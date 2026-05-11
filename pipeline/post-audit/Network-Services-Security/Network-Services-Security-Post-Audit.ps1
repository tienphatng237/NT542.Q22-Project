$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$auditScript = Join-Path $scriptRoot 'CIS-WinServer2022-Audit.ps1'

if (-not (Test-Path $auditScript)) {
    $auditScript = Join-Path $scriptRoot '..\..\audit\Network-Services-Security\CIS-WinServer2022-Audit.ps1'
}

& $auditScript
