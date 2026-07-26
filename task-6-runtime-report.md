# Task 6 Runtime Report

## Scope

Base commit: `30ab5bb` (`Harden queued growth resolution`).

This runtime slice:

- connects `GrowthChoiceQueue.current_changed` to the single `CardGrowthUI`;
- routes `choice_confirmed` through the Task 5 `_confirm_growth_action()` authority;
- keeps unresolved choices open across UI close, Escape, pause, and generic stack-close paths;
- drains queued entries in FIFO order without recreating the modal;
- adds reference-counted, owner-keyed modal pause ownership;
- keeps `Game`, HUD, and modal UI always-processing while making `MapRoot` explicitly pausable;
- resumes only after the growth queue and all other modal pause owners release;
- removes the obsolete LevelUp scene, script, test, and UID files;
- updates content validation to require `CardGrowthUI` and reject obsolete LevelUp content.

No `CardGrowthUI` scene/script/test or `test_ui_keyboard.gd` implementation files were edited.

## RED to GREEN Evidence

1. `growth_pause_integration_test.gd` initially failed because `Game` had no owner-key pause API, did not open `CardGrowthUI`, did not pause, and advanced AP/combo time.
2. The same test then failed because generic `close_top_ui()` dismissed an unresolved growth modal.
3. The map-subtree assertion then failed because `MapRoot` inherited `Game.PROCESS_MODE_ALWAYS`.
4. `content_validation_test.gd` failed while the obsolete LevelUp scene and script still existed.

Each failure was observed with a bounded command using:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 20 --script res://tests/<test>.gd
```

All four contracts are now GREEN.

## Final Verification

The following bounded tests passed with isolated `APPDATA` directories:

- `tests/growth_pause_integration_test.gd`
- `tests/content_validation_test.gd`
- `tests/growth_choice_queue_test.gd`
- `tests/run_card_growth_test.gd`
- `tests/card_growth_ui_test.gd` (all six required viewport sizes)
- `tests/test_ui_keyboard.gd`
- `tests/timed_combo_window_test.gd`
- `tests/vertical_slice_flow_test.gd`
- `tests/town_runtime_ui_test.gd`
- `tests/town_autumn_portal_flow_test.gd`

Additional smoke checks passed:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit-after 30 --quit
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 5
```

## Cross-task Regression

`tests/card_combat_integration_test.gd` remains failing outside this Task 6
scope with the exact assertion:

```text
ERROR: Played cards must enter discard.
at: _expect (res://tests/card_combat_integration_test.gd:138)
at: _run (res://tests/card_combat_integration_test.gd:52)
```

Per coordination direction, this is recorded for Task 8/full-suite repair.
Task 6 does not alter deck play or discard semantics.
