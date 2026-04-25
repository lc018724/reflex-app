# GPT-5.5 Reflex App: 4-hour test + improve directive

You are GPT-5.5 working autonomously on the Reflex iOS app on branch `feat/gpt55-test-2026-04-25`. This directive bounds your work for the next ~4 hours.

## Repository context

- **Working dir:** `/Users/paigeturner/.openclaw/workspace/projects/ReflexApp`
- **App:** Reflex, iOS cognitive training (Stroop, N-Back, Gauntlet, 20 modes total)
- **Stack:** SwiftUI, xcodegen, no external SDKs (no RevenueCat, no Firebase). Runs offline.
- **Files:** `Sources/Reflex/*.swift` (23 files). `project.yml` defines the Xcode project. `Reflex.xcodeproj` is the generated project.
- **Important:** RevenueCat does NOT belong in this repo. Do not add it. Reflex is free / no subscriptions.
- **Branch:** Already on `feat/gpt55-test-2026-04-25`. Push with `git push origin feat/gpt55-test-2026-04-25`.

## Style + safety rules

- No em-dashes anywhere (in code comments, commit messages, the report). Use commas, periods, semicolons.
- No emojis.
- Commit each meaningful unit of work separately with a clear `feat:` / `fix:` / `test:` prefix. Push after each phase.
- Do NOT mention AI, GPT, OpenAI, or model names in any commit message, code comment, or in-app text. Internal notes in `GPT55_TEST_REPORT.md` are fine.
- Do not modify `.github/`, `.claude/`, or any file outside `projects/ReflexApp/`.
- If you hit a rate limit or other unrecoverable error, save partial work to `GPT55_TEST_REPORT.md`, commit, push, and exit cleanly.

## Phase 1: Backend testing (~90 min)

The repo currently has ZERO XCTest targets. The files named `TestEngine.swift`, `TestView.swift`, `TestStore.swift` are app feature code (the cognitive-test feature), not unit tests. Confirm this yourself with `grep -r "import XCTest"`.

Tasks:
1. Create an XCTest target via `project.yml` and run `xcodegen generate` to regenerate the Xcode project.
2. Add unit tests for the logic layer:
   - `TestEngineTests.swift`: scoring math, timing accuracy, mode lifecycle, edge cases (zero-duration runs, rapid taps)
   - `TestStoreTests.swift`: persistence round-trip, history queries, best-ever-score computation
   - `ModelsTests.swift`: data invariants, struct equality, decoding/encoding if Codable
3. Run `xcodebuild test -scheme Reflex -destination 'platform=iOS Simulator,name=iPhone 17'` until tests build cleanly.
4. Document every test you wrote and its result (pass/fail) in `GPT55_TEST_REPORT.md` under `## Phase 1 results`.
5. If a test reveals a bug in the app code, log it in `GPT55_TEST_REPORT.md` with a short description and the file:line where the bug lives. Do NOT fix bugs yet; that is Phase 3.
6. Commit and push: `test: add XCTest target with TestEngine/Store/Models coverage`.

## Phase 2: Simulator walk-through (~90 min)

Tasks:
1. Build the app: `xcodebuild -scheme Reflex -destination 'platform=iOS Simulator,name=iPhone 17' build`
2. Boot simulator: `xcrun simctl boot 'iPhone 17'` (skip if already booted)
3. Install the built `.app`: `xcrun simctl install booted <path>`
4. Launch: `xcrun simctl launch booted <bundle-id>` (find bundle id in `Info.plist` or `project.yml`)
5. Take a launch screenshot: `xcrun simctl io booted screenshot screenshots/01-launch.png`
6. For each of the 20 modes (Stroop, N-Back, Gauntlet, Memory, Find, Color, etc.), interactively or via xcuitest exercise the mode at least once. Capture a screenshot per mode.
7. Document everything you observe in `GPT55_TEST_REPORT.md` under `## Phase 2 results`. For each mode: works correctly / minor visual bug / functional bug / crash. Reference the screenshot file.
8. Commit and push: `test: simulator walk-through screenshots and notes`.

## Phase 3: Improvements (~60 min)

Tasks:
1. Read your Phase 1 + 2 findings. Pick the top 3-5 highest-impact issues. Prefer functional bugs over visual nits.
2. Fix each one in a separate commit, with the bug noted in the message body. Re-run the relevant test to confirm the fix.
3. Push after each fix.
4. Update `GPT55_TEST_REPORT.md` under `## Phase 3 fixes`.

## Final: Summary commit

End with a final commit `docs: GPT-5.5 test report (Apr 25)` that finalizes `GPT55_TEST_REPORT.md` with:
- Total tests added (count)
- Pass / fail breakdown
- Bugs found (count + list)
- Bugs fixed (count + list)
- Bugs deferred for human review (count + list)
- Time spent per phase (rough)

Push the final commit.

## What success looks like

- New XCTest target builds and at least 80% of new tests pass on first run
- Simulator launched cleanly, all 20 modes opened without immediate crash
- 3-5 fixes committed and pushed
- Branch ready for human review (the human will open a PR to main if satisfied)
- `GPT55_TEST_REPORT.md` exists, is clear, and captures every finding

## What to do if you get stuck

Do NOT spin endlessly. If a phase blocks you for more than 20 minutes:
1. Document the blocker in `GPT55_TEST_REPORT.md`
2. Skip to the next phase
3. Note in the final report what was skipped and why

This is a real-world test of GPT-5.5 on iOS work. Be honest about what you can and cannot do. Do not fabricate test results or screenshots.
