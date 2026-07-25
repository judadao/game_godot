# Codex Project Governance Initialization

你現在不是要實作功能，而是要建立這個 Godot 專案的完整工程文件（Project Governance）。

這些文件將成為此專案唯一可信的開發規範。

從這一刻開始，所有未來修改都必須先閱讀並遵守這些文件。

---

# 專案背景

Engine:
Godot 4.x

Language:
GDScript

Project:
2D Pixel Game

本專案會長期維護。

未來所有 AI（Codex、Claude Code、Copilot、Gemini 等）都會依照這些文件開發。

因此文件品質比功能更重要。

請將文件寫成中大型遊戲工作室等級，而不是 README 或簡單筆記。

---

# 任務

建立完整 docs 文件系統。

如果 docs 不存在，請建立。

建立以下文件：

docs/
README.md

01_AI_GUIDE.md

02_PROJECT_ARCHITECTURE.md

03_SCENE_STRUCTURE.md

04_UI_GUIDE.md

05_CODING_STANDARD.md

06_RESOURCE_GUIDE.md

07_THEME_GUIDE.md

08_COMPONENT_LIBRARY.md

09_TESTING_GUIDE.md

10_DEBUG_GUIDE.md

11_GIT_WORKFLOW.md

12_GAME_DESIGN.md

13_ROADMAP.md

CLAUDE.md

AGENTS.md

---

# 每份文件要求

每份文件都必須：

使用 Markdown

具有完整目錄

具有章節編號

具有 Checklist

具有 Best Practice

具有 Anti Pattern

具有 Code Example

具有 Scene Tree Example

具有 Godot Example

具有 Review Checklist

具有 Future Extension

具有 Related Documents

禁止只寫幾頁。

每份至少應具有可長期維護的內容。

---

# AI Guide

AI Guide 必須包含：

AI Workflow

Task Analysis

Reading Order

Modification Rules

Review Process

Testing SOP

Reporting Format

Forbidden Actions

Risk Analysis

Regression Rules

Completion Checklist

---

# UI Guide

UI Guide 必須完整說明：

CanvasLayer

Control

Container

MarginContainer

VBoxContainer

HBoxContainer

GridContainer

ScrollContainer

PanelContainer

CenterContainer

AspectRatioContainer

Anchor

Offsets

Size Flags

Minimum Size

Theme

Popup

Dialog

Inventory

Shop

HUD

Quest UI

Battle UI

Responsive Design

Pixel Perfect

Animation Rules

Dynamic UI

Long Text

Localization

Accessibility

UI Review Checklist

Common Mistakes

Forbidden Practices

---

# Scene Structure

定義：

每一種 Scene

應該有哪些 Node

命名規範

Node Tree

父子關係

Signal

Script

Resource

Component

禁止事項

---

# Coding Standard

Early Return

Signal First

Single Responsibility

Naming

Folder Rules

File Rules

Comment Rules

Performance

Memory

Thread Safety

Async

Autoload

Resource

Dependency

Error Handling

Logging

Review Checklist

---

# Theme Guide

Theme Layer

Theme Variation

Color System

Typography

Icons

Button Style

Panel Style

StyleBox

Spacing

Padding

Margin

Dark Theme

Light Theme

---

# Component Library

建立建議元件：

PrimaryButton

SecondaryButton

DangerButton

Dialog

ItemCard

SkillCard

QuestRow

Tooltip

InventorySlot

HealthBar

ManaBar

StatusRow

PanelHeader

ListRow

LoadingView

EmptyView

ErrorView

每個元件說明：

用途

Scene Tree

Script

Signals

Theme

使用時機

禁止事項

---

# Testing Guide

Parser

Signals

Resources

Scene

Theme

Resolution

Animation

Gameplay

Regression

Performance

Memory

UI

Checklist

---

# Game Design

不要猜測玩法。

請先分析目前專案。

依照現有玩法建立 Game Design。

若資訊不足：

使用 TODO 標示。

不要幻想功能。

不要自行設計新玩法。

---

# Architecture

Architecture 必須根據目前專案。

分析：

Scene

Scripts

Resources

Autoload

Data Flow

Signals

UI

Inventory

Save

Combat

NPC

Quest

Dialogue

Animation

Audio

如果不存在：

寫 TODO。

不要幻想架構。

---

# 寫作要求

所有內容必須：

以 Godot 4 為基準

符合 GDScript

符合目前專案

不要引用 Godot 3

不要引用 Unity

不要使用過時 API

所有範例都必須可讀且一致。

---

# AI 必須遵守

建立完成後。

未來所有任務：

開始之前

必須先閱讀：

CLAUDE.md

AGENTS.md

以及 docs 中所有相關文件。

如果文件與使用者要求衝突：

先告知。

不要自行違反規範。

---

# 修改規則

未來若修改架構。

必須同步更新：

相關 docs。

不得讓文件過期。

Documentation 與 Code 必須保持一致。

---

# 文件品質要求

目標不是完成。

而是建立：

可維護

可擴充

可 Review

可交接

可讓其他 AI 持續開發

的工程文件。

所有文件都應具有中大型遊戲工作室的品質。

不要省略內容。

不要只寫概要。

如果內容過長。

請自動分多次 Commit 建立全部文件。

直到完成整個文件系統為止。

在所有文件完成之前，不要開始任何遊戲功能開發。
