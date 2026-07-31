# Town Figma

可編輯 Town Figma 的來源與交付集中在此資料夾。

- `town_style_discussion_board.svg`：保留的一頁式歷史討論板。
- Figma 的 `Town / Base Modular Buildings + Town Map / FAST IMPORT`：
  目前正式的一頁式 Base 物件與完整地圖檢查頁；以精簡 SVG 匯入即可更新。
- `town_base_building_landmark_map_review.svg`：網頁版 Figma 的精簡快速匯入檔；
  完整地圖依 locked A 拆成藍天山景 plate、生成的繁盛橘黃／赭紅中景秋林、
  中央大秋樹、MaterialYard-style Base v5 不滅熔爐、Base v4 旋渦門、Base 建築與
  石橋 layer；八個主建築／地標保留可獨立選取、移動或隱藏的 map layer，
  下方另附八張 isolated Base 物件卡。
- `town_b2_building_landmark_review.svg`：六棟 B2 建築、不滅火炬與戰鬥傳送門
  的歷史審稿板。
- `b2_front_style_candidates/`：目前八個嚴格正面朝向、低 AI 痕跡的透明
  PNG；八個物件皆為可供 Godot 疊加手繪光罩的中性 Base，沿用材料行的像素
  群塊、斷裂線稿、固有色與結構 AO 規則。
  村長家、劍魂商、裝備圖紙商與東郊民宅的 `*_base_v3.png`，以及
  不滅熔爐的 `*_base_v5.png` 與戰鬥傳送門的 `*_base_v4.png` 是目前核准來源，
  由 `prepare_town_base_assets.py` 以共同 4× pixel-density canvas 產生 runtime
  版本；舊 `*_b2.png` 只保留作歷史比較。
- `b2_front_candidates/`：保留的正面透視基礎版，用於比對風格轉換是否改壞造型。
- `b2_front_style_candidates/eternal_flame_animation/`：核准的 4×2 火焰與符文
  透明動畫表；`tools/prepare_town_eternal_flame_animation.py` 會可重現地切成
  runtime 8 幀素材。火焰與符文不可重新烘焙進 Base v5。
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

## Town 美術審查原則

通用權威是 [`docs/09_TESTING_GUIDE.md` 的「生成圖片與整體構圖 Review」][art-review]。
本節記錄 Town 的實際執行方式；若兩者衝突，以通用權威為準。

1. 先以完整 1942 × 809 map 區比對 locked A 背景／地板排版與 Base 前景建築。
2. 八張物件卡用來單獨討論或替換，位置仍以 JSON layout 為唯一權威。
3. Base 不烘焙大面方向光；後續日照、色調與氛圍由 Godot 疊加層處理。
4. 每個生成物件都要以原始尺寸檢查透明／色邊、像素密度、輪廓、比例、材質、
   光向與不該出現的局部，不得只看縮小後的 Figma 卡片。
5. Base 材料行是 Town 唯一筆觸基準：大型色塊、粗而斷裂的線稿、有限色階、
   石木材質筆觸與細節密度必須一致。過度平滑、碎裂、寫實或高噪點，即使幾何
   正確也不通過。
6. 必須排除可辨識的 AI 生成痕跡：糊爛或過度細碎的紋理、無意義重複、
   材質頻率不一致、錯誤幾何、假接縫，以及與既有 Town 畫風無關的裝飾。
7. 完整整合圖必查焦點、色彩層級、前中後景、遮擋、重複、左右邊界、建築後方、
   貼地空隙、比例、位置與 z-order。
8. 完整圖固定切成 3 欄 × 2 列共 6 個等分區域；獨立 reviewer 必須逐一回報
   `R1C1` 到 `R2C3` 的 PASS 或 finding，不得只看整張縮圖或問題 crop。
9. finding 使用 `Critical`、`Important`、`Minor`。`Critical`／`Important`
   未修正並重新審查前不得交付。
10. 審查後只要修改 asset、scale、position、z-index 或排版，舊審查立即失效；
    最終版必須重新完成原尺寸物件、full-frame 與全部 6 區審查。
11. `.gd` 測試只保護載入、alpha、source path、aspect ratio、z-order 與
    Scene／layout parity，不能代替畫風與構圖判斷。

### 審查紀錄格式

每次最終候選的 reviewer 紀錄至少包含：

- revision／commit、審查者與整合圖路徑；
- 原尺寸物件逐件結論；
- full-frame 結論；
- `R1C1` 至 `R2C3` 的 6 區結論；
- finding 的 severity、位置、證據、處理結果；
- 最後一次視覺修改後的重新審查結果；
- 尚未驗證項目，不得以自動測試 PASS 代替。

建議本機證據放在忽略提交的
`output/playwright/town_reviews/<revision>/`，並使用
`full_frame.png`、`object_<id>.png` 與 `slice_R<row>C<column>.png` 命名。
正式提交只保留規則、來源素材與可重建工具，不提交本機 review cache。

[art-review]: ../../../docs/09_TESTING_GUIDE.md#31-生成圖片與整體構圖-review
