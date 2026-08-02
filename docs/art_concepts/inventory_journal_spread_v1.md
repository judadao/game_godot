# Inventory Journal Spread v1

## Runtime asset

- Path: `res://assets/ui/inventory/generated/inventory_journal_spread_v1.png`
- Source size: 1536×1024 RGBA
- Generator: OpenAI built-in image generation
- Use: text-free background for the single authoritative `InventoryUI.tscn`

## Generation prompt

Use case: stylized concept and runtime UI background. Create a straight-on, open ancient
adventurer's journal as a blank double-page game UI frame: navy leather cover, warm parchment,
brass corners and spine hardware, four colored bookmark tabs. Match hand-painted pixel-art with
large color clusters, broken coarse linework, limited value steps, restrained stone/wood-like
mark-making and low detail density. Keep both pages clear for Godot-authored controls. No text,
letters, numbers, icons, symbols, watermark or signature. Avoid photorealism, smooth gradients,
noisy microtexture, meaningless repetition, false seams, fragmented brushwork and broken geometry.

## Integration contract

- The PNG never owns labels, buttons, icons or gameplay state.
- `BookBackground` keeps aspect and shares the exact transformed rect of the 1020×680 native
  journal panel.
- Curated pixel icons remain separate and retain their own filtering policy.
- Any change to the image, scale, position, z-order or integrated composition invalidates prior
  visual approval and requires native-detail, full-frame and fixed 3×2 slice review again.
