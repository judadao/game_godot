#!/usr/bin/env bash
set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
SUITE="all"
PATTERN=""
RUN_SMOKE=0
FAIL_FAST=0
KEEP_LOGS=0
LIST_ONLY=0
STRICT_WARNINGS=0
MAIN_FRAMES=300
RUN_ID="$(date +%Y%m%d_%H%M%S)_$$"
ARTIFACT_ROOT="$ROOT_DIR/.test_userdata/godot_tests/$RUN_ID"
LOG_ROOT="$ARTIFACT_ROOT/logs"
FAILURES=()
RAN=0
PASSED=0

BASE_MARKERS='SCRIPT ERROR|Parse Error|ERROR:|Invalid call|Previously freed|Node not found'

usage() {
	cat <<'EOF'
Usage: tools/run_godot_tests.sh [options]

Options:
  --suite NAME          Test suite: all, maintenance, assets, cards, combat, vfx, maps, scene, systems, forge, story, town, autumn, ui, smoke.
  --pattern REGEX       Run tests whose path matches REGEX after suite filtering.
  --smoke               Also run editor and main-scene smoke checks.
  --fail-fast           Stop at the first failing test or smoke check.
  --strict-warnings     Treat Godot WARNING lines as failures.
  --main-frames N       Frames for main-scene smoke; default: 300.
  --godot PATH          Godot executable; default: $GODOT_BIN or godot.
  --keep-logs           Keep .test_userdata/godot_tests/<run-id> after completion.
  --list                Print selected tests without running them.
  -h, --help            Show this help.
EOF
}

fail() {
	printf 'ERROR: %s\n' "$1" >&2
	exit 2
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--suite)
			[[ $# -ge 2 ]] || fail "--suite requires a value"
			SUITE="$2"
			shift 2
			;;
		--pattern)
			[[ $# -ge 2 ]] || fail "--pattern requires a value"
			PATTERN="$2"
			shift 2
			;;
		--smoke)
			RUN_SMOKE=1
			shift
			;;
		--fail-fast)
			FAIL_FAST=1
			shift
			;;
		--strict-warnings)
			STRICT_WARNINGS=1
			shift
			;;
		--main-frames)
			[[ $# -ge 2 ]] || fail "--main-frames requires a value"
			MAIN_FRAMES="$2"
			shift 2
			;;
		--godot)
			[[ $# -ge 2 ]] || fail "--godot requires a value"
			GODOT_BIN="$2"
			shift 2
			;;
		--keep-logs)
			KEEP_LOGS=1
			shift
			;;
		--list)
			LIST_ONLY=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			fail "Unknown option: $1"
			;;
	esac
done

command -v "$GODOT_BIN" >/dev/null 2>&1 || fail "Godot executable not found: $GODOT_BIN"

marker_pattern() {
	if [[ "$STRICT_WARNINGS" -eq 1 ]]; then
		printf '%s|WARNING:' "$BASE_MARKERS"
	else
		printf '%s' "$BASE_MARKERS"
	fi
}

matches_suite() {
	local path="$1"
	case "$SUITE" in
		all) return 0 ;;
		smoke) return 1 ;;
		maintenance) [[ "$path" =~ asset_classification|combat_target_adapter|ui_value_formatter|codex_text_formatter|quick_save_service|maintenance_scope_map|content_validation|scene_feature_directory|scene_registry ]] ;;
		assets) [[ "$path" =~ asset|content_validation|texture|visual_source ]] ;;
		cards) [[ "$path" =~ card|deck|combo|growth|skill|fixed|hand|projectile ]] ;;
		combat) [[ "$path" =~ combat|boss|enemy|encounter|survival|auto_attack|auto_horizontal|experience_gem|dash|potion|wandering_merchant|power_fantasy|lightning|moon_wheel|feather|black_hole|dr_stone|thorn|swamp|dragon_breath|fire_pillar|tidal ]] ;;
		vfx) [[ "$path" =~ vfx|visual|effect|lightning|moon_wheel|feather|black_hole|thorn|swamp|dr_stone|dragon_breath|fire_pillar|tidal ]] ;;
		maps) [[ "$path" =~ map|town|battle_portal|vertical_slice|campfire ]] ;;
		scene) [[ "$path" =~ scene|content_validation|map_layout|map_main|interactive ]] ;;
		systems) [[ "$path" =~ registry|migration|progression|run_|save|collection|state|memory|recipe ]] ;;
		forge) [[ "$path" =~ forge|blacksmith|market|material_yard|shop|equipment|town_building ]] ;;
		story) [[ "$path" =~ story|dialogue|codex|journal ]] ;;
		town) [[ "$path" =~ town|shop|inventory|merchant ]] ;;
		autumn) [[ "$path" =~ autumn|battle_map|survival|boss|encounter|combat_camera ]] ;;
		ui) [[ "$path" =~ ui|hud|layout|card_hand|card_growth|deck_builder|dialogue|shop|inventory|pause|run_result|interaction_prompt ]] ;;
		*) fail "Unknown suite: $SUITE" ;;
	esac
}

selected_tests=()
while IFS= read -r test_file; do
	if ! matches_suite "$test_file"; then
		continue
	fi
	if [[ -n "$PATTERN" ]] && ! [[ "$test_file" =~ $PATTERN ]]; then
		continue
	fi
	selected_tests+=("$test_file")
done < <(cd "$ROOT_DIR" && find tests -maxdepth 1 -name '*_test.gd' -print | sort)

if [[ "$LIST_ONLY" -eq 1 ]]; then
	printf '%s\n' "${selected_tests[@]}"
	exit 0
fi

if [[ "$SUITE" != "smoke" && "${#selected_tests[@]}" -eq 0 ]]; then
	fail "No tests selected for suite '$SUITE' and pattern '${PATTERN:-<none>}'"
fi

mkdir -p "$LOG_ROOT"

run_with_isolation() {
	local name="$1"
	shift
	export APPDATA="$ARTIFACT_ROOT/userdata/$name/appdata"
	export XDG_DATA_HOME="$ARTIFACT_ROOT/userdata/$name/xdg_data"
	export XDG_CONFIG_HOME="$ARTIFACT_ROOT/userdata/$name/xdg_config"
	export XDG_CACHE_HOME="$ARTIFACT_ROOT/userdata/$name/xdg_cache"
	mkdir -p "$APPDATA" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
	"$@"
}

record_failure() {
	local label="$1"
	FAILURES+=("$label")
	if [[ "$FAIL_FAST" -eq 1 ]]; then
		return 1
	fi
	return 0
}

run_test() {
	local test_file="$1"
	local name
	name="$(basename "$test_file" .gd)"
	local log_file="$LOG_ROOT/$name.log"
	RAN=$((RAN + 1))
	printf 'RUN  %s\n' "$test_file"
	run_with_isolation "$name" "$GODOT_BIN" --headless --path "$ROOT_DIR" --script "res://$test_file" >"$log_file" 2>&1
	local status=$?
	local markers
	markers="$(marker_pattern)"
	if [[ "$status" -ne 0 ]] || rg -q "$markers" "$log_file"; then
		printf 'FAIL %s status=%s log=%s\n' "$test_file" "$status" "$log_file"
		rg -n "$markers" "$log_file" || true
		record_failure "$test_file"
		return $?
	fi
	printf 'PASS %s\n' "$test_file"
	PASSED=$((PASSED + 1))
	return 0
}

run_smoke_check() {
	local label="$1"
	shift
	local log_file="$LOG_ROOT/$label.log"
	printf 'RUN  smoke:%s\n' "$label"
	run_with_isolation "smoke_$label" "$@" >"$log_file" 2>&1
	local status=$?
	local markers
	markers="$(marker_pattern)"
	if [[ "$status" -ne 0 ]] || rg -q "$markers" "$log_file"; then
		printf 'FAIL smoke:%s status=%s log=%s\n' "$label" "$status" "$log_file"
		rg -n "$markers" "$log_file" || true
		record_failure "smoke:$label"
		return $?
	fi
	printf 'PASS smoke:%s\n' "$label"
	return 0
}

if [[ "$SUITE" != "smoke" ]]; then
	for test_file in "${selected_tests[@]}"; do
		run_test "$test_file" || break
	done
fi

if [[ "$RUN_SMOKE" -eq 1 || "$SUITE" == "smoke" ]]; then
	run_smoke_check "editor" "$GODOT_BIN" --headless --editor --path "$ROOT_DIR" --quit
	if [[ "${#FAILURES[@]}" -eq 0 || "$FAIL_FAST" -eq 0 ]]; then
		run_smoke_check "main" "$GODOT_BIN" --headless --path "$ROOT_DIR" --quit-after "$MAIN_FRAMES"
	fi
fi

printf 'TOTAL tests=%d passed=%d failures=%d logs=%s\n' "$RAN" "$PASSED" "${#FAILURES[@]}" "$LOG_ROOT"
if [[ "${#FAILURES[@]}" -gt 0 ]]; then
	printf 'FAILED:%s\n' " ${FAILURES[*]}"
	exit 1
fi

if [[ "$KEEP_LOGS" -eq 0 ]]; then
	rm -rf "$ARTIFACT_ROOT"
else
	printf 'KEPT logs at %s\n' "$LOG_ROOT"
fi
