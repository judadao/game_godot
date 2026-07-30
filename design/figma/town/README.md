# Town Figma

可編輯 Town Figma 的來源與交付集中在此資料夾。

- `town_style_discussion_board.svg`：保留的一頁式歷史討論板。
- Figma 的 `Town / Base Modular Buildings + Town Map / FAST IMPORT`：
  目前正式的一頁式 Base 物件與完整地圖檢查頁；以精簡 SVG 匯入即可更新。
- `town_base_building_landmark_map_review.svg`：網頁版 Figma 的精簡快速匯入檔；
  完整地圖中的背景／地面與前景街具各自成組，八個主建築／地標皆為可獨立
  選取、移動或隱藏的 map layer；下方另附八張 isolated Base 物件卡。
- `town_b2_building_landmark_review.svg`：六棟 B2 建築、不滅火炬與戰鬥傳送門
  的歷史審稿板。
- `b2_front_style_candidates/`：目前八個嚴格正面朝向、低 AI 痕跡的透明
  PNG；八個物件皆為可供 Godot 疊加手繪光罩的中性 Base，沿用材料行的像素
  群塊、斷裂線稿、固有色與結構 AO 規則。
- `b2_front_candidates/`：保留的正面透視基礎版，用於比對風格轉換是否改壞造型。
- `b2_candidates/`：保留的舊 3/4 視角候選，不再作為目前審稿來源。
- `CODEX_RESTART_HANDOFF.md`：重開 Codex 後的完整續作紀錄。
- `plugin/`：在 Figma 中產生原生節點、元件和頁面的本機插件。
  已匯入過插件時，直接重跑 `Town Eternal Forge Builder` 即可快速更新 B2
  審稿區，不需重新上傳 SVG 或重新登入。
- `vector_sources/`：可直接匯入和修改的 SVG 素材。
- `*.png`：鎖定的概念參考圖，不視為可編輯交付。
- `town_eternal_forge.fig`：由 Figma Desktop 的 Save local copy 產生。

主要尺寸：

- Town map：`5200 × 720`
- Presentation：`2560 × 1080`

所有中文標籤保持為可編輯文字，建築上的圖像招牌保持空白。

目前 review 規則：

1. 先以完整 1942 × 809 map 區確認背景、建築、火炬、傳送門、古樹與留白。
2. 八張物件卡用來單獨討論或替換，位置仍以 JSON layout 為唯一權威。
3. Base 不烘焙大面方向光；後續日照、色調與氛圍由 Godot 疊加層處理。
