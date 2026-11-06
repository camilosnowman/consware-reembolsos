<#
.SYNOPSIS
    Empaqueta la entrega consware-reembolsos.zip a partir de los ficheros
    versionados del checkout actual (git ls-files).

.DESCRIPTION
    Reglas de empaquetado:

    - Entran en el paquete SOLO los ficheros versionados por git en el checkout
      actual (git ls-files). Se copia el contenido del arbol de trabajo, por lo
      que los ficheros versionados con modificaciones sin confirmar se copian
      tal cual, como trabajo en progreso. Nunca se copian ficheros ignorados o
      sin versionar (por eso no se usa robocopy, que arrastraria los ignorados).

    - Se excluyen de forma explicita, como defensa en profundidad, aunque un
      fichero de este tipo llegara a estar versionado:
        * material personal de estudio: GUIA_ENTREVISTA.md y cualquier guia o
          PDF tecnico de estudio (guia/entrevista/estudio en el nombre);
        * configuraciones privadas: appsettings.Development.json y
          appsettings.Production.json (las plantillas *.example.json SI se
          incluyen);
        * secretos: .env*, certificados y llaves (*.pem, *.key, *.pfx, *.p12),
          nombres con secret/password/credential;
        * IDE: carpetas .idea/.vscode/.vs y ficheros *.iml;
        * local.properties (config local de Android);
        * carpetas generadas y de build: bin, obj, node_modules, dist, build,
          .angular, .dart_tool, .git, .gradle, coverage, TestResults.

    - El ZIP mantiene la estructura original de la entrega: carpeta raiz
      consware-reembolsos/ con todos los fuentes permitidos. El .git nunca se
      comprime porque solo se copian ficheros versionados individuales.

    - El staging se crea bajo el directorio temporal del usuario con prefijo
      GUID. La ruta resuelta se valida (dentro de TEMP y con el patron GUID
      esperado) antes de crear la carpeta y antes de cada borrado recursivo,
      para no borrar por error otra raiz. No se recorre ningun arbol de
      directorios (lista explicita de ficheros y directorios creados por el
      script), por lo que no se atraviesan symlinks.

.NOTES
    Salida: consware-reembolsos.zip en la raiz del repositorio, fuera de git
    (el .gitignore raiz ya lo excluye).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------ constantes

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$archivePath = Join-Path $repoRoot 'consware-reembolsos.zip'

# Carpetas generadas/build que nunca deben entrar en el paquete (defensa en
# profundidad; se comparan segmentos exactos de ruta, por lo que ficheros como
# build.gradle.kts NO se ven afectados).
$script:ExcludedSegments = @(
    '.git', '.gradle', '.angular', '.dart_tool', '.idea', '.vscode', '.vs',
    'bin', 'obj', 'node_modules', 'dist', 'build', 'coverage', 'TestResults'
)

# Patrones aplicados SOLO al nombre de fichero (no a la ruta completa).
# Nota: 'gu\u00eda' se expresa con escape Unicode para que el patron sea inmune
# a la codificacion con la que se guarde este script.
$script:ExcludedFileNamePatterns = @(
    '(?i)(guia|gu\u00eda|entrevista|study|estudio|guide)[^/]*\.(md|pdf)$',
    '(?i)appsettings\.(development|production)\.json$',
    '(?i)^\.env(\..*)?$',
    '(?i)(secret|password|credential)',
    '\.pem$', '\.key$', '\.pfx$', '\.p12$',
    '\.iml$',
    'local\.properties$',
    '^consware-reembolsos\.zip$'
)

# -------------------------------------------------------------------- funciones

function Test-ExcludedRelativePath {
    # Devuelve $true si una ruta versionada (relativa a la raiz del repositorio)
    # debe quedar fuera del paquete por las reglas de exclusion explicitas.
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $normalized = $RelativePath -replace '\\', '/'
    $fileName = [System.IO.Path]::GetFileName($normalized)

    foreach ($segment in @($normalized -split '/')) {
        if ($script:ExcludedSegments -contains $segment) {
            return $true
        }
    }

    foreach ($pattern in $script:ExcludedFileNamePatterns) {
        if ($fileName -match $pattern) {
            return $true
        }
    }

    return $false
}

function Assert-SafeTemporaryRoot {
    # Valida que la ruta de staging resuelta quede dentro del directorio
    # temporal del usuario y sea exactamente la carpeta con prefijo GUID creada
    # por este script. Se comprueba antes de crearla y antes de cada
    # Remove-Item recursivo, para no limpiar nunca otra raiz.
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $resolvedCandidate = [System.IO.Path]::GetFullPath($Path)

    if (-not $resolvedCandidate.StartsWith($resolvedTempRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "La ruta de staging '$resolvedCandidate' queda fuera del directorio temporal ($resolvedTempRoot); se cancela por seguridad."
    }

    $leaf = Split-Path -Leaf $resolvedCandidate
    if ($leaf -notmatch '^consware-reembolsos-[0-9a-f]{32}$') {
        throw "La carpeta de staging '$resolvedCandidate' no sigue el patron GUID esperado; se cancela por seguridad."
    }
}

# ------------------------------------------------------------------ principal

# 1) Lista de ficheros versionados en el checkout actual (git ls-files, con
#    separador NUL para que las rutas no se partan por saltos de linea).
$rawListing = & git -C $repoRoot ls-files -z
if ($LASTEXITCODE -ne 0) {
    throw "git ls-files fallo con codigo $LASTEXITCODE; no se puede determinar la lista de ficheros versionados."
}
$trackedFiles = @((@($rawListing) -join "`0") -split "`0" | Where-Object { $_ -ne '' })
if ($trackedFiles.Count -eq 0) {
    throw "git ls-files no devolvio ficheros; revise el checkout ($repoRoot)."
}

# 2) Staging bajo TEMP con prefijo GUID (validado antes de crear nada).
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("consware-reembolsos-" + [Guid]::NewGuid().ToString('N'))
Assert-SafeTemporaryRoot -Path $temporaryRoot
$stagingRoot = Join-Path $temporaryRoot 'consware-reembolsos'

try {
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    # 3) Copia fichero a fichero SOLO los versionados permitidos, tal como estan
    #    en el arbol de trabajo (incluye modificaciones sin confirmar).
    $included = New-Object System.Collections.Generic.List[string]
    $excluded = New-Object System.Collections.Generic.List[string]

    foreach ($relative in $trackedFiles) {
        if (Test-ExcludedRelativePath -RelativePath $relative) {
            $excluded.Add($relative)
            continue
        }

        $windowsRelative = $relative -replace '/', '\'
        $source = Join-Path $repoRoot $windowsRelative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "El fichero versionado '$relative' no existe en el arbol de trabajo; el paquete quedaria incompleto. Confirme o restaure el fichero antes de empaquetar."
        }

        $destination = Join-Path $stagingRoot $windowsRelative
        $destinationDirectory = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationDirectory)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $source -Destination $destination -Force
        $included.Add($relative)
    }

    if ($included.Count -eq 0) {
        throw "Ningun fichero versionado supero las exclusiones; el paquete quedaria vacio."
    }

    if ($excluded.Count -gt 0) {
        Write-Warning ("Ficheros versionados excluidos del paquete ({0}): {1}" -f $excluded.Count, ($excluded -join ', '))
    }

    # 4) ZIP con la misma estructura raiz que la version original:
    #    carpeta consware-reembolsos/ en la raiz del archivo. Se crea entrada a
    #    entrada con separador '/' (el estandar ZIP) porque Compress-Archive de
    #    Windows PowerShell 5.1 guarda '\' y el paquete no seria portable.
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    $zip = [System.IO.Compression.ZipFile]::Open(
        $archivePath,
        [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
        foreach ($relative in $included) {
            $source = Join-Path $stagingRoot ($relative -replace '/', '\')
            $entryName = 'consware-reembolsos/' + ($relative -replace '\\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $source, $entryName, [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $zip.Dispose()
    }

    $size = (Get-Item -LiteralPath $archivePath).Length
    $sizeMiB = [Math]::Round($size / 1MB, 2)
    Write-Host ("Paquete creado: {0} ({1} ficheros, {2} MiB)" -f $archivePath, $included.Count, $sizeMiB)
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        # Validacion completa de la ruta resuelta antes del borrado recursivo.
        Assert-SafeTemporaryRoot -Path $temporaryRoot
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
