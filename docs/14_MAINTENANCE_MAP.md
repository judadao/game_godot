# Maintenance Scope Map

這份文件讓 Codex 或維護者先定位最小修改區域，再開始讀 code。機器可讀的權威
索引是 `res://data/maintenance_scope_map.json`；本頁補充操作規則。

## 快速定位流程

1. 以需求關鍵字在 `maintenance_scope_map.json` 找到 domain。
2. 只先讀該 domain 的 `authority_paths`、直接 caller、scene signal 與 focused tests。
3. 修改資料規則時不順手改 UI；修改 presentation 時不改傷害、存檔或 progression。
4. 先跑 domain 的 `test_suite`，完成提交前才跑全回歸與 headless smoke。

`python3 tools/audit_code_structure.py --limit 20` 可快速列出目前最大 script 與 function；
輸出只是拆分候選清單，不是用行數直接判定刪除或切檔。

```bash
tools/run_godot_tests.sh --suite vfx --strict-warnings
tools/run_godot_tests.sh --suite forge --strict-warnings
tools/run_godot_tests.sh --suite all --smoke --strict-warnings
```

## 變更隔離原則

- `Game` 是 composition root，只負責生命週期與跨域 wiring；新規則不得繼續堆入
  `scripts/managers/game.gd`。
- 可獨立驗證的檔案 I/O、格式化、target contract 或 catalog 規則放入小型
  `RefCounted` service/helper。
- UI 只接收 projection、顯示狀態與發出 intent；不得直接修改 forge、inventory、
  combat 或 story model。
- VFX 消費戰鬥事件，但不決定傷害；地圖 Scene 擁有碰撞與 placement，素材檔不擁有
  gameplay truth。
- public canonical scene path 與 save identity 不因整理目錄而改變。

## 大型檔案拆分規則

大型檔案不按固定行數硬切。當一個檔案同時擁有兩個以上可獨立測試的責任時：

1. 先為待抽責任補 characterization/regression test。
2. 抽出完整責任與其 private helper，不建立 `part_1.gd` 之類無語意切片。
3. 原 owner 只保留組裝、資料轉換或相容 wrapper。
4. focused suite 通過後，再處理下一個責任，避免一次改動多個不相干功能。

本輪已先將 quick-save 檔案 I/O 從 `game.gd` 抽到
`scripts/systems/quick_save_service.gd`，並將圖鑑的純文字投影抽到
`scripts/ui/inventory/codex_text_formatter.gd`。其餘大型檔案仍應依相同方式逐責任拆分，不能
為追求行數一次重寫整個 coordinator。

## 素材保存

`assets/asset_classification.json` 使用 longest-prefix 分類 active、candidate、legacy 與
license 素材。`python3 tools/audit_assets.py` 只產生盤點，不移動或刪除任何素材；零直接
reference 也不等於可刪除。

## Review Checklist

- [ ] 修改落在單一 domain，或已明確列出必要的跨域 contract。
- [ ] 沒有改動不相關 scene、data、save schema 或 UI layout。
- [ ] 新 helper/service 有 focused test。
- [ ] 大檔案按責任拆分，名稱可直接說明 owner。
- [ ] 先跑 focused suite，提交前跑全回歸與 headless smoke。
- [ ] 未使用素材仍被保留並可由分類表找到。

## Related Documents

- `docs/02_PROJECT_ARCHITECTURE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/11_GIT_WORKFLOW.md`
- `assets/README.md`
