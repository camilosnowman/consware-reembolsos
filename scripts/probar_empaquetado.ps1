<#
.SYNOPSIS
    Pruebas del paquete de entrega generado por scripts/empaquetar.ps1.

.DESCRIPTION
    Valida que consware-reembolsos.zip cumpla las reglas de entrega:

      1. Estructura compatible con la original: carpeta raiz
         consware-reembolsos/ y todas las entradas dentro de ella.
      2. Sin material personal de estudio (GUIA_ENTREVISTA.md, guias/PDFs
         tecnicos de estudio).
      3. Sin configuraciones privadas (appsettings.Development.json /
         appsettings.Production.json; la plantilla *.example.json SI debe ir).
      4. Sin secretos (.env, certificados/llaves, nombres con
         secret/password/credential), sin IDE (.idea/.vscode/*.iml), sin
         local.properties y sin carpetas generadas/build (bin, obj,
         node_modules, dist, build, .angular, .dart_tool, .git, ...).
      5. Contiene TODOS los fuentes versionados permitidos del checkout actual
         (git ls-files una vez aplicadas las exclusiones anteriores).

    Por defecto empaqueta primero (invocando scripts/empaquetar.ps1) y valida
    el ZIP resultante. Con -ZipPath <ruta> valida un ZIP ya existente sin
    volver a empaquetar.

    Codigo de salida: 0 si todas las comprobaciones pasan, 1 si alguna falla.
#>
[CmdletBinding()]
param(
    # Ruta opcional a un ZIP ya creado. Si se omite, se empaqueta antes de validar.
    [string]$ZipPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$failures = New-Object System.Collections.Generic.List[string]
$checks = 0

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:failures.Add($Message)
}

# ------------------------------------------------------------------ empaquetado

if (-not $ZipPath) {
    $ZipPath = Join-Path $repoRoot 'consware-reembolsos.zip'
    try {
        & (Join-Path $PSScriptRoot 'empaquetar.ps1')
    }
    catch {
        Write-Host "[FALLO] empaquetar.ps1 no termino correctamente: $($_.Exception.Message)"
        exit 1
    }
}

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    Write-Host "[FALLO] No existe el paquete a validar: $ZipPath"
    exit 1
}

# ------------------------------------------------- esperado: fuentes versionados

# Mismas reglas de exclusion que empaquetar.ps1, reimplementadas aqui a
# conciencia para validar de verdad al empaquetador.
$excludedSegments = @(
    '.git', '.gradle', '.angular', '.dart_tool', '.idea', '.vscode', '.vs',
    'bin', 'obj', 'node_modules', 'dist', 'build', 'coverage', 'TestResults'
)
$excludedFileNamePatterns = @(
    '(?i)(guia|gu\u00eda|entrevista|study|estudio|guide)[^/]*\.(md|pdf)$',
    '(?i)appsettings\.(development|production)\.json$',
    '(?i)^\.env(\..*)?$',
    '(?i)(secret|password|credential)',
    '\.pem$', '\.key$', '\.pfx$', '\.p12$',
    '\.iml$',
    'local\.properties$',
    '^consware-reembolsos\.zip$'
)

function Test-ForbiddenEntryName {
    # Devuelve $true si el nombre de una entrada del ZIP incumple las reglas
    # de la entrega (secretos, guias, IDE, configs privadas, build/generados).
    param([Parameter(Mandatory = $true)][string]$EntryName)

    $normalized = ($EntryName -replace '\\', '/') -replace '^\./', ''
    $fileName = [System.IO.Path]::GetFileName($normalized)

    foreach ($segment in @($normalized -split '/')) {
        if ($excludedSegments -contains $segment) {
            return $true
        }
    }

    foreach ($pattern in $excludedFileNamePatterns) {
        if ($fileName -match $pattern) {
            return $true
        }
    }

    return $false
}

$rawListing = & git -C $repoRoot ls-files -z
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FALLO] git ls-files fallo con codigo $LASTEXITCODE."
    exit 1
}
$trackedFiles = @((@($rawListing) -join "`0") -split "`0" | Where-Object { $_ -ne '' })

$expectedEntries = @{}
foreach ($relative in $trackedFiles) {
    if (-not (Test-ForbiddenEntryName $relative)) {
        $expectedEntries[('consware-reembolsos/' + ($relative -replace '\\', '/'))] = $relative
    }
}

# ------------------------------------------------------------------- validacion

Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath).Path)
try {
    $rawEntries = @($zip.Entries | ForEach-Object { $_.FullName } | Where-Object { $_ -ne '' })
}
finally {
    $zip.Dispose()
}

$entryNames = @($rawEntries | ForEach-Object { ($_ -replace '\\', '/').TrimEnd('/') } | Where-Object { $_ -ne '' })
$fileEntries = @{}
foreach ($rawName in $rawEntries) {
    if ($rawName.EndsWith('/') -or $rawName.EndsWith('\')) {
        continue
    }
    $fileEntries[($rawName -replace '\\', '/')] = $true
}

# 1) Estructura: raiz consware-reembolsos/ y nada fuera de ella.
$checks++
$outsideRoot = @($rawEntries | Where-Object {
    $_ -ne 'consware-reembolsos' -and
    $_ -ne 'consware-reembolsos/' -and
    -not $_.StartsWith('consware-reembolsos/')
})
if ($outsideRoot.Count -gt 0) {
    foreach ($name in $outsideRoot) {
        Add-Failure ("ENTRADA FUERA DE LA RAIZ consware-reembolsos/: {0}" -f $name)
    }
}

# 2) Separador estandar '/' en todas las entradas (ZIP portable).
$checks++
$backslashEntries = @($rawEntries | Where-Object { $_ -match '\\' })
if ($backslashEntries.Count -gt 0) {
    foreach ($name in $backslashEntries) {
        Add-Failure ("ENTRADA CON SEPARADOR '\\' EN LUGAR DE '/': {0}" -f $name)
    }
}

# 3) Sin entradas prohibidas (secretos, guias de estudio, IDE, configs
#    privadas, carpetas generadas/build, ficheros ignorados por regla).
$checks++
$forbidden = @($entryNames | Where-Object { Test-ForbiddenEntryName $_ })
if ($forbidden.Count -gt 0) {
    foreach ($name in $forbidden) {
        Add-Failure ("ENTRADA PROHIBIDA EN EL PAQUETE: {0}" -f $name)
    }
}

# 4) Completitud: todos los fuentes versionados permitidos estan dentro.
$checks++
$missing = @()
foreach ($expected in $expectedEntries.Keys) {
    if (-not $fileEntries.ContainsKey($expected)) {
        $missing += $expectedEntries[$expected]
    }
}
if ($missing.Count -gt 0) {
    foreach ($relative in $missing) {
        Add-Failure ("FALTA FICHERO VERSIONADO PERMITIDO: {0}" -f $relative)
    }
}

# 5) Sin ficheros de mas: el paquete contiene SOLO ficheros versionados que
#    superaron las exclusiones (no arrastra ignorados ni locales).
$checks++
$unexpected = @($fileEntries.Keys | Where-Object { -not $expectedEntries.ContainsKey($_) })
if ($unexpected.Count -gt 0) {
    foreach ($name in $unexpected) {
        Add-Failure ("FICHERO NO VERSIONADO O NO PERMITIDO EN EL PAQUETE: {0}" -f $name)
    }
}

# 6) La plantilla de configuracion SIN secretos SI viaja en el paquete
#    (protege contra exclusiones demasiado agresivas).
$checks++
$exampleConfig = 'consware-reembolsos/backend/Consware.Reimbursements.Api/appsettings.Development.example.json'
if (-not $fileEntries.ContainsKey($exampleConfig)) {
    Add-Failure ("DEBE INCLUIR LA PLANTILLA SIN SECRETOS: {0}" -f $exampleConfig)
}

# 7) Sin .git dentro del ZIP (equivale a no comprimir el historial).
$checks++
if (@($entryNames | Where-Object { $_ -match '(^|/)\.git(/|$)' }).Count -gt 0) {
    Add-Failure 'EL PAQUETE CONTIENE .git'
}

# --------------------------------------------------------------------- resumen

Write-Host ''
Write-Host ("Entradas del ZIP: {0} ({1} ficheros)" -f $entryNames.Count, $fileEntries.Count)
Write-Host ("Fuentes versionados permitidos esperados: {0}" -f $expectedEntries.Count)
Write-Host ("Comprobaciones ejecutadas: {0}" -f $checks)
Write-Host ''

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "[FALLO] $failure"
    }
    Write-Host ''
    Write-Host ("PRUEBAS DE EMPAQUETADO: {0} fallo(s)." -f $failures.Count)
    exit 1
}

Write-Host 'PRUEBAS DE EMPAQUETADO: OK (sin secretos, sin guias, sin IDE, con todos los fuentes versionados permitidos).'
exit 0
