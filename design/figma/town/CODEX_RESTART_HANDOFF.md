# Town Figma — Codex Restart Handoff

更新時間：2026-07-27

## 目標

在以下 Figma Design 檔案建立真正可編輯的 Town：

https://www.figma.com/design/EKb2iRdSIJJE3LcNUarw5D/game?node-id=4-2&m=dev&t=anfexHWa6MvUCpWG-1

新增內容命名為：

`Town / Eternal Forge / Editable v2`

不得刪除或覆蓋既有 Figma 內容。

## 重開 Codex 後第一步

1. 確認本回合的 Skills 中有 Figma skills，尤其：
   - `figma:figma-use`
   - `figma:figma-generate-design`
   - 建立元件時使用 `figma:figma-generate-library`
2. 用 Tool Search 一次載入：
   - `use_figma`
   - `get_metadata`
   - `get_screenshot`
3. 使用 `get_metadata` 讀取上方網址的 `4:2`，確認連線與檔案權限。
4. 讀取 Figma skills 後，使用 `use_figma` 分段建立內容。
5. 每個 major section 使用獨立 `use_figma` call，回傳所有建立／修改的 node IDs。
6. 每段完成後用 `get_screenshot` 視覺驗證。

## Figma MCP／Plugin 狀態

- 官方 Codex plugin 已安裝：
  - `figma@openai-curated`
  - version：`11c74d6b`
  - auth policy：`ON_INSTALL`
- 官方遠端 MCP 已設定：
  - `https://mcp.figma.com/mcp`
- 已執行 `codex mcp login figma`
- OAuth 結果：`Successfully logged in to MCP server 'figma'`
- `codex mcp list` 顯示：
  - status：`enabled`
  - auth：`OAuth`

舊 Codex thread 無法熱載入剛安裝／登入的 Figma tool schemas，所以必須重開
Codex。不要重新產生 PNG，也不要把 PNG 當成可編輯 Figma 交付。

## 已完成的可編輯素材

- `vector_sources/eternal_flame.svg`
  - 640 × 720
  - 純向量
  - foundation、stairs、pillar、brazier、flame、runes、banners、glow、
    particles 分層
- `vector_sources/town_buildings.svg`
  - 2400 × 720
  - 六棟純向量建築
  - 材料行、鐵匠鋪、村長家、劍魂商、圖紙研究室、劍魂精煉所
- `vector_sources/town_ui_icons.svg`
  - 純向量
  - 城徽、地點牌、地點 icon、五種劍魂球、旗幟、四格出征配置 UI

SVG XML 驗證必須使用 UTF-8：

```powershell
[xml](Get-Content -LiteralPath '<path>' -Raw -Encoding UTF8)
```

## 本機 Figma Plugin 備援

位置：

`design/figma/town/plugin/`

內容：

- `manifest.json`
- `code.template.js`
- `build_figma_plugin.ps1`
- `code.js`

已執行 build：

- Vector sources：3
- Raster references：4
- `node --check code.js` 通過

`code.js` 會把 SVG 與四張概念 PNG 內嵌。PNG 只應放在鎖定的
`99_Raster_References`。

注意：本機 plugin template 目前仍有一個待修項目：

- `figma.currentPage = world` 要改成
  `await figma.setCurrentPageAsync(world)`

若 MCP 寫入可用，優先使用 MCP，不必執行本機 plugin。

## 必須建立的 Figma 結構

### Frames／Areas

- Cover：2560 × 1080
- World map：5200 × 720
- Building components
- UI components
- Icons／tokens
- Locked raster references

### World map 順序

由左至右：

1. 材料行
2. 主角家／鐵匠鋪
3. 不滅火炬
4. 戰鬥傳送門
5. 村長家
6. 劍魂商
7. 圖紙研究室
8. 劍魂精煉所

### UI／系統

- 中文地點名稱必須是可編輯文字
- 建築招牌底圖保持空白
- 不滅火炬升級進度
- 鐵匠技術升級進度
- 武器欄
- 三格 Combo 劍魂
- 一格專用治療劍魂
- 終結技預覽
- 火、冰、雷、毒、治療劍魂

### 顏色

- Ink：`#10151D`
- Stone：`#3B4148`
- Gold：`#D99A2B`
- Fire：`#FF8A18`
- Portal：`#28A9FF`
- Soul：`#A743FF`
- Roof Blue：`#244C70`
- Roof Red：`#793A32`

## 驗收

- 不是單張 PNG。
- 建築、招牌、UI、文字、劍魂與互動區皆可分別選取和修改。
- 重複元素使用 Component／Instance。
- 圖層有語意化命名。
- World map 是 5200 × 720 的橫向場景。
- 完成後回報建立的 node IDs 與可直接開啟的 Figma node link。
