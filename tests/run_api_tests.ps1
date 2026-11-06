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
        [object]$Body
    )

    $params = @{ Uri = $Uri; Method = $Method; UseBasicParsing = $true; ErrorAction = 'Stop' }
    if ($null -ne $Body) {
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
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $content = $reader.ReadToEnd()
            $reader.Dispose()
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

# Un Ãºnico prechequeo: no se ejecutan los casos si la API no estÃ¡ escuchando.
try {
    Invoke-Api -Method Get -Uri $api | Out-Null
}
catch {
    Write-Host "API no disponible en $base. No se ejecutÃ³ la matriz de pruebas." -ForegroundColor Yellow
    exit 1
}

$demoEmployee = 'Empleado Demo'
$pendingEmployee = "Pendiente API $runId"
$rejectEmployee = "Rechazo API $runId"

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
[System.IO.File]::WriteAllText("$env:TEMP\opencode\t10_debug.json", $r.Content)
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
$t13 = Test-Case 'T13' 200 {
    $newPending = Invoke-Api Post $api @{ employeeName = $rejectEmployee; amount = 500001; category = 'Hospedaje'; description = 'Solicitud para rechazo T13' }
    $rejectId = (Convert-ApiJson $newPending.Content).id
    Invoke-Api Patch "$api/$rejectId/reject" @{ reason = 'Soporte insuficiente' }
} { param($r) Assert-Status $r 'Rejected' }
$rejectedId = $null
if ($null -ne $t13) { $rejectedId = (Convert-ApiJson $t13.Content).id }

# Se crea una nueva pendiente para validar el motivo vacÃ­o sin depender de estados previos.
$invalidReject = Invoke-Api Post $api @{ employeeName = "Motivo API $runId"; amount = 500001; category = 'Hospedaje'; description = 'Pendiente para T14' }
$invalidRejectId = (Convert-ApiJson $invalidReject.Content).id
Test-Case 'T14' 400 { Invoke-Api Patch "$api/$invalidRejectId/reject" @{ reason = ' ' } } | Out-Null

Test-Case 'T15' 409 { Invoke-Api Patch "$api/$approvedId/approve" } | Out-Null
Test-Case 'T16' 409 { Invoke-Api Patch "$api/$rejectedId/reject" @{ reason = 'Segundo intento' } } | Out-Null

$total = $passed + $failed
Write-Host "Resumen: $passed PASS, $failed FAIL, $total total"
if ($failed -gt 0) { exit 1 }
exit 0
