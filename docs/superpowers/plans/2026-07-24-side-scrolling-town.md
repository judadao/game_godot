# Side-Scrolling Town Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `scenes/maps/town.tscn` into a playable side-scrolling RPG town prototype.

**Architecture:** Keep the town as a single Godot `Node2D` scene with explicit visual layers and simple physics nodes. Add one focused player movement script for prototype traversal.

**Tech Stack:** Godot 4.7 text scenes, GDScript, curated PNG assets under `concept/town/can_use/`.

## Global Constraints

- Use only existing repository assets.
- Treat `concept/town/can_use/` assets as prototype-only.
- Keep world sprites visually layered by node groups.
- Keep interaction logic out of scope for this pass.

---

### Task 1: Player Prototype Movement

**Files:**
- Create: `scripts/player/player_controller.gd`

**Interfaces:**
- Produces: a `CharacterBody2D` script with exported `speed`, `gravity`, and `jump_velocity`.

- [x] Create a small side-scroller controller using Godot's built-in `ui_left`, `ui_right`, and `ui_accept` actions.
- [x] Keep the player usable without custom input-map changes.

### Task 2: Town Scene Assembly

**Files:**
- Modify: `scenes/maps/town.tscn`

**Interfaces:**
- Consumes: `scripts/player/player_controller.gd` and PNG assets from `concept/town/can_use/`.
- Produces: a layered town with camera limits, floor collision, and visible RPG town dressing.

- [x] Add external resources for backgrounds, buildings, props, NPCs, and the player script.
- [x] Add layered `Node2D` groups for `ParallaxBackground`, `Ground`, `Buildings`, `Props`, `NPCs`, `Player`, `Camera2D`, and `WorldCollision`.
- [x] Place the player near the left side and limit camera movement across the street width.

### Task 3: Verification

**Files:**
- Validate: `scenes/maps/town.tscn`
- Validate: `scripts/player/player_controller.gd`

- [x] Run a headless Godot parse/load check.
- [x] Inspect git diff for expected files only.
