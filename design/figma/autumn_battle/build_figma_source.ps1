param(
	[string]$DesignDirectory = $PSScriptRoot
)

$sourcePath = Join-Path $DesignDirectory "autumn-hud-redesign-source.svg"
$backgroundPath = Join-Path $DesignDirectory "autumn-map-background.png"
$outputPath = Join-Path $DesignDirectory "autumn-hud-redesign-figma.svg"

if (-not (Test-Path -LiteralPath $sourcePath)) {
	throw "Missing SVG source: $sourcePath"
}
if (-not (Test-Path -LiteralPath $backgroundPath)) {
	throw "Missing map background: $backgroundPath"
}

$svg = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
$backgroundBase64 = [Convert]::ToBase64String(
	[System.IO.File]::ReadAllBytes($backgroundPath)
)
$externalReference = 'href="autumn-map-background.png" xlink:href="autumn-map-background.png"'
$embeddedReference = 'href="data:image/png;base64,' + $backgroundBase64 + '"'

if (-not $svg.Contains($externalReference)) {
	throw "Expected external background reference was not found."
}

$selfContainedSvg = $svg.Replace($externalReference, $embeddedReference)
[System.IO.File]::WriteAllText(
	$outputPath,
	$selfContainedSvg,
	[System.Text.UTF8Encoding]::new($false)
)

Write-Output $outputPath
