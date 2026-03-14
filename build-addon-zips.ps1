param(
    [string]$OutputDirectory,
    [string]$Version,
    [string[]]$Addons = @("NextCast", "Preydator")
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $OutputDirectory -or $OutputDirectory.Trim() -eq "") {
    $OutputDirectory = $root
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

function Get-VersionFromToc {
    param([string]$TocPath)

    if (-not (Test-Path -LiteralPath $TocPath)) {
        return $null
    }

    $versionLine = Select-String -Path $TocPath -Pattern '^##\s*Version\s*:\s*(.+)$' | Select-Object -First 1
    if (-not $versionLine) {
        return $null
    }

    $parsed = $versionLine.Matches[0].Groups[1].Value.Trim()
    if ($parsed -eq "") {
        return $null
    }

    return $parsed
}

function Build-AddonZip {
    param(
        [string]$AddonName,
        [string]$ResolvedVersion
    )

    $addonPath = Join-Path $root $AddonName
    if (-not (Test-Path -LiteralPath $addonPath)) {
        Write-Warning ("Skipping {0}: folder not found." -f $AddonName)
        return
    }

    $stagingRoot = Join-Path $root ".release-staging"
    $stagingAddonPath = Join-Path $stagingRoot $AddonName

    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $stagingAddonPath -Force | Out-Null

    Get-ChildItem -LiteralPath $addonPath -Force | Where-Object {
        $_.Name -ne ".git" -and
        $_.Name -ne ".github" -and
        $_.Name -ne ".vscode" -and
        $_.Name -ne ".release-staging" -and
        $_.Name -ne "issues" -and
        $_.Name -ne "build-release.ps1" -and
        $_.Name -ne "ROADMAP.md" -and
        $_.Name -ne ".gitattributes" -and
        $_.Name -ne ".gitignore"
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stagingAddonPath -Recurse -Force
    }

    $zipPath = Join-Path $OutputDirectory ("{0}-{1}.zip" -f $AddonName, $ResolvedVersion)
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal -Force
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force

    Write-Host ("Created: {0}" -f $zipPath)
}

foreach ($addon in $Addons) {
    $addonPath = Join-Path $root $addon
    $tocPath = Join-Path $addonPath ("{0}.toc" -f $addon)

    $resolvedVersion = $Version
    if (-not $resolvedVersion -or $resolvedVersion.Trim() -eq "") {
        $resolvedVersion = Get-VersionFromToc -TocPath $tocPath
    }

    if (-not $resolvedVersion -or $resolvedVersion.Trim() -eq "") {
        Write-Warning ("Skipping {0}: no version found in TOC and -Version not provided." -f $addon)
        continue
    }

    Build-AddonZip -AddonName $addon -ResolvedVersion $resolvedVersion
}
