# Town — Eternal Forge Figma V1

## Source

- Concept render: `res://design/figma/town/town_eternal_forge_figma_v1.png`
- Eternal Flame variants: `res://design/figma/town/eternal_flame_upgrades_figma_v1.png`
- Player forge variants: `res://design/figma/town/player_blacksmith_upgrades_figma_v1.png`
- Sword Soul district: `res://design/figma/town/sword_soul_district_figma_v1.png`
- Figma presentation frame: `2560 × 1080`
- Godot gameplay target: `5200 × 720`
- Navigation: one horizontal street; no vertical platform route

## Visual hierarchy

1. Eternal Flame shrine
2. Player blacksmith shop
3. Battle portal
4. Sword Soul district
5. Material and civic services

## Horizontal gameplay layout

| X range | Landmark | Primary interaction |
|---|---|---|
| 0–700 | West gate and material yard | Buy/sell ore, timber, ingots |
| 700–1650 | Player blacksmith shop | Forge gear, orders, shop expansion |
| 1650–2800 | Eternal Flame sanctuary | Upgrade the city guardian flame |
| 2200–2650 | Battle portal | Weapon and four-slot Sword Soul loadout |
| 2800–3650 | Town hall | Quests, commissions, city expansion |
| 3650–4150 | Sword Soul shop | Acquire and equip Sword Souls |
| 4150–4650 | Blueprint research | Unlock equipment designs |
| 4650–5200 | Soul refinery and east gate | Refine/evolve Sword Souls |

## Figma components

- `Town/LocationMarker`
  - icon
  - short Chinese name
  - hover glow
  - locked state
- `Town/EternalFlameProgress`
  - current level
  - offering progress
  - next unlocks
- `Town/BlacksmithProgress`
  - forging level
  - shop level
  - available designs
- `Town/PortalLoadout`
  - weapon
  - healing Sword Soul
  - Combo Sword Soul 1–3
  - available Finisher preview

## Overlay labels

- 材料行
- 我的鐵匠鋪
- 不滅火炬
- 戰鬥傳送門
- 村長家／委託所
- 劍魂商
- 設計稿研究室
- 劍魂精煉工房

Do not bake these labels into raster building art. Keep gold-framed plaques blank
and render text as Figma/Godot UI so localization remains editable.

## Progression ownership

- Eternal Flame level unlocks shop stock, blueprint categories, town districts,
  rare materials, and Sword Soul refinement caps.
- Forging level unlocks equipment quality, affix count, resource efficiency,
  advanced refinement methods, order difficulty, and sale value.
- Weapons define the base attack; Sword Souls modify attacks and form named
  three-Soul Finishers. The healing Sword Soul does not enter Finisher recipes.
