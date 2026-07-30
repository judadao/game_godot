param(
	[string]$PluginDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

$templatePath = Join-Path $PluginDirectory "code.template.js"
$outputPath = Join-Path $PluginDirectory "code.js"
$townDirectory = Split-Path $PluginDirectory -Parent
$vectorDirectory = Join-Path $townDirectory "vector_sources"
$b2Directory = Join-Path $townDirectory "b2_candidates"
$repositoryRoot = Split-Path (Split-Path (Split-Path $townDirectory -Parent) -Parent) -Parent
$b2ReferencePath = Join-Path $repositoryRoot "concept/town/main_horizontal_concept/town_style_direction_a_locked.png"

$svgAssets = [ordered]@{}
Get-ChildItem -LiteralPath $vectorDirectory -Filter "*.svg" -File |
	Sort-Object Name |
	ForEach-Object {
		$svgAssets[$_.BaseName] = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
	}

$referenceAssets = [ordered]@{}
Get-ChildItem -LiteralPath $townDirectory -Filter "*.png" -File |
	Sort-Object Name |
	ForEach-Object {
		$referenceAssets[$_.BaseName] = [Convert]::ToBase64String(
			[IO.File]::ReadAllBytes($_.FullName)
		)
	}

$b2Assets = [ordered]@{}
Get-ChildItem -LiteralPath $b2Directory -Filter "*.png" -File |
	Sort-Object Name |
	ForEach-Object {
		$b2Assets[$_.BaseName] = [Convert]::ToBase64String(
			[IO.File]::ReadAllBytes($_.FullName)
		)
	}

$b2ReferenceAsset = [Convert]::ToBase64String(
	[IO.File]::ReadAllBytes($b2ReferencePath)
)

$template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
$result = $template.
	Replace("__TOWN_SVG_ASSETS__", ($svgAssets | ConvertTo-Json -Compress -Depth 4)).
	Replace("__TOWN_REFERENCE_ASSETS__", ($referenceAssets | ConvertTo-Json -Compress -Depth 4)).
	Replace("__TOWN_B2_REVIEW_ASSETS__", ($b2Assets | ConvertTo-Json -Compress -Depth 4)).
	Replace("__TOWN_B2_REFERENCE_ASSET__", ($b2ReferenceAsset | ConvertTo-Json -Compress))

[IO.File]::WriteAllText($outputPath, $result, [Text.UTF8Encoding]::new($false))

Write-Output "Built $outputPath"
Write-Output "Vector sources: $($svgAssets.Count)"
Write-Output "Raster references: $($referenceAssets.Count)"
Write-Output "B2 review assets: $($b2Assets.Count)"
