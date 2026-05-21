param(
    [Parameter(Mandatory = $true)]
    [string]$CallerScriptRoot,
    [string]$BaseDir = "C:\CIS-Automation",
    [switch]$IncludeTemplates
)

$BaseDir = $BaseDir
$Paths = @(
    "$BaseDir\Scripts",
    "$BaseDir\Reports\HTML",
    "$BaseDir\Reports\JSON",
    "$BaseDir\Logs"
)

foreach ($PathItem in $Paths) {
    if (-not (Test-Path $PathItem)) {
        New-Item -ItemType Directory -Force -Path $PathItem | Out-Null
    }
}

$StartTime = Get-Date
$TimestampFile = $StartTime.ToString("yyyyMMdd_HHmmss")
$TimestampDisplay = $StartTime.ToString("dd/MM/yyyy HH:mm:ss")
$OSInfo = (Get-CimInstance Win32_OperatingSystem).Caption

if ($IncludeTemplates) {
    $SearchRoot = $CallerScriptRoot
    while ($SearchRoot -and -not (Test-Path (Join-Path $SearchRoot "templates"))) {
        $Parent = Split-Path -Parent $SearchRoot
        if ($Parent -eq $SearchRoot) { break }
        $SearchRoot = $Parent
    }

    if (-not (Test-Path (Join-Path $SearchRoot "templates"))) {
        throw "Could not locate pipeline templates directory from caller root: $CallerScriptRoot"
    }

    $PipelineRoot = $SearchRoot
    $TemplateDir = Join-Path $PipelineRoot "templates"
    $CssTemplatePath = Join-Path $TemplateDir "cis-audit-report.css"
    $HtmlTemplatePath = Join-Path $TemplateDir "cis-audit-report.html.tpl"
}
