[CmdletBinding()]
param(
    [string]$Output = "rakuten-big-s-apn-unlock.zip"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$build = Join-Path $root ".build"

function Find-Tool([string]$Name, [string[]]$Candidates) {
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

$zip = Find-Tool "zip.exe" @()
if (-not $zip) { $zip = Find-Tool "zip" @() }
if (-not $zip) { throw "A compatible zip utility was not found on PATH." }

if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
$stage = New-Item -ItemType Directory -Path (Join-Path $build "stage")

try {
    foreach ($name in @("module.prop", "service.sh", "uninstall.sh", "customize.sh", "README.md")) {
        $text = [IO.File]::ReadAllText((Join-Path $root $name)).Replace("`r`n", "`n").Replace("`r", "`n")
        [IO.File]::WriteAllText((Join-Path $stage.FullName $name), $text, (New-Object Text.UTF8Encoding($false)))
    }
    Copy-Item -LiteralPath (Join-Path $root "META-INF") -Destination $stage.FullName -Recurse

    $zipPath = if ([IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $root $Output }
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Push-Location $stage.FullName
    try {
        & $zip -q -r -9 $zipPath . -x '*.build*' '*.zip' '*.log' '*applied-subids*'
        if ($LASTEXITCODE -ne 0) { throw "zip failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
    Write-Host "Built: $zipPath"
} finally {
    if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
}
