[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$archivePath = Join-Path $repoRoot 'consware-reembolsos.zip'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("consware-reembolsos-$([Guid]::NewGuid().ToString('N'))")
$stagingRepository = Join-Path $temporaryRoot 'consware-reembolsos'

try {
    New-Item -ItemType Directory -Path $stagingRepository -Force | Out-Null

    & robocopy $repoRoot $stagingRepository /E /R:1 /W:1 /XD bin obj node_modules .dart_tool build .angular dist .git /XF consware-reembolsos.zip appsettings.Development.json appsettings.Production.json *.secret* /NFL /NDL /NJH /NJS /NP
    $robocopyExitCode = $LASTEXITCODE
    if ($robocopyExitCode -gt 7) {
        throw "robocopy falló al preparar el paquete (código $robocopyExitCode)."
    }

    Compress-Archive -Path $stagingRepository -DestinationPath $archivePath -CompressionLevel Optimal -Force

    $size = (Get-Item -LiteralPath $archivePath).Length
    $sizeMiB = [Math]::Round($size / 1MB, 2)
    Write-Host "Paquete creado: $archivePath ($sizeMiB MiB)"
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
