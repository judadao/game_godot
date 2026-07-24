[CmdletBinding()]
param(
    [string]$SourceDirectory,
    [string]$ProjectDirectory = (Split-Path -Parent $PSScriptRoot),
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$archiveMap = [ordered]@{
    'craftpix-net-763418-free-autumn-forest-2d-platformer-tileset.zip' = 'environments\autumn_forest'
    'craftpix-net-376431-free-crystal-caves-2d-platformer-tileset.zip' = 'environments\crystal_caves'
    'craftpix-net-929602-free-forbidden-graveyard-2d-platformer-tileset.zip' = 'environments\forbidden_graveyard'
    'craftpix-net-218281-free-pixel-art-dungeon-objects-asset-pack.zip' = 'props\dungeon_objects'
    'craftpix-net-809047-free-animated-magic-book-pixel-art-asset-pack.zip' = 'props\magic_book'
    'craftpix-net-255216-free-basic-pixel-art-ui-for-rpg.zip' = 'ui\basic_rpg_ui'
    'craftpix-net-994534-free-basic-pixel-art-fantasy-icons-16x16-for-ui.zip' = 'ui\fantasy_icons_16x16'
}

$formatDirectories = @{
    'PNG' = 'png'
    'PSD' = 'psd'
    'EPS' = 'eps'
    'AI' = 'ai'
    'ASEPRITE' = 'aseprite'
    'Tiled_files' = 'tiled_files'
}

function Test-ExcludedAsset {
    param([Parameter(Mandatory)][string]$RelativePath)

    $segments = $RelativePath -split '[\\/]'
    if ($segments -contains '__MACOSX') {
        return $true
    }

    $fileName = [System.IO.Path]::GetFileName($RelativePath)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    if ($fileName -in @('.DS_Store', 'COUPON.pdf', 'COUPON.png')) {
        return $true
    }
    if ([System.IO.Path]::GetExtension($fileName) -ieq '.url') {
        return $true
    }
    if ($baseName -ieq 'Free Assets Craftpix!') {
        return $true
    }

    return $false
}

function Get-NormalizedRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $segments = @($RelativePath -split '[\\/]')
    if ($segments.Count -gt 0 -and $formatDirectories.ContainsKey($segments[0])) {
        $segments[0] = $formatDirectories[$segments[0]]
    }
    return ($segments -join [System.IO.Path]::DirectorySeparatorChar)
}

function Test-LicenseDocument {
    param([Parameter(Mandatory)][string]$RelativePath)

    $segments = @($RelativePath -split '[\\/]')
    $fileName = [System.IO.Path]::GetFileName($RelativePath)
    return (
        $fileName -ieq 'License.txt' -or
        $fileName -ieq 'readme.txt' -or
        ($segments.Count -gt 1 -and $segments[0] -ieq 'TXT')
    )
}

function Get-LicenseRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $segments = @($RelativePath -split '[\\/]')
    if ($segments.Count -gt 1 -and $segments[0] -ieq 'TXT') {
        return (($segments | Select-Object -Skip 1) -join [System.IO.Path]::DirectorySeparatorChar)
    }
    return [System.IO.Path]::GetFileName($RelativePath)
}

function Assert-SafeStagingPath {
    param(
        [Parameter(Mandatory)][string]$StagingPath,
        [Parameter(Mandatory)][string]$TemporaryRoot
    )

    $resolvedStaging = [System.IO.Path]::GetFullPath($StagingPath)
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($TemporaryRoot).TrimEnd('\') + '\'
    if (-not $resolvedStaging.StartsWith(
        $resolvedTemporaryRoot,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unsafe staging path: $resolvedStaging"
    }
}

if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
    $searchRoot = Split-Path -Parent $ProjectDirectory
    $firstArchiveName = $archiveMap.Keys | Select-Object -First 1
    $sourceCandidates = Get-ChildItem -LiteralPath $searchRoot -Directory |
        Where-Object {
            Test-Path -LiteralPath (Join-Path $_.FullName $firstArchiveName) -PathType Leaf
        }
    if (@($sourceCandidates).Count -ne 1) {
        throw "Expected exactly one source directory beneath $searchRoot; found $(@($sourceCandidates).Count)."
    }
    $SourceDirectory = @($sourceCandidates)[0].FullName
}

if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
    throw "Source directory does not exist: $SourceDirectory"
}
if (-not (Test-Path -LiteralPath $ProjectDirectory -PathType Container)) {
    throw "Project directory does not exist: $ProjectDirectory"
}

$assetsRoot = Join-Path $ProjectDirectory 'assets'
$temporaryRoot = [System.IO.Path]::GetTempPath()
$totalPlanned = 0
$totalCopied = 0
$totalSkipped = 0

foreach ($entry in $archiveMap.GetEnumerator()) {
    $archivePath = Join-Path $SourceDirectory $entry.Key
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "Required archive does not exist: $archivePath"
    }

    $packRelativePath = $entry.Value
    $packName = Split-Path $packRelativePath -Leaf
    $stagingPath = Join-Path $temporaryRoot ("game_godot_assets_" + [guid]::NewGuid().ToString('N'))
    Assert-SafeStagingPath -StagingPath $stagingPath -TemporaryRoot $temporaryRoot
    [void](New-Item -ItemType Directory -Path $stagingPath)

    $packPlanned = 0
    $packCopied = 0
    $packSkipped = 0

    try {
        Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingPath
        $files = Get-ChildItem -LiteralPath $stagingPath -File -Recurse

        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($stagingPath.Length).TrimStart('\', '/')
            if (Test-ExcludedAsset -RelativePath $relativePath) {
                $packSkipped++
                continue
            }

            if (Test-LicenseDocument -RelativePath $relativePath) {
                $licenseRelativePath = Get-LicenseRelativePath -RelativePath $relativePath
                $destinationPath = Join-Path $assetsRoot (
                    Join-Path 'licenses' (Join-Path $packName $licenseRelativePath)
                )
            } else {
                $normalizedRelativePath = Get-NormalizedRelativePath -RelativePath $relativePath
                $destinationPath = Join-Path $assetsRoot (
                    Join-Path $packRelativePath $normalizedRelativePath
                )
            }

            $packPlanned++
            if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
                $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
                if ($sourceHash -ne $destinationHash) {
                    throw "Content collision at destination: $destinationPath"
                }
                continue
            }

            if ($DryRun) {
                Write-Verbose "PLAN $destinationPath"
                continue
            }

            $destinationDirectory = Split-Path -Parent $destinationPath
            if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
                [void](New-Item -ItemType Directory -Path $destinationDirectory -Force)
            }
            Copy-Item -LiteralPath $file.FullName -Destination $destinationPath
            $packCopied++
        }
    } finally {
        Assert-SafeStagingPath -StagingPath $stagingPath -TemporaryRoot $temporaryRoot
        if (Test-Path -LiteralPath $stagingPath) {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force
        }
    }

    $totalPlanned += $packPlanned
    $totalCopied += $packCopied
    $totalSkipped += $packSkipped
    $mode = if ($DryRun) { 'DRY-RUN' } else { 'COPIED' }
    Write-Output ("[{0}] {1}: retained={2}, copied={3}, excluded={4}" -f
        $mode, $packName, $packPlanned, $packCopied, $packSkipped)
}

Write-Output ("Complete: retained={0}, copied={1}, excluded={2}" -f
    $totalPlanned, $totalCopied, $totalSkipped)
