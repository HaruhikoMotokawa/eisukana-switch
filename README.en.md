# EisuKana Switch

[日本語](README.md)

A macOS menu bar app that switches between alphanumeric (英数) and kana (かな) input when you press the left or right ⌘ key on its own.
It gives US and other non-JIS keyboards the same behavior as the 英数 / かな keys on a JIS keyboard.

- Left ⌘ → alphanumeric (英数)
- Right ⌘ → kana (かな)

Shortcuts such as ⌘C, ⌘-click, and combinations with other modifier keys do not switch the input source.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon / Intel

## Installation

### Homebrew

```sh
brew install --cask HaruhikoMotokawa/tap/eisukana-switch
```

To update, run `brew upgrade --cask eisukana-switch`.

### GitHub Releases

Download the zip or dmg from [Releases](https://github.com/HaruhikoMotokawa/eisukana-switch/releases) and move `EisuKanaSwitch.app` to your Applications folder.
The app is signed with a Developer ID and notarized by Apple.

## First-time setup (Input Monitoring)

EisuKana Switch needs Input Monitoring access to notice the ⌘ keys.
Keystrokes are never stored or sent anywhere, and the app makes no network connections.

1. When you launch EisuKana Switch for the first time, macOS shows a confirmation dialog and the app shows an "Input Monitoring is required" window. Choose "Open System Settings" in either of them
2. In **System Settings > Privacy & Security > Input Monitoring**, turn on EisuKana Switch
3. When the app's window changes to "Input Monitoring is allowed", you are done. You do not need to restart the app

If you closed the window, choose "Open System Settings…" from the menu bar icon.
If EisuKana Switch is not in the list, add `/Applications/EisuKanaSwitch.app` with the "+" button.

## Usage

Click the menu bar icon to open the menu. The app does not appear in the Dock.

| Item | Description |
| --- | --- |
| Enabled | When off, pressing ⌘ does not switch the input source |
| Launch at Login | Starts the app automatically when you log in. If you see "Needs approval in Login Items", allow it in System Settings > General > Login Items |
| About EisuKana Switch | Version and credits |
| Quit | Quits the app |

For alphanumeric, the app selects your IME's alphanumeric mode (if you have enabled it, e.g. in Google Japanese Input) or a keyboard layout such as ABC.
For kana, it selects the hiragana mode of the Japanese IME you used most recently.
See [docs/input-source-switching.md](docs/input-source-switching.md) (Japanese) for the detailed rules.

## Uninstallation

If you installed with Homebrew, you can remove the app together with its settings:

```sh
brew uninstall --zap --cask eisukana-switch
```

If you installed manually, quit the app and delete `/Applications/EisuKanaSwitch.app`.
You can remove the leftover entry in System Settings > Privacy & Security > Input Monitoring with the "−" button.

## Development

### Requirements

- Xcode 26.0.1 (the same version as CI)
- macOS 14 or later

### Build and run

```sh
git clone https://github.com/HaruhikoMotokawa/eisukana-switch.git
cd eisukana-switch
open EisuKanaSwitch.xcodeproj
```

1. In Signing & Capabilities of the EisuKanaSwitch target, set Team to your own (a personal Apple ID works)
2. Select the EisuKanaSwitch scheme and press ⌘R

Input Monitoring access is tied to the app's code signature. If the signature changes, you may need to allow it again;
if the app does not respond, remove it from Input Monitoring in System Settings and allow it again.

### Tests

```sh
xcodebuild test \
  -project EisuKanaSwitch.xcodeproj \
  -scheme EisuKanaSwitch \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO
```

Tests that actually switch the input source run only when the environment variable `EISUKANA_RUN_LIVE_TESTS=1` is set
(check it in the scheme's Test > Arguments).

### Documents (Japanese)

- [Requirements](docs/requirements.md)
- [Spike #1: key detection and input source switching under App Sandbox](docs/spike-1-sandbox.md)
- [Input source switching (英数 / かな)](docs/input-source-switching.md)
- [Release process](docs/release.md)

## Acknowledgements

This app is inspired by [⌘英かな (iMasanari/cmd-eikana)](https://github.com/iMasanari/cmd-eikana) (MIT License).

## License

[MIT](LICENSE)
