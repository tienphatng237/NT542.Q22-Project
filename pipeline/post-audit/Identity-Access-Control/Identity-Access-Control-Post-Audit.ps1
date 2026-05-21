$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AuditScript = Join-Path $ScriptRoot 'Identity-Access-Control-Audit.ps1'
$HelperScript = Join-Path $ScriptRoot '..\..\common\Post-Audit-Report-Helpers.ps1'

if (-not (Test-Path $AuditScript)) {
    throw "Audit script not found for post-audit phase: $AuditScript"
}
if (-not (Test-Path $HelperScript)) {
    throw "Post-audit helper script not found: $HelperScript"
}

. $AuditScript
. $HelperScript

if (-not $Results -or $Results.Count -eq 0) {
    throw "No audit results found after running audit script."
}

$Report = Write-GroupedPostAuditReport `
    -Results $Results `
    -BaseDir $BaseDir `
    -TimestampFile $TimestampFile `
    -TimestampDisplay $TimestampDisplay `
    -OSInfo $OSInfo `
    -ReportStem 'Identity-Post-Audit' `
    -Title 'CIS Post-Audit Report - Identity & Access' `
    -ReportTitle 'CIS Post-Audit Report - Identity & Access Control (Full)' `
    -CssTemplatePath $CssTemplatePath `
    -HtmlTemplatePath $HtmlTemplatePath `
    -JsonDepth 4

Write-Host ''
Write-Host '===============================================================================' -ForegroundColor Cyan
Write-Host ' POST-AUDIT REPORT HOAN TAT! ' -ForegroundColor Green
Write-Host " [HTML Report] : $($Report.HtmlPath)" -ForegroundColor Yellow
Write-Host " [JSON Data]   : $($Report.JsonPath)" -ForegroundColor Yellow
Write-Host '===============================================================================' -ForegroundColor Cyan
