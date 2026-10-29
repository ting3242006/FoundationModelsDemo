# MessyNote Native Studio Implementation Plan

> For agentic workers: use superpowers:subagent-driven-development. The user approved this design and implementation on 2026-10-27; do not request design approval again.

Goal: Redesign the existing note-to-calendar demo as a native note studio, preserving every current model/tool/edit/review/save capability.
Architecture: SwiftUI presentation-only work around the existing PlannerViewModel and ReviewedEvent/SaveReview. Keep the current state machine, permission timing and EventKit commit boundary. Share a small event preview component between planner and final confirmation.
Tech Stack: Existing SwiftUI iOS 27 app; no dependencies or deployment changes.

## Constraints
- Work in /Users/yitingsung/Developer/FMDemo. No Git repository exists; do not initialize Git or commit. Preserve baseline copies and a unified diff.
- Source path is outside the current writable roots: actual source writes require exec_command require_escalated. Do not circumvent the sandbox. User explicitly authorized this target and redesign.
- Never write AGENTS.md, policy/configuration protection files, or change capabilities/permissions.
- Preserve model generation, typed partial generation, follow-up, cancellation, reset, missing-time picker, manual event editing, contact selection and unresolved-name option, conflict/unknown distinction, suggested slot acceptance, demo fixtures and their real-write warning, AI activity and raw diagnostics, final confirmation/cancel, saving lock and saved lock.
- Only final confirmation may invoke existing confirmSave; no test or visual check should create real calendar events without a fake writer.
- Do not change PlannerViewModel, model/tool/services, or stored event semantics for styling.
- Preserve accessibility identifiers and current test fixtures. Add stable identifiers only as needed for meaningful UI tests.
- No speculative features, extra tabs, onboarding or dependencies.

## Task 1 — Behavioral regression evidence
- [ ] Read applicable project instructions and the implementation-context report.
- [ ] Backup every file before modifying it under /private/tmp/fmdemo-native-studio-baseline; record hashes.
- [ ] Inspect current UI tests. Add a focused UI test for the new primary entry action, the disclosure/edit interaction, and the review cancellation boundary using existing injected fixtures and fake storage. Run before production changes and record expected assertion failures.
- [ ] Keep existing model/service regression tests. Avoid tests that merely assert colors or mirror view implementation.

## Task 2 — Native note studio views (one serial writer)
Files: MessyNote/Feature/Planner/PlannerView.swift, EventEditorView.swift, SaveReviewView.swift; add a small EventPreviewView.swift and StudioStyle.swift only if shared code benefits all three. Tests: existing UI test file(s). Asset changes only if required by existing project setup.
- [ ] Planner: NavigationStack with adaptive content. Compact width uses one column; regular available width uses note and event columns. At accessibility sizes prefer stacking. Use ScrollView with grouped surfaces instead of an all-purpose Form as the top-level canvas.
- [ ] Intro: MessyNote, display text "把想法，排進生活", concise note guidance, editable note and example action, primary action "整理成活動". Keep generate/follow-up enabled semantics compatible with existing model.
- [ ] Generation: real partial fields appear in a preview, truthful status and explicit cancel. Use only a brief reduced-motion-aware transition; no fabricated percentage.
- [ ] Result: event preview with calendar date tile, title, start/end, location, readable participant/status information. Original note may collapse once a draft exists but must remain editable for follow-ups. A visible "編輯" disclosure exposes all original editable fields with explicit labels.
- [ ] Missing date/time and all errors remain actionable and visible; explain failure in plain Chinese and offer expandable original diagnostic text without misclassifying unknown errors.
- [ ] Contact and calendar sections preserve candidates, unresolved choice, actual conflicts, unknown state and next slot action. No missing evidence represented as a success.
- [ ] Toolbar holds reset, recheck and DEBUG fixture controls. Active fixture mode remains visibly labeled and clearly states that final confirmation writes a real event. AI processing log remains accessible via disclosure.
- [ ] One prominent next action "檢查並加入" invokes prepareSave. Preserve canSave gating. Saved success remains visible.
- [ ] SaveReview: reuse event preview, localized dates in the event timezone, natural reminder labels (0,15,120,1440 and arbitrary values preserved), clear participants-only-in-notes notice. Keep fixture warning, snapshot warning, actual error, saving progress and cancellation. Primary "確認加入行事曆" and cancellation remain reachable via safeAreaInset; keyboard/safe areas/large text must not cover content.
- [ ] Color roles: background light F6F7FA/dark 121316, surface FFFFFF/1B1C20, primary 202124/F3F4F7, secondary 63666E/A9ADB8, accent 315BC7/9AB6FF. Use semantic/dynamic choices and stronger contrast fallbacks; don't freeze system colors to sampled hex values. Text-on-surface ratios >=4.5:1. CTA foreground must contrast with its fill in both appearances.
- [ ] Typography: system largeTitle/title2/body (default 34/22/17pt), regular through bold weights; SF Symbols. Approximate 20pt page margins, 24pt section gaps, generous single-purpose surfaces. Native glass only for navigation/control layers. Honor Reduce Motion/Transparency, support large Dynamic Type and labeled >=44pt hit targets.

## Task 3 — Validation and delivery
- [ ] Run new focused UI tests and affected existing UI tests; then main conversation runs the complete project-defined tests/build/lint once on the final state.
- [ ] Inspect rendered initial, draft/edit, final review, missing-data/error and saved states supported by existing fixtures. Capture light/dark, narrow phone and iPad/regular width plus large Dynamic Type. Do not claim hardware model inference passes based on simulator fixtures.
- [ ] Inspect the diff against baseline, confirm only approved presentation/test/docs files changed and all original actions remain wired to their existing model methods.
- [ ] Save implementation report, exact commands/exit statuses and screenshots. Status IMPLEMENTATION_COMPLETE only when project checks are green; MERGE_READY is out of scope (no Git/PR requested).

## Progress
- [x] Design approved by user.
- [ ] Test-first evidence captured.
- [ ] View implementation complete.
- [ ] Full verification and visual review complete.
