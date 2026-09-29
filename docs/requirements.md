# EisuKana Switch 要求定義

## 1. 背景・目的

macOS で JIS キーボードの「英数」「かな」キーと同じ操作を、US 配列などのキーボードで左右の ⌘ キーにより実現したい。
既存の「⌘英かな」（[iMasanari/cmd-eikana](https://github.com/iMasanari/cmd-eikana), MIT License）は 2017 年以降リリースが無く、最新 macOS での動作継続に不安がある。
そこで、最新の macOS / Swift / SwiftUI で動作する後継的な OSS アプリを新規に作成する。

## 2. 対象

- 対応 OS: macOS 14 Sonoma 以降（最新の macOS を主対象とする）
- 対応 CPU: Apple Silicon / Intel（Universal Binary）
- 利用者: US 配列などで日本語入力を行う macOS ユーザー

## 3. 機能要件

### 3.1 必須（MVP）

| ID | 要件 |
| --- | --- |
| F-01 | 左 ⌘ キーを単独で押して離すと、入力ソースが英数（ABC 等）に切り替わる |
| F-02 | 右 ⌘ キーを単独で押して離すと、入力ソースがかな（日本語）に切り替わる |
| F-03 | ⌘ + 他キー（⌘C 等）、⌘ + クリック、他の修飾キーとの同時押しでは切り替わらない。本来のショートカットは一切妨げない |
| F-04 | メニューバーに常駐し、有効/無効の切り替え・About・終了ができる（Dock には表示しない） |
| F-05 | ログイン時に自動起動する設定を ON/OFF できる |
| F-06 | 必要な権限（入力監視 / アクセシビリティ等）が未許可の場合、状態を表示し、システム設定への案内を出す |

### 3.2 任意（MVP 以降）

| ID | 要件 |
| --- | --- |
| O-01 | ⌘ を長押しした場合は切り替えない（しきい値を設定可能） |
| O-02 | 左右 ⌘ への割り当て（英数/かな/何もしない）を入れ替え・変更できる |
| O-03 | 特定のアプリでは無効にする |
| O-04 | 他のキーの割り当て変更（キーリマップ） |

## 4. 非機能要件

| ID | 要件 |
| --- | --- |
| N-01 | キー入力の遅延を体感できないこと。常駐時の CPU 使用率はほぼ 0% |
| N-02 | キー入力の内容を保存・送信しない。ネットワーク通信を行わない |
| N-03 | Mac App Store の審査ガイドラインに適合すること（App Sandbox 有効） |
| N-04 | Homebrew Cask でインストールできること（Developer ID 署名 + 公証済み） |
| N-05 | ライセンスは MIT。cmd-eikana を参考にした旨を README に明記する |
| N-06 | UI は日本語・英語に対応する |

## 5. 配布

- **Mac App Store**: App Sandbox 有効の状態で提出する
- **Homebrew**: 独自 tap（`HaruhikoMotokawa/homebrew-tap`）で `brew install --cask eisukana-switch` を提供する。将来的に公式 homebrew-cask への登録も検討する
- **GitHub Releases**: 署名・公証済みの zip/dmg を配布する

App Store 版と Developer ID 版は、同一のソースコード・同一の Sandbox 設定からビルドする。

## 6. 技術方針と主要リスク

- 実装: Swift / SwiftUI（`MenuBarExtra`）、自動起動は `SMAppService`
- キー検出: `CGEventTap`（`flagsChanged` を監視して、左右 ⌘ の単独押下を判定する）
- 入力ソース切り替えの候補:
  - A) 英数/かなのキーイベント（`kVK_JIS_Eisu` / `kVK_JIS_Kana`）を送る。元アプリと同じ方式で、IME との相性が良い
  - B) `TISSelectInputSource` で入力ソースを直接選ぶ

**リスク**: App Sandbox の下では、イベントタップを listen-only にする必要がある（入力監視の権限）。またイベントを送る場合は `CGRequestPostEventAccess` が必要になる。この組み合わせで App Store の審査を通せるかは、最初に検証（Spike）する。
検証の結果によっては、App Store 版だけ機能を制限する、または App Store 配布を断念することもあり得る。

## 7. スコープ外

- JIS キーボード固有の機能
- Windows / Linux 対応
