# Town Figma

可編輯 Town Figma 的來源與交付集中在此資料夾。

- `town_style_discussion_board.svg`：目前首選的一頁式討論板。直接拖進空白
  Figma page；第一區是不可變動的 Image #2 基準，第二區才是重組候選與可選取
  分件素材庫。
- `town_b2_building_landmark_review.svg`：六棟 B2 建築、不滅火炬與戰鬥傳送門
  的單頁審稿板。此檔只供逐件核准，未接入 runtime。
- `b2_front_candidates/`：目前八個嚴格正面朝向的透明 PNG；可各自拖入
  Figma 並獨立替換。
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

1. 先以第一區確認背景、建築、火炬、傳送門、古樹與整體構圖。
2. 第二區只用來討論單一物件是否可替換，不代表已進 runtime。
3. 未核准的分件不可覆蓋第一區，也不可直接切回遊戲場景。
