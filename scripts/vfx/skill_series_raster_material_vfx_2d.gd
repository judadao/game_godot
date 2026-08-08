class_name SkillSeriesRasterMaterialVFX2D
extends Node2D

const MUTATION_CATALOG := preload("res://scripts/vfx/blessing_vfx_mutation_catalog.gd")
const FALLBACK_ROLES := ["contact", "travel", "residual"]
const PHASE_ORDER := ["anticipation", "travel", "contact", "residual"]
const TIER_IDS := ["basic", "advanced", "master"]

var _recipe: Dictionary = {}
var _runtime: Dictionary = {}
var _composition: Dictionary = {}
var _tier := 1
var _component_sprites: Array[Sprite2D] = []
var _component_roles: Array[String] = []
var _component_sources: Array[String] = []
var _component_ordinals: Array[int] = []
var _component_specs: Array[Dictionary] = []
var _atlas_regions: Array[Dictionary] = []
var _role_counts: Dictionary = {}
var _base_phase_layers: Dictionary = {}
var _source_phase_horizons: Dictionary = {}
var _resolved_elements: Array[String] = []
var _overlay_asset_paths: Array[String] = []
var _blessing_overlay_count := 0
var _variant_signature := ""
var _progress := 0.0
var _maximum_instances := 0
var _visible_travel_positions: Array[Vector2] = []
var _visible_base_travel_positions: Array[Vector2] = []
var _visible_contact_positions: Array[Vector2] = []
var _visible_residual_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func configure(recipe: Dictionary, tier_rank: int, blessing_overlays: Array = []) -> bool:
	clear()
	if recipe.is_empty():
		return false
	var material_path := String(recipe.get("material_asset_path", ""))
	if material_path.is_empty() or not ResourceLoader.exists(material_path, "Texture2D"):
		return false
	var base_texture := load(material_path) as Texture2D
	if base_texture == null:
		return false
	_recipe = recipe.duplicate(true)
	_runtime = (recipe.get("material_runtime", {}) as Dictionary).duplicate(true)
	_composition = (recipe.get("material_composition", {}) as Dictionary).duplicate(true)
	_tier = clampi(tier_rank, 1, 3)
	_maximum_instances = clampi(int(_runtime.get("max_instances", 24)), 7, 24)
	var candidate_elements := _candidate_elements(blessing_overlays)
	var reserved_overlay_instances := mini(candidate_elements.size(), 2) * 5
	var base_limit := maxi(5, _maximum_instances - reserved_overlay_instances)
	var built := false
	if not _composition.is_empty():
		built = _build_mapped_components(base_texture, _composition, "base", base_limit) > 0
	else:
		built = _build_fallback_base_components(base_texture)
	if not built:
		clear()
		return false
	if not _resolve_overlays(blessing_overlays):
		clear()
		return false
	_variant_signature = _build_variant_signature(material_path)
	visible = not _component_sprites.is_empty()
	return visible


func set_progress(
	value: float,
	source: Vector2,
	target: Vector2,
	impact_progress: float = 0.62,
	core_positions: Array = []
) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_visible_travel_positions.clear()
	_visible_base_travel_positions.clear()
	_visible_contact_positions.clear()
	_visible_residual_count = 0
	if _component_sprites.is_empty():
		return
	var displacement := target - source
	var direction := displacement.normalized() if not displacement.is_zero_approx() else Vector2.RIGHT
	var normal := direction.orthogonal()
	for index in _component_sprites.size():
		var spec := _component_specs[index]
		if bool(spec.get("mapped", false)):
			_update_mapped_component(index, source, target, impact_progress, direction, normal, core_positions)
		else:
			_update_fallback_component(index, source, target, impact_progress, displacement, normal)


func clear() -> void:
	for sprite in _component_sprites:
		if sprite != null and is_instance_valid(sprite):
			var parent := sprite.get_parent()
			if parent != null:
				parent.remove_child(sprite)
			sprite.free()
	_component_sprites.clear()
	_component_roles.clear()
	_component_sources.clear()
	_component_ordinals.clear()
	_component_specs.clear()
	_atlas_regions.clear()
	_role_counts.clear()
	_base_phase_layers.clear()
	_source_phase_horizons.clear()
	_resolved_elements.clear()
	_overlay_asset_paths.clear()
	_blessing_overlay_count = 0
	_variant_signature = ""
	_progress = 0.0
	_maximum_instances = 0
	_visible_travel_positions.clear()
	_visible_base_travel_positions.clear()
	_visible_contact_positions.clear()
	_visible_residual_count = 0
	_composition.clear()
	_runtime.clear()
	_recipe.clear()
	visible = false


func get_debug_state() -> Dictionary:
	var placements: Array[String] = []
	var component_snapshots: Array[Dictionary] = []
	for index in _component_specs.size():
		var spec := _component_specs[index]
		var debug_layer := spec.get("layer", {}) as Dictionary
		var placement := String(debug_layer.get("resolved_placement", debug_layer.get("placement", "")))
		if not placement.is_empty() and not placements.has(placement):
			placements.append(placement)
		var sprite := _component_sprites[index]
		component_snapshots.append({
			"role": _component_roles[index],
			"source": _component_sources[index],
			"anchor": String(debug_layer.get("resolved_anchor", debug_layer.get("anchor", ""))),
			"position": sprite.position,
			"alpha": sprite.modulate.a,
		})
	return {
		"presentation_only": true,
		"presentation_mode": "skill_series_raster_material",
		"recipe_id": String(_recipe.get("id", "")),
		"composition_id": String(_composition.get("id", "")),
		"material_asset_path": String(_recipe.get("material_asset_path", "")),
		"resolved_elements": _resolved_elements.duplicate(),
		"overlay_asset_paths": _overlay_asset_paths.duplicate(),
		"component_roles": _component_roles.duplicate(),
		"component_role_counts": _role_counts.duplicate(true),
		"placement_modes": placements,
		"component_snapshots": component_snapshots,
		"atlas_regions": _atlas_regions.duplicate(true),
		"uses_full_sheet": _uses_full_sheet(),
		"blessing_overlay_count": _blessing_overlay_count,
		"active_layer_count": _component_sprites.size(),
		"max_instance_count": _maximum_instances,
		"visible_travel_positions": _visible_travel_positions.duplicate(),
		"visible_base_travel_positions": _visible_base_travel_positions.duplicate(),
		"source_phase_horizons": _source_phase_horizons.duplicate(true),
		"visible_contact_positions": _visible_contact_positions.duplicate(),
		"visible_residual_count": _visible_residual_count,
		"variant_signature": _variant_signature,
		"progress": _progress,
	}


func get_active_layer_count() -> int:
	return _component_sprites.size()


func _build_mapped_components(
	texture: Texture2D,
	composition: Dictionary,
	source_id: String,
	instance_limit: int
) -> int:
	var requests := _mapped_requests(composition)
	if requests.is_empty():
		return -1
	_register_source_phase_horizons(source_id, requests)
	if source_id == "base":
		for request in requests:
			var request_dict := request as Dictionary
			var phase := String(request_dict.get("phase", ""))
			if not _base_phase_layers.has(phase):
				_base_phase_layers[phase] = (request_dict.get("layer", {}) as Dictionary).duplicate(true)
	var start_count := _component_sprites.size()
	var next_indices: Array[int] = []
	for request in requests:
		next_indices.append(0)
		if _component_sprites.size() < instance_limit:
			if not _add_mapped_sprite(texture, source_id, request, 0):
				return -1
			next_indices[next_indices.size() - 1] = 1
	var made_progress := true
	while _component_sprites.size() < instance_limit and made_progress:
		made_progress = false
		for request_index in requests.size():
			if _component_sprites.size() >= instance_limit:
				break
			var request := requests[request_index] as Dictionary
			var next_index := next_indices[request_index]
			if next_index >= int(request.get("count", 1)):
				continue
			if _add_mapped_sprite(texture, source_id, request, next_index):
				next_indices[request_index] = next_index + 1
				made_progress = true
	return _component_sprites.size() - start_count


func _register_source_phase_horizons(source_id: String, requests: Array[Dictionary]) -> void:
	for request in requests:
		var phase := String(request.get("phase", ""))
		var layer := request.get("layer", {}) as Dictionary
		var stack := layer.get("stack", {}) as Dictionary
		var requested_count := int(request.get("count", 1))
		var horizon := float(layer.get("delay_seconds", 0.0))
		horizon += float(maxi(0, requested_count - 1)) * float(stack.get("stagger_seconds", 0.0))
		horizon += float(layer.get("lifetime_seconds", 0.1))
		var key := "%s:%s" % [source_id, phase]
		_source_phase_horizons[key] = maxf(float(_source_phase_horizons.get(key, 0.1)), horizon)


func _mapped_requests(composition: Dictionary) -> Array[Dictionary]:
	var component_sources: Dictionary = {}
	for component_variant in composition.get("components", []) as Array:
		if component_variant is Dictionary:
			var component := component_variant as Dictionary
			component_sources[String(component.get("id", ""))] = {
				"source_region": (component.get("region", []) as Array).duplicate(),
				"asset_path": String(component.get("asset_path", "")),
				"asset_region": (component.get("asset_region", []) as Array).duplicate(),
			}
	var requests: Array[Dictionary] = []
	for stage_variant in composition.get("stages", []) as Array:
		if not stage_variant is Dictionary:
			continue
		var stage := stage_variant as Dictionary
		var phase := String(stage.get("phase", ""))
		for layer_variant in stage.get("layers", []) as Array:
			if not layer_variant is Dictionary:
				continue
			var layer := (layer_variant as Dictionary).duplicate(true)
			var component_source := component_sources.get(String(layer.get("component", "")), {}) as Dictionary
			var source_region := component_source.get("source_region", []) as Array
			var asset_region := component_source.get("asset_region", []) as Array
			var component_path := String(component_source.get("asset_path", ""))
			if component_path.is_empty() or asset_region.size() != 4 or not ResourceLoader.exists(component_path, "Texture2D"):
				return []
			var region := asset_region
			var stack := layer.get("stack", {}) as Dictionary
			var counts := stack.get("count_by_tier", {}) as Dictionary
			var count := int(counts.get(TIER_IDS[_tier - 1], 0))
			if PHASE_ORDER.has(phase) and region.size() == 4 and count > 0:
				requests.append({
					"phase": phase,
					"layer": layer,
					"region": region.duplicate(),
					"source_region": source_region.duplicate(),
					"asset_path": component_path,
					"count": count,
				})
	return requests


func _add_mapped_sprite(
	texture: Texture2D,
	source_id: String,
	request: Dictionary,
	stack_index: int
) -> bool:
	if _component_sprites.size() >= _maximum_instances:
		return false
	var phase := String(request.get("phase", ""))
	var component_path := String(request.get("asset_path", ""))
	if component_path.is_empty() or not ResourceLoader.exists(component_path, "Texture2D"):
		return false
	var component_texture := load(component_path) as Texture2D
	if component_texture == null:
		return false
	var source_kind := "isolated_component"
	var region_values := request.get("region", []) as Array
	var atlas := _pixel_atlas_texture(component_texture, region_values, source_kind == "isolated_component")
	if atlas == null:
		return false
	var layer := (request.get("layer", {}) as Dictionary).duplicate(true)
	var inherited_anchor := String(layer.get("anchor", "")).begins_with("inherit_base_")
	if source_id != "base" and inherited_anchor:
		var base_layer := _base_phase_layers.get(phase, {}) as Dictionary
		if base_layer.is_empty():
			return false
		layer["resolved_anchor"] = String(base_layer.get("anchor", "contact"))
		layer["resolved_placement"] = String(base_layer.get("placement", "contact_fan"))
	else:
		layer["resolved_anchor"] = String(layer.get("anchor", "contact"))
		layer["resolved_placement"] = String(layer.get("placement", "contact_fan"))
	var spec := {
		"mapped": true,
		"phase": phase,
		"layer": layer.duplicate(true),
		"stack_index": stack_index,
		"stack_count": int(request.get("count", 1)),
		"source_kind": source_kind,
		"source_path": component_path if source_kind == "isolated_component" else component_texture.resource_path,
	}
	return _attach_sprite(component_texture, atlas, phase, source_id, String(layer.get("blend", "mix")), spec)


func _build_fallback_base_components(texture: Texture2D) -> bool:
	var tier_counts := _fallback_tier_counts()
	if tier_counts.is_empty():
		return false
	for role in FALLBACK_ROLES:
		for instance_index in int(tier_counts.get(role, 0)):
			if not _add_fallback_sprite(role, texture, "base"):
				return false
	return true


func _resolve_overlays(blessing_overlays: Array) -> bool:
	var mapped_overlays := _recipe.get("blessing_material_compositions", {}) as Dictionary
	var ordered_elements := _candidate_elements(blessing_overlays)
	for overlay_variant in blessing_overlays:
		if not overlay_variant is Dictionary:
			continue
		var gift := overlay_variant as Dictionary
		var candidates: Array = []
		var elements_value: Variant = gift.get("elements", null)
		if elements_value is Array:
			candidates = elements_value as Array
		else:
			candidates = [gift.get("element", "")]
		var gift_resolved := false
		for candidate_index in candidates.size():
			var candidate_variant: Variant = candidates[candidate_index]
			var element := String(candidate_variant).to_lower().strip_edges()
			if element.is_empty() or _resolved_elements.has(element):
				continue
			var mutation := MUTATION_CATALOG.get_mutation(element)
			var overlay_path := String(mutation.get("overlay_asset_path", ""))
			if overlay_path.is_empty() or not ResourceLoader.exists(overlay_path, "Texture2D"):
				continue
			var texture := load(overlay_path) as Texture2D
			if texture == null:
				continue
			var added := 0
			var ordered_index := ordered_elements.find(element)
			var future_element_reserve := maxi(0, ordered_elements.size() - ordered_index - 1) * 5
			var element_limit := maxi(_component_sprites.size(), _maximum_instances - future_element_reserve)
			var mapped_value: Variant = mapped_overlays.get(element, null)
			if mapped_value is Dictionary:
				var mapped := mapped_value as Dictionary
				var minimum_layers := _mapped_requests(mapped).size()
				if _maximum_instances - _component_sprites.size() < minimum_layers:
					break
				added = _build_mapped_components(texture, mapped, element, element_limit)
				if added < 0:
					return false
			elif _maximum_instances - _component_sprites.size() >= FALLBACK_ROLES.size():
				for role in FALLBACK_ROLES:
					if _add_fallback_sprite(role, texture, element):
						added += 1
			if added <= 0:
				continue
			_resolved_elements.append(element)
			_overlay_asset_paths.append(overlay_path)
			gift_resolved = true
		if gift_resolved:
			_blessing_overlay_count += 1
	return true


func _add_fallback_sprite(role: String, texture: Texture2D, source_id: String) -> bool:
	var atlas := _normalized_atlas_texture(texture, role)
	if atlas == null:
		return false
	return _attach_sprite(texture, atlas, role, source_id, _fallback_blend(role, source_id), {
		"mapped": false,
		"source_kind": "plate_crop",
		"source_path": texture.resource_path,
	})


func _attach_sprite(
	sheet: Texture2D,
	atlas: AtlasTexture,
	role: String,
	source_id: String,
	blend: String,
	spec: Dictionary
) -> bool:
	if _component_sprites.size() >= _maximum_instances:
		return false
	var container := get_node_or_null("%sComponents" % role.capitalize()) as Node2D
	if container == null:
		return false
	var ordinal := int(_role_counts.get(role, 0))
	var sprite := Sprite2D.new()
	sprite.name = "%s%sMaterial%02d" % [source_id.capitalize(), role.capitalize(), ordinal + 1]
	sprite.texture = atlas
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 2 + PHASE_ORDER.find(role) * 5 + ordinal
	sprite.modulate = Color.TRANSPARENT
	sprite.set_meta("material_role", role)
	sprite.set_meta("material_source", source_id)
	sprite.set_meta("material_source_kind", String(spec.get("source_kind", "plate_crop")))
	sprite.set_meta("material_source_path", String(spec.get("source_path", sheet.resource_path)))
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if blend == "add" else CanvasItemMaterial.BLEND_MODE_MIX
	sprite.material = canvas_material
	container.add_child(sprite)
	_component_sprites.append(sprite)
	_component_roles.append(role)
	_component_sources.append(source_id)
	_component_ordinals.append(ordinal)
	_component_specs.append(spec.duplicate(true))
	_role_counts[role] = ordinal + 1
	_atlas_regions.append({
		"role": role,
		"source": source_id,
		"source_kind": String(spec.get("source_kind", "plate_crop")),
		"source_path": String(spec.get("source_path", sheet.resource_path)),
		"region": atlas.region,
		"sheet_size": sheet.get_size(),
	})
	return true


func _update_mapped_component(
	index: int,
	source: Vector2,
	target: Vector2,
	impact_progress: float,
	direction: Vector2,
	normal: Vector2,
	core_positions: Array
) -> void:
	var sprite := _component_sprites[index]
	var spec := _component_specs[index]
	var phase := String(spec.get("phase", ""))
	var layer := spec.get("layer", {}) as Dictionary
	var stack := layer.get("stack", {}) as Dictionary
	var stack_index := int(spec.get("stack_index", 0))
	var stack_count := int(spec.get("stack_count", 1))
	var stagger := float(stack.get("stagger_seconds", 0.0))
	var delay := float(layer.get("delay_seconds", 0.0)) + float(stack_index) * stagger
	var lifetime := float(layer.get("lifetime_seconds", 0.1))
	var phase_window := _mapped_phase_window(phase, impact_progress)
	var horizon := _mapped_phase_horizon(phase, _component_sources[index])
	var start := phase_window.x + delay / horizon * (phase_window.y - phase_window.x)
	var end := phase_window.x + (delay + lifetime) / horizon * (phase_window.y - phase_window.x)
	var local_phase := _phase(_progress, start, minf(end, phase_window.y))
	var alpha := smoothstep(0.0, 0.16, local_phase) * (1.0 - smoothstep(0.72, 1.0, local_phase))
	if phase == "contact":
		alpha = sin(local_phase * PI)
	var is_overlay := _component_sources[index] != "base"
	alpha *= 0.34 if is_overlay else 0.62
	if not is_overlay and not bool(layer.get("render_base", true)):
		alpha = 0.0
	var anchor := String(layer.get("resolved_anchor", layer.get("anchor", "contact")))
	var position := _mapped_anchor_position(anchor, phase, source, target, local_phase, stack_index, stack_count, core_positions)
	var offset_values := layer.get("offset", [0.0, 0.0]) as Array
	var offset := Vector2(float(offset_values[0]), float(offset_values[1]))
	position += direction * offset.x + normal * offset.y
	var rotation := deg_to_rad(float(layer.get("rotation_degrees", 0.0)))
	if phase == "travel" or "path" in anchor:
		rotation += direction.angle()
	var scale_values := layer.get("scale", [1.0, 1.0]) as Array
	var mapped_scale := Vector2(float(scale_values[0]), float(scale_values[1]))
	var stack_mode := String(stack.get("mode", "contact_fan"))
	var overlap := clampf(float(stack.get("overlap_ratio", 0.5)), 0.0, 1.0)
	var spacing := float(stack.get("spacing_pixels", 0.0))
	var rotation_step := deg_to_rad(float(stack.get("rotation_step_degrees", 0.0)))
	var side := float(stack_index) - float(stack_count - 1) * 0.5
	match stack_mode:
		"orbit":
			var radius := spacing if spacing > 0.0 else 24.0
			var angle := rotation_step * float(stack_index) - PI * 0.5
			position += Vector2(cos(angle), sin(angle)) * radius
			rotation += angle + PI * 0.5
		"path_overlap":
			position -= direction * side * spacing * (1.0 - overlap) * 0.18
			rotation += rotation_step * side
		"concentric":
			mapped_scale *= 1.0 + float(stack_index) * (1.0 - overlap) * 0.14
			rotation += rotation_step * float(stack_index)
		"vertical_stagger":
			position.y -= float(stack_index) * spacing * (1.0 - overlap)
			rotation += rotation_step * side
		_:
			position += normal * side * spacing * (1.0 - overlap) * 0.32
			rotation += rotation_step * side
	var tint := Color(String(layer.get("tint", "#FFFFFF")))
	sprite.position = position
	sprite.rotation = rotation
	sprite.scale = mapped_scale * (0.94 + sin(local_phase * PI) * 0.08)
	sprite.modulate = Color(tint.r, tint.g, tint.b, tint.a * alpha)
	if phase == "travel" and alpha > 0.02:
		_visible_travel_positions.append(position)
		if _component_sources[index] == "base":
			_visible_base_travel_positions.append(position)
	elif phase == "contact" and alpha > 0.02:
		_visible_contact_positions.append(position)
	elif phase == "residual" and alpha > 0.02:
		_visible_residual_count += 1


func _update_fallback_component(
	index: int,
	source: Vector2,
	target: Vector2,
	impact_progress: float,
	displacement: Vector2,
	normal: Vector2
) -> void:
	var sprite := _component_sprites[index]
	var role := _component_roles[index]
	var ordinal := _component_ordinals[index]
	var role_total := int(_role_counts.get(role, 1))
	var side := float(ordinal) - float(role_total - 1) * 0.5
	var is_overlay := _component_sources[index] != "base"
	var alpha := 0.0
	var phase_value := 0.0
	match role:
		"contact":
			phase_value = _phase(_progress, 0.38 + minf(float(ordinal), 3.0) * 0.018, 0.78)
			alpha = sin(phase_value * PI) * (0.34 if is_overlay else 0.58)
			sprite.position = target
			sprite.rotation = side * 0.055
		"travel":
			phase_value = _phase(_progress, 0.02 + float(ordinal) * float(_runtime.get("travel_stagger", 0.085)), minf(0.72, impact_progress + 0.10))
			alpha = smoothstep(0.0, 0.16, phase_value) * (1.0 - smoothstep(0.80, 1.0, phase_value)) * (0.30 if is_overlay else 0.50)
			sprite.position = source.lerp(target, phase_value) + normal * side * 4.0
			sprite.rotation = displacement.angle() if not displacement.is_zero_approx() else 0.0
			if alpha > 0.02:
				_visible_travel_positions.append(sprite.position)
		_:
			phase_value = _phase(_progress, maxf(0.58, impact_progress) + float(ordinal) * float(_runtime.get("residual_stagger", 0.07)), 1.0)
			alpha = smoothstep(0.0, 0.16, phase_value) * (1.0 - smoothstep(0.68, 1.0, phase_value)) * (0.32 if is_overlay else 0.50)
			sprite.position = target + normal * side * 5.0
			sprite.rotation = -side * 0.045
			if alpha > 0.02:
				_visible_residual_count += 1
	sprite.scale = _fallback_component_scale(sprite.texture, role) * (0.90 + sin(phase_value * PI) * 0.12)
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)


func _mapped_anchor_position(
	anchor: String,
	phase: String,
	source: Vector2,
	target: Vector2,
	local_phase: float,
	stack_index: int,
	stack_count: int,
	core_positions: Array
) -> Vector2:
	var mapped_target := target
	if not core_positions.is_empty():
		var sample_ratio := float(stack_index) / maxf(1.0, float(stack_count - 1))
		var sample_index := clampi(roundi(sample_ratio * float(core_positions.size() - 1)), 0, core_positions.size() - 1)
		var candidate: Variant = core_positions[sample_index]
		if candidate is Vector2:
			mapped_target = candidate as Vector2
	if anchor in ["source", "inherit_base_source"]:
		return source
	if anchor == "target":
		return target
	if anchor in ["path", "inherit_base_path", "ground_path"] or phase == "travel":
		return source.lerp(mapped_target, local_phase)
	return mapped_target


func _mapped_phase_window(phase: String, impact_progress: float) -> Vector2:
	match phase:
		"anticipation": return Vector2(0.0, impact_progress * 0.52)
		"travel": return Vector2(0.04, minf(0.78, impact_progress + 0.10))
		"contact": return Vector2(maxf(0.0, impact_progress - 0.10), minf(0.92, impact_progress + 0.24))
		_: return Vector2(impact_progress, 1.0)


func _mapped_phase_horizon(phase: String, source_id: String) -> float:
	return maxf(0.1, float(_source_phase_horizons.get("%s:%s" % [source_id, phase], 0.1)))


func _pixel_atlas_texture(texture: Texture2D, values: Array, allow_whole_component: bool = false) -> AtlasTexture:
	if values.size() != 4:
		return null
	var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	var size := texture.get_size()
	if region.position.x < 0.0 or region.position.y < 0.0 or region.size.x <= 0.0 or region.size.y <= 0.0 or region.end.x > size.x or region.end.y > size.y:
		return null
	if not allow_whole_component and (region.size.x >= size.x or region.size.y >= size.y):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas


func _normalized_atlas_texture(texture: Texture2D, role: String) -> AtlasTexture:
	var regions := _runtime.get("regions", {}) as Dictionary
	var normalized_value: Variant = regions.get(role, null)
	if not normalized_value is Array or (normalized_value as Array).size() != 4:
		return null
	var normalized := normalized_value as Array
	var size := texture.get_size()
	return _pixel_atlas_texture(texture, [
		float(normalized[0]) * size.x,
		float(normalized[1]) * size.y,
		float(normalized[2]) * size.x,
		float(normalized[3]) * size.y,
	])


func _fallback_tier_counts() -> Dictionary:
	var all_counts := _runtime.get("tier_instance_counts", {}) as Dictionary
	return (all_counts.get(TIER_IDS[_tier - 1], {}) as Dictionary).duplicate(true)


func _fallback_blend(role: String, source_id: String) -> String:
	var blends := _runtime.get("blend_modes", {}) as Dictionary
	return "add" if source_id != "base" else String(blends.get(role, "mix"))


func _fallback_component_scale(texture: Texture2D, role: String) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var extents := _runtime.get("target_extents", {}) as Dictionary
	var target_extent := float(extents.get(role, 112.0)) * (0.90 + float(_tier) * 0.08)
	var size := texture.get_size()
	var longest := maxf(size.x, size.y)
	return Vector2.ONE * (target_extent / longest if longest > 0.0 else 1.0)


func _candidate_elements(blessing_overlays: Array) -> Array[String]:
	var result: Array[String] = []
	for overlay_variant in blessing_overlays:
		if not overlay_variant is Dictionary:
			continue
		var overlay := overlay_variant as Dictionary
		var values: Array = overlay.get("elements", [overlay.get("element", "")]) as Array
		for value in values:
			var element := String(value).to_lower().strip_edges()
			if not element.is_empty() and not result.has(element):
				result.append(element)
	return result


func _phase(value: float, start: float, end: float) -> float:
	if end <= start:
		return 1.0 if value >= end else 0.0
	return clampf(inverse_lerp(start, end, value), 0.0, 1.0)


func _uses_full_sheet() -> bool:
	for index in _component_sprites.size():
		var sprite := _component_sprites[index]
		if sprite.texture == null or not sprite.texture is AtlasTexture:
			return true
		var atlas := sprite.texture as AtlasTexture
		if atlas.atlas == null:
			return true
		var source_kind := String(_component_specs[index].get("source_kind", "plate_crop"))
		var sheet_size := atlas.atlas.get_size()
		if source_kind != "isolated_component" and (atlas.region.size.x >= sheet_size.x or atlas.region.size.y >= sheet_size.y):
			return true
	return false


func _build_variant_signature(material_path: String) -> String:
	var elements := ",".join(PackedStringArray(_resolved_elements))
	var overlays := ",".join(PackedStringArray(_overlay_asset_paths))
	return "%s|tier=%d|elements=%s|base=%s|overlays=%s|composition=%s|instances=%d" % [
		String(_recipe.get("id", "")),
		_tier,
		elements,
		material_path,
		overlays,
		String(_composition.get("id", "fallback")),
		_component_sprites.size(),
	]
