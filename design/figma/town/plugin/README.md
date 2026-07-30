# Town Eternal Forge Builder

本機 Figma 插件會在目前開啟的頁面新增六個獨立區域：

- Cover
- Town map
- Building components
- UI components
- Icons／tokens
- Locked raster references
- B2 building／landmark review

建築、招牌、火炬、劍魂、卡槽和互動區以 Figma 原生節點或 SVG
向量建立。World map 的建築和地點標記使用元件實例，建築招牌底圖保持空白；
中文地點名稱是可編輯文字。PNG 只放在鎖定的參考頁。

插件不會建立或移除 Page，因此可用於免費版的三頁限制。所有新區域會排列在
目前頁面的既有內容右側，不覆蓋既有節點。

若頁面已經有 `Town / Eternal Forge / Editable v2 / World / 5200x720`，
再次執行插件時會進入 fast import：只替換
`Town / B2 Hand-Painted Front Style Review / FAST IMPORT`，不重新建立舊 Town
frames。八個候選保持為八張獨立 Figma image layers。
Python builder 只把降尺寸的審稿副本嵌入插件，正式透明 PNG 不降質；目前
`code.js` 約 6.4 MB，不需經過瀏覽器上傳。

```bash
python build_figma_plugin.py
```

在 Figma Desktop 選擇
`Plugins > Development > Import plugin from manifest...`，匯入本資料夾的
`manifest.json`。若以前匯入過同一路徑，不需再次匯入；直接執行
`Town Eternal Forge Builder` 即可快速更新審稿區。最後用
`File > Save local copy...` 輸出 `town_eternal_forge.fig`。
