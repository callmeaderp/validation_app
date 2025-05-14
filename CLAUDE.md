# CLAUDE.md

This file provides guidance to Claude Code when working on the Validation App project. It captures project context, preferences, and key notes to ensure effective contributions.

## Project Overview

* **Name:** Weight Tracker Validation App
* **Purpose:** A personal tool to test and refine the EMA-based algorithm for weight and calorie tracking. Not intended for public release; used solely for private experimentation and validation.
* **Stack:** Flutter (Dart), Provider for state management, SQLite via `sqflite`, Shared Preferences, `fl_chart` for graphs.
* **Pattern:** MVVM—Models, Data (Repository/Database), Calculation Engine, ViewModels, UI Screens.

## Testing

* **Approach:** Build and run the app locally on a device or emulator, interact with the UI, and manually note any issues or bugs. No formal unit or widget tests are required; iterative feedback based on personal usage is sufficient.

## Repository Etiquette

* **Branches:** `feature/<name>`, `bugfix/<ticket>`, `hotfix/<issue>`
* **Commits:** Use imperative, present tense (e.g., "Add weight EMA logic").
* **Pull Requests:** Rebase to maintain a linear history; squash minor fix commits.
* **Self-Review:** Focus on clarity, correctness, and minimal personal style consistency.

## Known Limitations & Warnings

* **Personal Use Only:** This validation app is for private algorithm refinement. It does not need to meet production or public-ready standards.
* **No Cloud Sync:** Data remains local; use manual import/export as needed.
* **Orientation Locked:** Portrait mode only.
* **Dynamic Alpha Ranges:** Defined in `UserSettings`; adjust via the Settings screen as needed.