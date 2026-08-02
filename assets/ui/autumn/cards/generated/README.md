# Autumn Combo / Healing Card Art

This directory contains the 20 authoritative 256×256 semantic illustrations
used by every Combo or Healing sword soul that participates in a learned
finisher formula. Each filename is the stable card id from `data/cards.json`.

The illustrations were generated with OpenAI's built-in image generation on
2026-08-02 from four user-supplied dark tarot references, then reviewed at
native detail, resized to the runtime format, checked in a 5×4 contact sheet
and at 44 px, and integrated into the six required Autumn HUD resolutions.

The shared art direction is midnight black, aged-gold engraved geometry and
one dominant semantic emblem. Family color is limited to a restrained accent:
rust red for offense, stone/ivory for defense, blue-violet for arcane,
orange/ice/cyan/green for elements, and gold-green or crimson for healing.
Images contain no baked title, shortcut, level, AP cost, frame, letters,
numbers, pseudo-runes, logo, or watermark. `AutumnBattleCard` owns all live UI
text, the scalable ritual frame, input state, and cast feedback.

The complete prompt set and source-art rationale are recorded in
`docs/art_concepts/combo_card_tarot_v1.md`.
