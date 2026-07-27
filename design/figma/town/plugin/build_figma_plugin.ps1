param(
	[string]$PluginDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

$templatePath = Join-Path $PluginDirectory "code.template.js"
$outputPath = Join-Path $PluginDirectory "code.js"
$townDirectory = Split-Path $PluginDirectory -Parent
$vectorDirectory = Join-Path $townDirectory "vector_sources"

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

$template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
$result = $template.
	Replace("__TOWN_SVG_ASSETS__", ($svgAssets | ConvertTo-Json -Compress -Depth 4)).
	Replace("__TOWN_REFERENCE_ASSETS__", ($referenceAssets | ConvertTo-Json -Compress -Depth 4))

[IO.File]::WriteAllText($outputPath, $result, [Text.UTF8Encoding]::new($false))

Write-Output "Built $outputPath"
Write-Output "Vector sources: $($svgAssets.Count)"
Write-Output "Raster references: $($referenceAssets.Count)"
