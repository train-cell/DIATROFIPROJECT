# Changelog

All notable changes to **DIATROFIPROJECT** (The DIAτροφή Project / Orchard) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2026-11-22

### Added
- **Modular Menu-Picker Architecture (`PlanOption`)**:
  - Full support for multi-option meals (e.g. sandwiches, oat omelets, recovery tuppers, and garnishes) with categorized selections and individual macronutrient targets.
  - Interactive modal sheets (`MenuOptionPickerSheet`) providing 1-tap logging directly from the daily schedule.
- **5 Dynamic Day Modes (`DayTemplate`)**:
  - Dedicated nutrition templates: **Training** (single session), **Double Training** (multi-session with independent `sessionIndex: 0` and `sessionIndex: 1` anchor rippling), **Pre-Race (48h)** (low-residue pre-competition fueling), **Race Day** (competition fueling packet & immediate recovery), and **Rest** (active recovery).
  - Dynamic day mode switcher with automatic schedule and target recalculation.
- **Timeline Supplements & Weekday Filtering (`activeWeekdays`)**:
  - Fine-grained weekday scheduling: Ferro Sanol Duodenal 100mg + Vitamin C 500 scheduled strictly on Wednesdays and Fridays, automatically excluded on remaining days with cascading child-item filtering.
  - Real-time 6/7 supplement progress tracking alongside meal progress.
- **Athletic Hydration Engine (2.5L – 3.5L)**:
  - Mode-specific fluid targets (e.g. 3,000ml on training, 3,500ml on double-training, 2,500ml on rest days).
  - Quick-add chips (`+250ml`, `+500ml`, `+1.0L`, and `HIGH5+BCAA 💧` electrolyte tracking) with animated fill gauge and bidirectional Apple HealthKit sync.
- **Selective Feature Toggles**:
  - User-configurable toggles in Settings for Intermittent Fasting and Goal Weight / Coaching Projections to adapt the UI to athlete preferences.
- **Live BYOK AI Nutrition Coach (Gemini 12-Model Fallback Chain)**:
  - Bring-Your-Own-Key (BYOK) conversational nutrition coach utilizing user-provided Google AI Studio API keys.
  - 12-tier automated fallback chain spanning Gemini 3.x, 2.5, 2.0, and 1.5 Flash/Lite/Pro families with preferred model pinning and latency diagnostics.
  - `NutritionContextBuilder`: Deterministic dynamic system prompt builder injecting athlete profile, all 5 day modes, modular meal libraries, and current daily progress snapshot.
  - `AICoachResponseValidator`: 50/50 deterministic macro hydration and safety guard, populating exact plan macros, clamping negative/NaN/Infinite numbers, and ensuring valid Greek replies.
  - `AICoachChatView`: Interactive chat sheet with 1-tap Confirm, optional Auto-Log, and full multi-action Undo.
  - Live AI food estimation integrated into `AILogSheet` and `PlanImportSheet`.
- **Comprehensive Verification & Testing**:
  - Expanded unit, integration, and E2E test suites: 174 SwiftPM tests, 189 Xcode iOS Simulator tests, and 7 interactive XCUITest flows (`OrchardUITests`).

### Security & Hardening
- **HTTP Header API Key Transmission**: Gemini API keys are transmitted exclusively via the `x-goog-api-key` HTTP header, eliminating sensitive key exposure in URL query parameters.
- **On-Device Keychain Isolation**: API keys stored in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` to prevent unencrypted iCloud Keychain synchronization.
- **Telemetry Privacy Kill-Switch**: Zero-knowledge local JSONL telemetry strictly honors the Settings toggle and performs automatic log rotation at 1,000 entries with zero network egress.
- **Timezone-Aware Schedule Resolution**: Context builder respects the athlete's local timezone (`Europe/Athens`) ensuring prompt timestamps match local meal times rather than UTC.

### Fixed
- **Attached Item Meal-Gap Conflicts**: Excluded child (`attachedToItemId != nil`) and optional items from minimum meal gap calculations in `ScheduleResolver`, eliminating false 0-minute conflict warnings across all 35 template/weekday combinations.
- **Supplement Water Logging Idempotency**: Guarded against duplicate `waterMl` additions when re-logging supplements or completing multi-action sequences.
- **Supplement Undo Bite Count**: Preserved food meal bite counts when undoing supplement log entries.
- **Option ID Shorthand Normalization**: Implemented flexible ID matching to resolve shorthand identifiers (e.g. `tupper_3` -> `tupper_opt_3`) to the correct plan options.
- **Floating-Point Sanitization**: Added pre- and post-hydration guards in `AICoachResponseValidator` clamping `NaN` and `Infinity` to `0.0`, preventing runtime integer conversion crashes.
- **Manual AI Log Persistence & Undo Tracking**: Added `appliedLogIds` tracking to `AICoachChatMessage` and ensured `addManualLog(source: .ai)` persists entries to `UserDefaults`.

---

## [1.8.0] - 2026-11-20

### Added
- Dynamic font scaling on HRV and resting heart rate status descriptions.
- Smooth spring arc animations and numeric transitions on recovery gauge.
- Polish for TodayView habit rings and spring animations.

---

## [1.7.0] - 2026-11-19

### Added
- 12 premier athletic nutrition & performance features.
- HealthKit sleep architecture (deep, REM, core, awake stages), HRV, and resting heart rate integration.
- Pure Keychain BYOK storage and DIATROFIPROJECT branding.

---

## [1.6.0] - 2026-11-18

### Added
- 4.0L athletic hydration engine.
- Sleep recovery quick card.
- Animated application icon.

---

## [1.5.0] - 2026-11-17

### Added
- Comprehensive portfolio architectural documentation in README.md.

---

## [1.4.2] - 2026-11-16

### Added
- Active day confirmation banner with remaining 14-day quota guidance.

---

## [1.4.1] - 2026-11-15

### Fixed
- Morning schedule calibration: unified Day 7 breakfast test assertion to 10:30.

---

## [1.4.0] - 2026-11-14

### Added
- Expanded Gemini Fallback Chain to 12 models across 3.x, 2.5, 2.0, and 1.5 Flash/Lite/Pro families with preferred model picker.

---

## [1.3.0] - 2026-11-13

### Added
- Multi-model Gemini Fallback Chain and connection tester in Settings.

---

## [1.2.1] - 2026-11-12

### Added
- 14-day template quota enforcement and active schedule banner.

---

## [1.2.0] - 2026-11-11

### Added
- Bolero zero-calorie hydration quick-chip.
- Sleep rating notification alignment with morning schedule.

---

## [1.0.0] - 2026-11-10

### Added
- Production release: InsightsView with Swift Charts, 7-day cyclical PlanView with AI Import, AILogSheet, and SettingsView.

---

## [0.1.0] - [0.9.0] - 2026-11-01

### Added
- Pure Swift Domain Core (M1), NotificationPlanner & SigningGuard (M2), HealthKit integration & FakeHealthStore (M3-M4), Widgets & WeeklyStats (M5-M6), AI Router & Local Telemetry (M7-M9).
