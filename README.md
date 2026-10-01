# EisuKana Switch

[English](README.en.md)

左右の ⌘ キーを単独で押すだけで、英数 / かな を切り替える macOS メニューバーアプリです。
US 配列などのキーボードで、JIS キーボードの「英数」「かな」キーと同じ操作ができます。

- 左 ⌘ → 英数
- 右 ⌘ → かな

⌘C などのショートカットや、⌘ + クリック、他の修飾キーとの同時押しでは切り替わりません。

## 動作環境

- macOS 14 Sonoma 以降
- Apple Silicon / Intel

## インストール

### Homebrew

```sh
brew install --cask HaruhikoMotokawa/tap/eisukana-switch
```

アップデートは `brew upgrade --cask eisukana-switch` で行えます。

### GitHub Releases

[Releases](https://github.com/HaruhikoMotokawa/eisukana-switch/releases) から zip または dmg をダウンロードし、`EisuKanaSwitch.app` を「アプリケーション」フォルダに入れてください。
Developer ID で署名し、Apple の公証を受けています。

## 初回の設定（入力監視の許可）

⌘ キーが押されたことを知るために、「入力監視」の許可が必要です。
キー入力の内容を保存したり、送信したりすることはありません（ネットワーク通信も行いません）。

1. EisuKana Switch を初めて起動すると、macOS の確認ダイアログと、アプリの「入力監視の許可が必要です」という案内が出ます。どちらかの「システム設定を開く」を選びます
2. **システム設定 > プライバシーとセキュリティ > 入力監視** で、EisuKana Switch をオンにします
3. アプリの案内が「入力監視が許可されました」に変われば完了です。アプリを再起動する必要はありません

案内を閉じてしまった場合は、メニューバーのアイコンから「システム設定を開く…」を選んでください。
一覧に EisuKana Switch が無いときは、「+」ボタンから `/Applications/EisuKanaSwitch.app` を追加します。

## 使い方

メニューバーのアイコンをクリックすると、次のメニューが出ます。Dock には表示されません。

| 項目 | 内容 |
| --- | --- |
| 有効 | オフにすると、⌘ を押しても切り替えなくなります |
| ログイン時に起動 | ログイン時に自動で起動します。「ログイン項目での許可が必要です」と出たら、システム設定 > 一般 > ログイン項目 で許可してください |
| EisuKana Switch について | バージョンなど |
| 終了 | アプリを終了します |

英数には、使っている IME の英数モード（Google 日本語入力などで有効にしている場合）か、ABC などのキーボードレイアウトを選びます。
かなには、直前まで使っていた日本語 IME のひらがなモードを選びます。
詳しいルールは [docs/input-source-switching.md](docs/input-source-switching.md) を参照してください。

## アンインストール

Homebrew で入れた場合は、設定ごと削除できます。

```sh
brew uninstall --zap --cask eisukana-switch
```

手動で入れた場合は、アプリを終了してから `/Applications/EisuKanaSwitch.app` を削除してください。
システム設定 > プライバシーとセキュリティ > 入力監視 に残った項目は、「−」ボタンで消せます。

## 開発

### 必要なもの

- Xcode 26.0.1（CI と同じバージョン）
- macOS 14 以降

### ビルドと実行

```sh
git clone https://github.com/HaruhikoMotokawa/eisukana-switch.git
cd eisukana-switch
open EisuKanaSwitch.xcodeproj
```

1. ターゲット EisuKanaSwitch の Signing & Capabilities で、Team を自分のものにします（個人の Apple ID でも構いません）
2. スキーム EisuKanaSwitch を選び、⌘R で実行します

入力監視の許可は、アプリの署名に結び付きます。署名が変わると許可し直しが必要になることがあるので、
動かないときはシステム設定の入力監視から一度消して、許可し直してください。

### テスト

```sh
xcodebuild test \
  -project EisuKanaSwitch.xcodeproj \
  -scheme EisuKanaSwitch \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO
```

実際に入力ソースを切り替えるテストは、環境変数 `EISUKANA_RUN_LIVE_TESTS=1` を与えたときだけ動きます
（スキームの Test > Arguments でチェックを入れれば有効になります）。

### ドキュメント

- [要求定義](docs/requirements.md)
- [Spike #1: App Sandbox 下でのキー検出・入力ソース切り替え](docs/spike-1-sandbox.md)
- [入力ソースの切り替え（英数 / かな）](docs/input-source-switching.md)
- [リリース手順](docs/release.md)

## 謝辞

このアプリは [⌘英かな (iMasanari/cmd-eikana)](https://github.com/iMasanari/cmd-eikana)（MIT License）に着想を得ています。

## ライセンス

[MIT](LICENSE)
