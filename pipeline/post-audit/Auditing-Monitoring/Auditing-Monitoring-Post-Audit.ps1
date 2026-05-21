$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AuditScript = Join-Path $ScriptRoot 'Auditing-Monitoring-Audit.ps1'
$HelperScript = Join-Path $ScriptRoot '..\..\common\Post-Audit-Report-Helpers.ps1'
$TemplateDir = Join-Path $ScriptRoot '..\..\templates'
$GroupedCssTemplatePath = Join-Path $TemplateDir 'cis-audit-report.css'
$GroupedHtmlTemplatePath = Join-Path $TemplateDir 'cis-audit-report.html.tpl'

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

# Convert flat auditing rows to grouped structure so HTML format stays
# consistent with the other post-audit modules.
$ReportRows = foreach ($Item in $Results) {
    $CisIdText = [string]$Item.CIS_ID
    $TypeText = [string]$Item.Type
    $StatusText = if (([string]$Item.Status).ToUpperInvariant() -eq 'PASS') { 'Pass' } else { 'Fail' }

    $GrpId = '9'
    $GrpName = 'Other'
    if ($CisIdText -like '2.3.*') {
        $GrpId = '1'
        $GrpName = 'Local Policies'
    } elseif ($CisIdText -like '17.*') {
        $GrpId = '2'
        $GrpName = 'Advanced Audit Policy'
    } elseif ($CisIdText -like '18.10.26.*') {
        $GrpId = '3'
        $GrpName = 'Event Log Service'
    }

    $SubId = switch ($TypeText) {
        'Registry' { "$GrpId.1" }
        'AuditPol' { "$GrpId.2" }
        default { "$GrpId.9" }
    }
    $SubName = switch ($TypeText) {
        'Registry' { 'Registry Settings' }
        'AuditPol' { 'Audit Policy Settings' }
        default { $TypeText }
    }

    [PSCustomObject]@{
        GrpId  = $GrpId
        GrpName = $GrpName
        SubId  = $SubId
        SubName = $SubName
        CisId  = $CisIdText
        Desc   = [string]$Item.Description
        Status = $StatusText
    }
}

$Report = Write-GroupedPostAuditReport `
    -Results $ReportRows `
    -BaseDir $BaseDir `
    -TimestampFile $TimestampFile `
    -TimestampDisplay $TimestampDisplay `
    -OSInfo $OSInfo `
    -ReportStem 'Auditing-Monitoring-Post-Audit' `
    -Title 'CIS Post-Audit Report - Auditing & Monitoring' `
    -ReportTitle 'CIS Post-Audit Report - Auditing & Monitoring' `
    -CssTemplatePath $GroupedCssTemplatePath `
    -HtmlTemplatePath $GroupedHtmlTemplatePath `
    -JsonDepth 5

Write-Host ''
Write-Host '===============================================================================' -ForegroundColor Cyan
Write-Host ' POST-AUDIT REPORT HOAN TAT! ' -ForegroundColor Green
Write-Host " [HTML Report] : $($Report.HtmlPath)" -ForegroundColor Yellow
Write-Host " [JSON Data]   : $($Report.JsonPath)" -ForegroundColor Yellow
Write-Host '===============================================================================' -ForegroundColor Cyan
