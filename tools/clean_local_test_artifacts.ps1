param(
	[switch]$WhatIf
)

$workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$protectedDirectoryNames = @(".git", ".godot")
$artifactPatterns = @(
	".codex_test_*",
	".debug*",
	".final_*",
	".review*",
	".smoke*",
	".test_userdata",
	".tmp*",
	".verify*",
	".superpowers"
)

$artifactDirectories = @(
	Get-ChildItem -LiteralPath $workspaceRoot -Force -Directory |
		Where-Object {
			$directoryName = $_.Name
			-not $protectedDirectoryNames.Contains($directoryName) -and
			$null -ne ($artifactPatterns | Where-Object {
				$directoryName -like $_
			} | Select-Object -First 1)
		}
)
$artifactLogs = @(
	Get-ChildItem -LiteralPath $workspaceRoot -Force -File -Filter "*.log"
)

foreach ($directory in $artifactDirectories) {
	if ($directory.Parent.FullName -ne $workspaceRoot) {
		throw "Refusing to remove a directory outside the workspace root: $($directory.FullName)"
	}
	if ($protectedDirectoryNames.Contains($directory.Name)) {
		throw "Refusing to remove protected directory: $($directory.FullName)"
	}
}
foreach ($logFile in $artifactLogs) {
	if ($logFile.Directory.FullName -ne $workspaceRoot) {
		throw "Refusing to remove a log outside the workspace root: $($logFile.FullName)"
	}
}

Write-Output (
	"Cleaning {0} artifact directories and {1} root log files under {2}" -f
	$artifactDirectories.Count,
	$artifactLogs.Count,
	$workspaceRoot
)

foreach ($directory in $artifactDirectories) {
	Remove-Item `
		-LiteralPath $directory.FullName `
		-Recurse `
		-Force `
		-WhatIf:$WhatIf `
		-ErrorAction Stop
}
foreach ($logFile in $artifactLogs) {
	Remove-Item `
		-LiteralPath $logFile.FullName `
		-Force `
		-WhatIf:$WhatIf `
		-ErrorAction Stop
}

Write-Output "Local test artifact cleanup complete."
