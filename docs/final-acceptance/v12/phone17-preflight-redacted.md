# iPhone 17 Pro read-only preflight (redacted)

Checked: 2026-10-22 23:37 CST.

## Current device details
- Physical iPhone 17 Pro, iOS 27.0.1 (build 24A446).
- Device State: connected; Pairing State: paired; transport: localNetwork; tunnel transport: TCP.
- Developer Mode: Enabled (1); boot state: booted.

## Scheme destination
- `xcodebuild -showdestinations` lists this iPhone 17 Pro as a compatible iOS destination for the MessyNote scheme.

## Project signing state
- `project.yml` has `CODE_SIGN_STYLE: Automatic` and `DEVELOPMENT_TEAM: ''`.
- Generated project contains `DEVELOPMENT_TEAM = "";`.

## Directly observed constraint
- This report did not build, sign, install, or launch the app. The empty project development-team setting remains present; no deployment conclusion is made here.

Identifiers, device name, tunnel address, serial, and ECID are intentionally omitted.
