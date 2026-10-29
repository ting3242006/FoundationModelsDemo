# iPhone 17 Pro physical-test preflight (read-only)

Checked at 2026-10-22 using `xcrun devicectl` and `xcodebuild -showdestinations`.
No app was installed, no project setting changed, and no device content was read.

## Device state

The selected physical iPhone 17 Pro (`iPhone18,1`) reports iOS 27.0.1,
build 24A446, `connected`, `paired`, transport `wired`, and Developer Mode 1.
`devicectl device info lockState` reports `passcodeRequired: true` and
`unlockedSinceBoot: true`; it does not expose a present locked/unlocked UI
boolean in the extracted fields.

`xcodebuild -project MessyNote.xcodeproj -scheme MessyNote -showdestinations`
lists this same device ID as a compatible iOS destination. Therefore Xcode can
select it as a scheme destination.

## Signing state

`project.yml` has `DEVELOPMENT_TEAM: ''`; generated project settings likewise
have `DEVELOPMENT_TEAM = ""`. Automatic signing is configured, but this
preflight does not establish that a team will be selected or that installation
will succeed.

## Apple Intelligence state

The inspected public `devicectl device info` fields exposed no
Apple-Intelligence-enabled, model-ready, or FoundationModels-availability
state. That state is unknown from this preflight.

## Scope note

The previous iPhone 15 Plus is not used for this preflight. The currently
connected iPhone 17 Pro is the Xcode-compatible physical destination.
