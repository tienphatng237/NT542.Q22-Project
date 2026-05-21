function Write-GroupedPostAuditReport {
    param(
        [Parameter(Mandatory = $true)] [array]$Results,
        [Parameter(Mandatory = $true)] [string]$BaseDir,
        [Parameter(Mandatory = $true)] [string]$TimestampFile,
        [Parameter(Mandatory = $true)] [string]$TimestampDisplay,
        [Parameter(Mandatory = $true)] [string]$OSInfo,
        [Parameter(Mandatory = $true)] [string]$ReportStem,
        [Parameter(Mandatory = $true)] [string]$Title,
        [Parameter(Mandatory = $true)] [string]$ReportTitle,
        [Parameter(Mandatory = $true)] [string]$CssTemplatePath,
        [Parameter(Mandatory = $true)] [string]$HtmlTemplatePath,
        [int]$JsonDepth = 6
    )

    if (-not (Test-Path $CssTemplatePath)) { throw "CSS template not found: $CssTemplatePath" }
    if (-not (Test-Path $HtmlTemplatePath)) { throw "HTML template not found: $HtmlTemplatePath" }

    $JsonPath = "$BaseDir\Reports\JSON\$ReportStem-$TimestampFile.json"
    $HtmlPath = "$BaseDir\Reports\HTML\$ReportStem-$TimestampFile.html"
    $Results | ConvertTo-Json -Depth $JsonDepth | Out-File $JsonPath -Encoding UTF8

    $CssContent = Get-Content -Path $CssTemplatePath -Raw
    $HtmlTemplate = Get-Content -Path $HtmlTemplatePath -Raw
    $StyleBlock = "<style>`n$CssContent`n</style>"
    $TableRows = New-Object System.Collections.Generic.List[string]

    $TotalPass = 0
    $TotalFail = 0
    $Groups = $Results | Group-Object GrpId

    foreach ($Grp in $Groups) {
        $GrpPass = @($Grp.Group | Where-Object { $_.Status -eq 'Pass' }).Count
        $GrpFail = @($Grp.Group | Where-Object { $_.Status -eq 'Fail' }).Count
        $GrpMax = [int]$Grp.Count
        $GrpPct = if ($GrpMax -gt 0) { [math]::Round(($GrpPass / $GrpMax) * 100) } else { 0 }
        $TotalPass += $GrpPass
        $TotalFail += $GrpFail

        $GrpName = $Grp.Group[0].GrpName
        $ClsGrp = 'grp-' + $Grp.Name
        $PassClass = if ($GrpPass -gt 0) { 'txt-pass' } else { 'txt-neutral' }
        $FailClass = if ($GrpFail -gt 0) { 'txt-fail' } else { 'txt-neutral' }

        $TableRows.Add("<tr class='row-group' onclick=`"toggle('$ClsGrp')`"><td class='col-desc'>$($Grp.Name) $GrpName</td><td class='col-num $PassClass'>$GrpPass</td><td class='col-num $FailClass'>$GrpFail</td><td class='col-num'>$GrpMax.0</td><td class='col-num'>$GrpPct%</td></tr>")

        $SubGroups = $Grp.Group | Group-Object SubId
        foreach ($Sub in $SubGroups) {
            $SubPass = @($Sub.Group | Where-Object { $_.Status -eq 'Pass' }).Count
            $SubFail = @($Sub.Group | Where-Object { $_.Status -eq 'Fail' }).Count
            $SubMax = [int]$Sub.Count
            $SubPct = if ($SubMax -gt 0) { [math]::Round(($SubPass / $SubMax) * 100) } else { 0 }
            $SubName = $Sub.Group[0].SubName
            $ClsSub = 'sub-' + $Sub.Name.Replace('.', '')
            $SubPassClass = if ($SubPass -gt 0) { 'txt-pass' } else { 'txt-neutral' }
            $SubFailClass = if ($SubFail -gt 0) { 'txt-fail' } else { 'txt-neutral' }

            $TableRows.Add("<tr class='row-subgroup $ClsGrp' style='display:none;' onclick=`"toggle('$ClsSub')`"><td class='col-desc'>&nbsp;&nbsp;&nbsp;&nbsp;$($Sub.Name) $SubName</td><td class='col-num $SubPassClass'>$SubPass</td><td class='col-num $SubFailClass'>$SubFail</td><td class='col-num'>$SubMax.0</td><td class='col-num'>$SubPct%</td></tr>")

            foreach ($Item in $Sub.Group) {
                $ItemPass = if ($Item.Status -eq 'Pass') { 1 } else { 0 }
                $ItemFail = if ($Item.Status -eq 'Fail') { 1 } else { 0 }
                $ItemPct = if ($ItemPass -eq 1) { 100 } else { 0 }
                $ItemPassClass = if ($ItemPass -eq 1) { 'txt-pass' } else { 'txt-neutral' }
                $ItemFailClass = if ($ItemFail -eq 1) { 'txt-fail' } else { 'txt-neutral' }

                $TableRows.Add("<tr class='row-item $ClsGrp $ClsSub'><td class='col-desc' style='color:#555;'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$($Item.CisId) $($Item.Desc)</td><td class='col-num $ItemPassClass'>$ItemPass</td><td class='col-num $ItemFailClass'>$ItemFail</td><td class='col-num'>1.0</td><td class='col-num'>$ItemPct%</td></tr>")
            }
        }
    }

    $GrandMax = $TotalPass + $TotalFail
    $GrandPct = if ($GrandMax -gt 0) { [math]::Round(($TotalPass / $GrandMax) * 100) } else { 0 }
    $TableRows.Add("<tr class='footer-row'><td class='col-desc' style='text-align:right'>Total</td><td class='col-num txt-pass'>$TotalPass</td><td class='col-num txt-fail'>$TotalFail</td><td class='col-num'>$GrandMax.0</td><td class='col-num'>$GrandPct%</td></tr>")

    $FinalHtml = $HtmlTemplate
    $Replacements = @{
        '{{TITLE}}'        = $Title
        '{{STYLE_BLOCK}}'  = $StyleBlock
        '{{REPORT_TITLE}}' = $ReportTitle
        '{{DISPLAY_TIME}}' = $TimestampDisplay
        '{{OS_INFO}}'      = $OSInfo
        '{{TABLE_ROWS}}'   = ($TableRows -join [Environment]::NewLine)
    }

    foreach ($Key in $Replacements.Keys) {
        $FinalHtml = $FinalHtml.Replace($Key, $Replacements[$Key])
    }

    $FinalHtml | Out-File $HtmlPath -Encoding UTF8
    return @{ JsonPath = $JsonPath; HtmlPath = $HtmlPath }
}

function Write-FlatPostAuditReport {
    param(
        [Parameter(Mandatory = $true)] [array]$Results,
        [Parameter(Mandatory = $true)] [string]$BaseDir,
        [Parameter(Mandatory = $true)] [string]$TimestampFile,
        [Parameter(Mandatory = $true)] [string]$TimestampDisplay,
        [Parameter(Mandatory = $true)] [string]$OSInfo,
        [Parameter(Mandatory = $true)] [string]$ReportStem,
        [Parameter(Mandatory = $true)] [string]$Title,
        [Parameter(Mandatory = $true)] [string]$ReportTitle,
        [Parameter(Mandatory = $true)] [string]$CssTemplatePath,
        [Parameter(Mandatory = $true)] [string]$HtmlTemplatePath,
        [string[]]$SelectColumns = @('CIS_ID','Type','Description','Expected','Current','Status'),
        [int]$JsonDepth = 5
    )

    if (-not (Test-Path $CssTemplatePath)) { throw "CSS template not found: $CssTemplatePath" }
    if (-not (Test-Path $HtmlTemplatePath)) { throw "HTML template not found: $HtmlTemplatePath" }

    $PassCount = @($Results | Where-Object { $_.Status -eq 'PASS' -or $_.Status -eq 'Pass' }).Count
    $FailCount = @($Results | Where-Object { $_.Status -eq 'FAIL' -or $_.Status -eq 'Fail' }).Count
    $TotalCount = $Results.Count
    $PassPct = if ($TotalCount -gt 0) { [math]::Round(($PassCount / $TotalCount) * 100, 2) } else { 0 }

    $JsonPath = "$BaseDir\Reports\JSON\$ReportStem-$TimestampFile.json"
    $HtmlPath = "$BaseDir\Reports\HTML\$ReportStem-$TimestampFile.html"
    $Results | ConvertTo-Json -Depth $JsonDepth | Out-File -FilePath $JsonPath -Encoding UTF8

    $CssContent = Get-Content -Path $CssTemplatePath -Raw
    $HtmlTemplate = Get-Content -Path $HtmlTemplatePath -Raw
    $StyleBlock = "<style>`n$CssContent`n</style>"
    $Summary = "PASS: $PassCount | FAIL: $FailCount | TOTAL: $TotalCount | PASS RATE: $PassPct%"

    $Selected = $Results | Select-Object -Property $SelectColumns
    $TableHtml = $Selected | ConvertTo-Html -Fragment

    $FinalHtml = $HtmlTemplate
    $Replacements = @{
        '{{TITLE}}'        = $Title
        '{{STYLE_BLOCK}}'  = $StyleBlock
        '{{REPORT_TITLE}}' = $ReportTitle
        '{{DISPLAY_TIME}}' = $TimestampDisplay
        '{{OS_INFO}}'      = $OSInfo
        '{{SUMMARY}}'      = $Summary
        '{{TABLE_HTML}}'   = $TableHtml
    }

    foreach ($Key in $Replacements.Keys) {
        $FinalHtml = $FinalHtml.Replace($Key, $Replacements[$Key])
    }

    $FinalHtml | Out-File -FilePath $HtmlPath -Encoding UTF8
    return @{ JsonPath = $JsonPath; HtmlPath = $HtmlPath }
}
