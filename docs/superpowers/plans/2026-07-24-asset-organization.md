# Asset Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all useful content from seven CraftPix archives into a scene-friendly `assets/` hierarchy while preserving editable sources, licenses, and the original ZIP files.

**Architecture:** Use a temporary staging directory for safe extraction, then copy each known archive into one predetermined asset-pack directory. A repository-local PowerShell script owns filtering, path normalization at the pack/format-directory level, collision detection, and verification so the operation is repeatable and auditable.

**Tech Stack:** PowerShell 7/Windows PowerShell, .NET `System.IO.Compression`, Git, Godot 4

## Global Constraints

- Keep every original ZIP archive unchanged in `D:\game\素材`.
- Retain PNG, PSD, EPS, AI, ASEPRITE, Tiled files, licenses, and useful documentation.
- Exclude `__MACOSX`, `.DS_Store`, coupon files, promotional files, and `.url` shortcuts.
- Use lowercase snake_case for asset-pack and top-level format-directory names.
- Preserve internal filenames so editable-source and Tiled references are not broken.
- Never silently overwrite a different file.
- Do not create scenes, TileSet resources, import settings, animations, or gameplay scripts.

---

### Task 1: Create the repeatable asset organizer

**Files:**
- Create: `tools/organize_assets.ps1`
- Test: PowerShell dry-run output against `D:\game\素材`

**Interfaces:**
- Consumes: `-SourceDirectory`, `-ProjectDirectory`, and optional `-DryRun`
- Produces: classified files under `assets/` and a nonzero exit code for missing archives or content collisions

- [ ] **Step 1: Define the archive-to-destination map**

Create `tools/organize_assets.ps1` with strict mode, parameters, and an ordered map containing these exact pairs:

```powershell
param(
    [string]$SourceDirectory = 'D:\game\素材',
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
```

- [ ] **Step 2: Add explicit filtering and classification helpers**

Add helpers that:

- reject any path segment named `__MACOSX`;
- reject `.DS_Store`, `.url`, `COUPON.pdf`, and `COUPON.png`;
- reject files whose basename is `Free Assets Craftpix!`;
- route `License.txt`, `license.txt`, `readme.txt`, and files under `TXT/` to `assets/licenses/<pack_name>/`;
- preserve all other relative paths, changing only a leading known format directory (`PNG`, `PSD`, `EPS`, `AI`, `ASEPRITE`, `Tiled_files`) to lowercase snake_case.

- [ ] **Step 3: Add staged extraction and collision protection**

For every archive:

1. Verify the ZIP exists.
2. Extract it beneath a unique directory created with `New-Item` under the system temporary directory.
3. Enumerate files with `Get-ChildItem -File -Recurse`.
4. Apply the filtering and destination helpers.
5. If a destination exists, compare SHA-256 hashes with `Get-FileHash`.
6. Skip identical files; throw on different content at the same path.
7. In dry-run mode, print planned destination paths without copying.
8. Otherwise create parent directories and use `Copy-Item -LiteralPath`.
9. Remove only the verified unique staging directory in a `finally` block.

- [ ] **Step 4: Run a syntax and dry-run check**

Run:

```powershell
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path '.\tools\organize_assets.ps1'),
    [ref]$null,
    [ref]$errors
)
if ($errors.Count -gt 0) { $errors | Format-List; exit 1 }
.\tools\organize_assets.ps1 -DryRun
```

Expected: exit code `0`, no parser errors, all seven pack destinations listed, and no files copied into `assets/`.

- [ ] **Step 5: Commit the organizer**

```powershell
git add -- tools/organize_assets.ps1
git commit -m "Add asset organization script"
```

### Task 2: Extract and classify all asset packs

**Files:**
- Create: `assets/environments/autumn_forest/**`
- Create: `assets/environments/crystal_caves/**`
- Create: `assets/environments/forbidden_graveyard/**`
- Create: `assets/props/dungeon_objects/**`
- Create: `assets/props/magic_book/**`
- Create: `assets/ui/basic_rpg_ui/**`
- Create: `assets/ui/fantasy_icons_16x16/**`
- Create: `assets/licenses/**`
- Delete: `assets/.gitkeep`

**Interfaces:**
- Consumes: `tools/organize_assets.ps1` from Task 1 and the seven source ZIP files
- Produces: the complete classified asset tree used by future Godot scene tasks

- [ ] **Step 1: Record source ZIP hashes**

Run:

```powershell
Get-ChildItem -LiteralPath 'D:\game\素材' -Filter '*.zip' |
    Sort-Object Name |
    Get-FileHash -Algorithm SHA256
```

Expected: exactly seven hash records. Keep this output for the post-extraction comparison.

- [ ] **Step 2: Execute the organizer**

Run:

```powershell
.\tools\organize_assets.ps1
```

Expected: exit code `0`, seven populated pack directories, and license directories for all packs that contain license/readme files.

- [ ] **Step 3: Remove the obsolete placeholder**

After confirming `assets/` contains extracted files, remove only:

```powershell
Remove-Item -LiteralPath '.\assets\.gitkeep'
```

- [ ] **Step 4: Verify retained formats and exclusions**

Run:

```powershell
$requiredPacks = @(
    'assets/environments/autumn_forest',
    'assets/environments/crystal_caves',
    'assets/environments/forbidden_graveyard',
    'assets/props/dungeon_objects',
    'assets/props/magic_book',
    'assets/ui/basic_rpg_ui',
    'assets/ui/fantasy_icons_16x16'
)
$missing = $requiredPacks | Where-Object { -not (Test-Path -LiteralPath $_) }
if ($missing) { $missing; exit 1 }

$forbidden = Get-ChildItem -LiteralPath '.\assets' -Recurse -Force |
    Where-Object {
        $_.FullName -match '(^|[\\/])__MACOSX([\\/]|$)' -or
        $_.Name -in @('.DS_Store', 'COUPON.pdf', 'COUPON.png') -or
        $_.Extension -eq '.url'
    }
if ($forbidden) { $forbidden.FullName; exit 1 }

Get-ChildItem -LiteralPath '.\assets' -File -Recurse |
    Group-Object Extension |
    Sort-Object Name |
    Select-Object Name, Count
```

Expected: no missing packs, no forbidden files, and counts showing runtime plus editable-source formats present in the source archives.

- [ ] **Step 5: Confirm source archives are unchanged**

Repeat the hash command from Step 1 and compare all seven SHA-256 values.

Expected: every filename and hash exactly matches the pre-extraction output.

- [ ] **Step 6: Commit the organized assets**

```powershell
git add -- assets
git commit -m "Organize CraftPix game assets"
```

### Task 3: Validate repository and Godot import

**Files:**
- Verify: `project.godot`
- Verify: `assets/**`

**Interfaces:**
- Consumes: the classified asset tree from Task 2
- Produces: evidence that repository paths are valid and Godot can import the assets

- [ ] **Step 1: Check repository cleanliness rules**

Run:

```powershell
git diff --check HEAD^ HEAD
git status --short
```

Expected: no whitespace errors and no unexpected uncommitted files before Godot import.

- [ ] **Step 2: Run Godot's headless import**

Resolve the installed Godot executable, then run:

```powershell
godot --headless --editor --path . --quit
```

If Godot is not on `PATH`, invoke its full `.exe` path with the same arguments.

Expected: exit code `0` and no project load or asset import errors.

- [ ] **Step 3: Inspect final status**

Run:

```powershell
git status --short
```

Expected: only ignored `.godot/` import-cache changes, or an empty result.
