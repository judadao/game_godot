# Git Workflow

## 目錄

1. [Repository 現況](#1-repository-現況)
2. [分支與工作區](#2-分支與工作區)
3. [Dirty Worktree 規則](#3-dirty-worktree-規則)
4. [Commit Workflow](#4-commit-workflow)
5. [Review 與 Push](#5-review-與-push)
6. [文件同步](#6-文件同步)
7. [復原與破壞性操作](#7-復原與破壞性操作)
8. [Code Example 與 Godot Example](#8-code-example-與-godot-example)
9. [Best Practice](#9-best-practice)
10. [Anti Pattern](#10-anti-pattern)
11. [Review Checklist](#11-review-checklist)
12. [Future Extension](#12-future-extension)
13. [Related Documents](#13-related-documents)

## 1. Repository 現況

Repository 使用 Git，已有長期提交歷史、`main` 分支、遠端 `origin` 與
`v0.1.0` tag。現階段沒有 repository 內 CI workflow，也沒有單一測試 runner。
因此本機／代理在 push 前負責完整驗證。

## 2. 分支與工作區

- 使用者明確要求直接 commit/push 時，可在目前分支小步提交。
- 大型或實驗性重整優先使用獨立 branch/worktree。
- 不在 detached HEAD 假裝已 push。
- 開始前記錄：

```powershell
git branch --show-current
git rev-parse --show-toplevel
git status --short
git remote -v
```

### Scene Tree Example

Git 不管理 runtime Scene Tree，但 commit 應以可獨立驗證的 Scene 邊界切分：

```text
Commit: Refactor card layout
├── CardHandUI.tscn
├── card_hand_ui.gd
├── layout tests
└── matching docs
```

不要把不相關地圖世界座標混入同一 commit。

## 3. Dirty Worktree 規則

working tree 中的既有修改預設屬於使用者。

1. 用 `git status --short` 列出。
2. 用 `git diff -- <path>` 了解是否與任務重疊。
3. 不使用 `git reset --hard`、`git checkout --` 或 broad clean。
4. stage 使用明確 path list。
5. dirty file 必須部分提交時，以可驗證 hunk staging，不能整檔混入。

本專案的 `.godot/`、`.test_userdata/` 與 `.superpowers/` 是本機／暫存內容，
不得因測試產生而加入正式 commit。

## 4. Commit Workflow

### 4.1 Commit boundary

一個 commit 表達一個可回歸成果，例如：

- `Refactor combat UI layout guardrails`
- `Add project governance documentation`
- `Extract map scene registry`

使用 imperative、簡潔且能說明 outcome 的 message。

### 4.2 Pre-commit

```powershell
git diff --check
git diff --cached --name-only
git diff --cached --check
git diff --cached --stat
```

逐一核對 staged files 等於預期清單。測試通過但 staging 錯誤仍不可 commit。

### 4.3 Generated UID

新增 GDScript 經 Godot 載入後通常產生 `.gd.uid`。若相同類型既有檔案均追蹤
UID，新 script/test 的 UID 應一起提交；不提交 `.godot` import cache。

## 5. Review 與 Push

重大功能／refactor 在 commit 前做獨立 review。Critical／Important finding
需修正與 scoped re-review。

Push 後核對：

```powershell
$branch = git branch --show-current
$local = git rev-parse HEAD
$remote = (git ls-remote origin "refs/heads/$branch") -split '\s+'
if ($local -ne $remote[0]) { throw "Remote branch mismatch: $branch" }
```

若目前 branch 尚未有 upstream，先以 `git push -u origin $branch` 建立；
不得只根據 `git push` 沒報錯就忽略實際推送的遠端 branch。

## 6. 文件同步

以下變更與 code 同 commit 更新 docs：

- Scene／path／ownership → 02、03。
- UI contract／component／theme → 04、07、08。
- data／save schema → 06。
- test command／coverage → 09。
- gameplay rule → 12。
- technical debt／milestone → 13。

## 7. 復原與破壞性操作

- 先用 read-only Git 確認精確 target。
- 優先新增修復 commit 或 `git revert <commit>`。
- 未經使用者明確要求，不 rewrite shared history 或 force push。
- 不刪除無法確認歸屬的 untracked file。
- material deletion 必須回報範圍與可恢復性。

## 8. Code Example 與 Godot Example

### 8.1 Scoped stage

```powershell
$files = @(
  'scripts/systems/map_registry.gd',
  'tests/map_registry_test.gd',
  'docs/02_PROJECT_ARCHITECTURE.md'
)
git add -- $files
git diff --cached --name-only
```

### 8.2 Godot change verification

```powershell
& $godot --headless --path . --script res://tests/map_registry_test.gd
if ($LASTEXITCODE -ne 0) { throw "Regression failed" }
git commit -m "Extract map scene registry"
```

## 9. Best Practice

- 小 commit、清楚 scope、完整測試證據。
- reviewer 讀 staged diff，不依賴作者記憶。
- code、test、docs 一起演進。
- push 後核對 remote SHA。

## 10. Anti Pattern

- `git add .` 混入地圖、cache、截圖與使用者檔。
- 為了乾淨狀態 reset 使用者工作。
- 一個 commit 同時重寫 Scene、玩法、資產與 docs。
- 測試失敗仍以「不是我的問題」推送，卻沒有證據與隔離。
- force push `main`。

## 11. Review Checklist

- [ ] branch、remote、base SHA 已確認。
- [ ] 未追蹤／dirty 使用者檔已保留。
- [ ] staged files 只含任務 scope。
- [ ] `git diff --cached --check` clean。
- [ ] focused/full tests 有 fresh evidence。
- [ ] docs 已同步。
- [ ] independent review 已完成。
- [ ] commit message 描述 outcome。
- [ ] push 後 local/remote SHA 一致。

## 12. Future Extension

- 建立 CI 執行 46+ headless tests、editor smoke、Markdown/path check。
- 增加 PR template 與 required checks。
- 定義 release branch、semantic version 與 changelog 流程。
- 以 script 提供跨平台一致的 test runner。

## 13. Related Documents

- `docs/01_AI_GUIDE.md`
- `docs/05_CODING_STANDARD.md`
- `docs/09_TESTING_GUIDE.md`
- `docs/10_DEBUG_GUIDE.md`
- `docs/13_ROADMAP.md`
