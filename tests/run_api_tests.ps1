[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5000'
)

$ErrorActionPreference = 'Stop'
$base = $BaseUrl.TrimEnd('/')
$api = "$base/api/reimbursements"
$passed = 0
$failed = 0
$runId = [Guid]::NewGuid().ToString('N').Substring(0, 8)

function Invoke-Api {
    param(
        [Parameter(Mandatory)] [string]$Method,
        [Parameter(Mandatory)] [string]$Uri,
        [object]$Body,
        [string]$RawBody
    )

    $params = @{ Uri = $Uri; Method = $Method; UseBasicParsing = $true; ErrorAction = 'Stop' }
    if ($PSBoundParameters.ContainsKey('RawBody')) {
        # Cuerpo JSON literal: evita que PowerShell redondee montos extremos
        # como decimal(18,2) antes de enviarlos.
        $params.ContentType = 'application/json'
        $params.Body = $RawBody
    }
    elseif ($null -ne $Body) {
        $params.ContentType = 'application/json'
        $params.Body = ($Body | ConvertTo-Json -Compress)
    }

    try {
        $response = Invoke-WebRequest @params
        return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Content = $response.Content }
    }
    catch {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }

        $content = ''
        try {
            if ($response -is [System.Net.Http.HttpResponseMessage]) {
                $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            }
            else {
                $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                $content = $reader.ReadToEnd()
                $reader.Dispose()
            }
        }
        catch { }
        return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Content = $content }
    }
}

function Convert-ApiJson {
    param([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return $null }
    return $Content | ConvertFrom-Json
}

function New-CreateBody {
    param(
        [Parameter(Mandatory)] [string]$EmployeeName,
        [Parameter(Mandatory)] [string]$AmountLiteral,
        [string]$Category = 'Transporte',
        [string]$Description = 'Prueba de limite'
    )

    return '{"employeeName":' + (ConvertTo-Json $EmployeeName -Compress) +
        ',"amount":' + $AmountLiteral +
        ',"category":' + (ConvertTo-Json $Category -Compress) +
        ',"description":' + (ConvertTo-Json $Description -Compress) + '}'
}

function Test-Case {
    param(
        [Parameter(Mandatory)] [string]$Id,
        [Parameter(Mandatory)] [int]$ExpectedHttp,
        [Parameter(Mandatory)] [scriptblock]$Request,
        [scriptblock]$Assertion
    )

    try {
        $response = & $Request
        $ok = $response.StatusCode -eq $ExpectedHttp
        $detail = ''
        if ($ok -and $null -ne $Assertion) {
            $assertionResult = & $Assertion $response
            if ($assertionResult -is [array]) {
                $ok = [bool]$assertionResult[0]
                $detail = [string]$assertionResult[1]
            }
            else { $ok = [bool]$assertionResult }
        }
        if ($ok) {
            $script:passed++
            Write-Host "$Id PASS - HTTP recibido $($response.StatusCode), esperado $ExpectedHttp $detail"
        }
        else {
            $script:failed++
            Write-Host "$Id FAIL - HTTP recibido $($response.StatusCode), esperado $ExpectedHttp $detail" -ForegroundColor Red
        }
        return $response
    }
    catch {
        $script:failed++
        Write-Host "$Id FAIL - HTTP recibido sin respuesta, esperado $ExpectedHttp ($($_.Exception.Message))" -ForegroundColor Red
        return $null
    }
}

function Assert-Status {
    param($Response, [string]$ExpectedStatus)
    $item = Convert-ApiJson $Response.Content
    if ($null -ne $item -and $item.status -eq $ExpectedStatus) { return @($true, "estado $ExpectedStatus") }
    return @($false, "estado recibido '$($item.status)', esperado '$ExpectedStatus'")
}

function Assert-Fields {
    param($Response, [hashtable]$Expected)
    $item = Convert-ApiJson $Response.Content
    if ($null -eq $item) { return @($false, 'respuesta sin cuerpo JSON') }

    $problems = @()
    foreach ($key in $Expected.Keys) {
        if ($item.$key -ne $Expected[$key]) {
            $problems += "$key='$($item.$key)' (esperado '$($Expected[$key])')"
        }
    }

    if ($problems.Count -eq 0) { return @($true, 'campos verificados') }
    return @($false, ($problems -join '; '))
}

# Un unico prechequeo: si la API no responde 200 no se ejecuta la matriz.
try {
    $precheck = Invoke-Api -Method Get -Uri $api
}
catch {
    Write-Host "API no disponible en $base. No se ejecuto la matriz de pruebas." -ForegroundColor Yellow
    exit 1
}

if ($precheck.StatusCode -ne 200) {
    Write-Host "API respondio $($precheck.StatusCode) en $base; se esperaba 200. No se ejecuto la matriz de pruebas." -ForegroundColor Yellow
    exit 1
}

# Identificadores unicos por ejecucion: los filtros no dependen de datos previos.
$demoEmployee = "Demo API $runId"
$pendingEmployee = "Pendiente API $runId"
$rejectEmployee = "Rechazo API $runId"
$invalidRejectEmployee = "Motivo API $runId"
$longReasonEmployee = "Longitud API $runId"

$t01 = Test-Case 'T01' 201 { Invoke-Api Post $api @{ employeeName = $demoEmployee; amount = 100000; category = 'Transporte'; description = 'Viaje de prueba T01' } } { param($r) Assert-Status $r 'Approved' }
$approvedId = (Convert-ApiJson $t01.Content).id
$t02 = Test-Case 'T02' 201 { Invoke-Api Post $api @{ employeeName = "Aprobado API $runId"; amount = 500000; category = 'Alimentacion'; description = 'Prueba T02' } } { param($r) Assert-Status $r 'Approved' }
$t03 = Test-Case 'T03' 201 { Invoke-Api Post $api @{ employeeName = $pendingEmployee; amount = 500001; category = 'Hospedaje'; description = 'Prueba T03' } } { param($r) Assert-Status $r 'Pending' }
$pendingId = (Convert-ApiJson $t03.Content).id

Test-Case 'T04' 400 { Invoke-Api Post $api @{ employeeName = "Invalido API $runId"; amount = 0; category = 'Transporte'; description = 'Monto cero' } } | Out-Null
Test-Case 'T05' 400 { Invoke-Api Post $api @{ employeeName = "Invalido API $runId"; amount = -1; category = 'Transporte'; description = 'Monto negativo' } } | Out-Null
Test-Case 'T06' 400 { Invoke-Api Post $api @{ employeeName = "Invalido API $runId"; amount = 1; category = 'Transporte'; description = ' ' } } | Out-Null
Test-Case 'T07' 400 { Invoke-Api Post $api @{ employeeName = "Invalido API $runId"; amount = 1; category = ''; description = 'Categoria vacia' } } | Out-Null
Test-Case 'T08' 404 { Invoke-Api Get "$api/999999" } | Out-Null

Test-Case 'T09' 200 { Invoke-Api Get ($api + '?status=Pending') } {
    param($r)
    $items = @(Convert-ApiJson $r.Content)
    $ok = ($items.Count -gt 0) -and (@($items | Where-Object { $_.status -ne 'Pending' }).Count -eq 0)
    return @($ok, 'solo registros Pending')
} | Out-Null
Test-Case 'T10' 200 { Invoke-Api Get ($api + '?employeeName=' + [uri]::EscapeDataString($demoEmployee)) } {
    param($r)
    $items = @(Convert-ApiJson $r.Content)
    $mis = @($items | Where-Object { $_.employeeName -ne $demoEmployee }).Count
    $ok = ($items.Count -gt 0) -and ($mis -eq 0)
    return @($ok, "solo $demoEmployee (items=$($items.Count) mismatches=$mis)")
} | Out-Null
Test-Case 'T11' 200 { Invoke-Api Get ($api + '?status=Pending&employeeName=' + [uri]::EscapeDataString($pendingEmployee)) } {
    param($r)
    $items = @(Convert-ApiJson $r.Content)
    $ok = $items.Count -gt 0 -and @($items | Where-Object { $_.status -ne 'Pending' -or $_.employeeName -ne $pendingEmployee }).Count -eq 0
    return @($ok, 'filtros status y employeeName combinados')
} | Out-Null

Test-Case 'T12' 200 { Invoke-Api Patch "$api/$pendingId/approve" } { param($r) Assert-Status $r 'Approved' } | Out-Null

# Se crea la solicitud a rechazar con un nombre unico, sin depender de T12.
$rejectSeed = Invoke-Api Post $api @{ employeeName = $rejectEmployee; amount = 500001; category = 'Hospedaje'; description = 'Solicitud para rechazo T13' }
$rejectedId = (Convert-ApiJson $rejectSeed.Content).id
Test-Case 'T13' 200 { Invoke-Api Patch "$api/$rejectedId/reject" @{ reason = 'Soporte insuficiente' } } {
    param($r)
    Assert-Fields $r @{ status = 'Rejected'; rejectionReason = 'Soporte insuficiente' }
} | Out-Null

# Motivo vacio sobre una pendiente propia: 400 y la solicitud sigue Pending.
$invalidReject = Invoke-Api Post $api @{ employeeName = $invalidRejectEmployee; amount = 500001; category = 'Hospedaje'; description = 'Pendiente para T14' }
$invalidRejectId = (Convert-ApiJson $invalidReject.Content).id
Test-Case 'T14' 400 { Invoke-Api Patch "$api/$invalidRejectId/reject" @{ reason = ' ' } } {
    param($r)
    $after = Invoke-Api Get "$api/$invalidRejectId"
    Assert-Fields $after @{ status = 'Pending'; rejectionReason = $null }
} | Out-Null

# Inmutabilidad: tras el 409 el estado y la fecha de decision no cambian.
$approvedBefore = Convert-ApiJson (Invoke-Api Get "$api/$approvedId").Content
Test-Case 'T15' 409 { Invoke-Api Patch "$api/$approvedId/approve" } {
    param($r)
    $after = Convert-ApiJson (Invoke-Api Get "$api/$approvedId").Content
    $ok = $after.status -eq 'Approved' -and $after.decidedAtUtc -eq $approvedBefore.decidedAtUtc
    return @($ok, "estado $($after.status), decidedAtUtc sin cambios")
} | Out-Null

$rejectedBefore = Convert-ApiJson (Invoke-Api Get "$api/$rejectedId").Content
Test-Case 'T16' 409 { Invoke-Api Patch "$api/$rejectedId/reject" @{ reason = 'Segundo intento' } } {
    param($r)
    $after = Convert-ApiJson (Invoke-Api Get "$api/$rejectedId").Content
    $ok = $after.status -eq 'Rejected' -and
        $after.rejectionReason -eq 'Soporte insuficiente' -and
        $after.decidedAtUtc -eq $rejectedBefore.decidedAtUtc
    return @($ok, "estado $($after.status), motivo y decidedAtUtc sin cambios")
} | Out-Null

# R01-R05: precision, tope de autoaprobacion y rango de decimal(18,2).
# Los montos extremos se envian como literal JSON para no perder precision.
Test-Case 'R01' 400 { Invoke-Api Post $api -RawBody (New-CreateBody "Precision API $runId" '0.001' 'Transporte' 'Tres decimales') } | Out-Null
Test-Case 'R02' 400 { Invoke-Api Post $api -RawBody (New-CreateBody "Precision API $runId" '500000.001' 'Transporte' 'Tope con tres decimales') } | Out-Null
Test-Case 'R03' 201 { Invoke-Api Post $api -RawBody (New-CreateBody "Rango API $runId" '500000.01' 'Transporte' 'Justo sobre el tope') } { param($r) Assert-Status $r 'Pending' } | Out-Null
Test-Case 'R04' 201 { Invoke-Api Post $api -RawBody (New-CreateBody "Rango API $runId" '9999999999999999.99' 'Transporte' 'Maximo de decimal(18,2)') } { param($r) Assert-Status $r 'Pending' } | Out-Null
Test-Case 'R05' 400 { Invoke-Api Post $api -RawBody (New-CreateBody "Rango API $runId" '10000000000000000.00' 'Transporte' 'Sobre el rango de decimal(18,2)') } | Out-Null

# R06-R09: los cuatro limites de longitud (100/60/500/500 tras Trim).
$longName = 'x' * 101
$longCategory = 'x' * 61
$longDescription = 'x' * 501
$longReason = 'x' * 501
Test-Case 'R06' 400 { Invoke-Api Post $api @{ employeeName = $longName; amount = 1; category = 'Transporte'; description = 'Nombre de 101 caracteres' } } | Out-Null
Test-Case 'R07' 400 { Invoke-Api Post $api @{ employeeName = "Longitud API $runId"; amount = 1; category = $longCategory; description = 'Categoria de 61 caracteres' } } | Out-Null
Test-Case 'R08' 400 { Invoke-Api Post $api @{ employeeName = "Longitud API $runId"; amount = 1; category = 'Transporte'; description = $longDescription } } | Out-Null
$longReasonSeed = Invoke-Api Post $api @{ employeeName = $longReasonEmployee; amount = 500001; category = 'Hospedaje'; description = 'Pendiente para R09' }
$longReasonId = (Convert-ApiJson $longReasonSeed.Content).id
Test-Case 'R09' 400 { Invoke-Api Patch "$api/$longReasonId/reject" @{ reason = $longReason } } {
    param($r)
    $after = Invoke-Api Get "$api/$longReasonId"
    Assert-Fields $after @{ status = 'Pending'; rejectionReason = $null }
} | Out-Null

# R10-R11: estados no definidos (numerico y texto) se rechazan con 400.
Test-Case 'R10' 400 { Invoke-Api Get ($api + '?status=999') } | Out-Null
Test-Case 'R11' 400 { Invoke-Api Get ($api + '?status=NoExiste') } | Out-Null

# R12: las fechas se serializan en UTC con sufijo Z sin migracion.
Test-Case 'R12' 200 { Invoke-Api Get "$api/$approvedId" } {
    param($r)
    $createdOk = $r.Content -match '"createdAtUtc":"[^"]*Z"'
    $decidedOk = $r.Content -match '"decidedAtUtc":"[^"]*Z"'
    return @(($createdOk -and $decidedOk), 'createdAtUtc y decidedAtUtc con sufijo Z')
} | Out-Null

$total = $passed + $failed
Write-Host "Resumen: $passed PASS, $failed FAIL, $total total"
if ($failed -gt 0) { exit 1 }
exit 0
