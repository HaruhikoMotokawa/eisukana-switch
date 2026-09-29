# 入力ソースの切り替え（英数 / かな）

F-01 / F-02 の実装メモ。左 ⌘ で英数、右 ⌘ でかなへ切り替える部分のうち、
「どの入力ソースを選ぶか」を決める層について書く。⌘ の単独押下の検出は別（#3）。

## `TISSelectInputSource` の前提

Spike #1 で方式は `TISSelectInputSource` に決まったが、実装前に macOS 26.5.1 /
ことえり（ローマ字入力）の環境で `TISInputSource` のプロパティを調べ直したところ、
前提を 2 つ修正する必要があった。

### 1. 最近の macOS では、ことえりの英数モードは有効になっていない

`TISCreateInputSourceList(nil, false)`（有効なものだけ）に入るのは
`com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese`（ひらがな）だけで、
`...RomajiTyping.Roman`（英数）は `kTISPropertyInputSourceIsEnabled` が false だった。

### 2. 無効な入力ソースは選べない

無効な入力ソースを `TISSelectInputSource` に渡すと `paramErr (-50)` が返り、切り替わらない。

```
select com.apple.inputmethod.Kotoeri.RomajiTyping.Roman -> status=-50（変わらず）
select com.apple.SyntheticRomanMode                     -> status=-50（変わらず）
select com.apple.keylayout.ABC                          -> status=0
```

つまり **ことえりだけの標準的な環境では、英数へは ABC などの ASCII 入力可能な
キーボードレイアウトに切り替えるしかない。** IME の英数モード（`*.Roman`）を選ぶ経路が
生きるのは、Google 日本語入力や ATOK のように、ユーザーが英数モードを入力ソースとして
有効にしている場合だけ。

## 切り替え先の決め方

候補は「有効」かつ「キーボード入力ソース（`kTISCategoryKeyboardInputSource`）」かつ
「選択可能（`kTISPropertyInputSourceIsSelectCapable`）」なものに限る。
判定は入力ソース ID の接尾辞ではなく `kTISPropertyInputModeID` で行う。
ことえり・Google 日本語入力・ATOK のいずれも、英数モードは `com.apple.inputmethod.Roman`、
ひらがなモードは `com.apple.inputmethod.Japanese` を返す。

**英数（左 ⌘）**

1. 現在がすでに英数なら何もしない（英数モード、または ASCII 入力可能なキーボードレイアウト）
2. 現在の IME と同じ `kTISPropertyBundleID` を持つ英数モード
3. 任意の英数モード
4. `TISCopyCurrentASCIICapableKeyboardInputSource()` が指すキーボードレイアウト（有効一覧にあれば）
5. `com.apple.keylayout.ABC`
6. 最初の ASCII 入力可能なキーボードレイアウト

4 を挟んでいるのは、Dvorak や US-International を使っている人のレイアウトを
ABC で奪わないため。このメソッドは有効でない入力ソースを返すことがあるので、
有効一覧に含まれるときだけ採用する。

**かな（右 ⌘）**

1. 現在がすでに `com.apple.inputmethod.Japanese` なら何もしない
2. 現在の入力ソースと同じ `kTISPropertyBundleID` を持つひらがなモード（英数モードからの復帰）
3. 直前に離れたひらがなの入力ソースと同じ `kTISPropertyBundleID` のもの
4. 有効一覧の順で最初のひらがなモード

3 は、ABC ↔ かなを往復するときのためのもの。複数の IME を有効にしていても、
直前に使っていた IME に戻る。

カタカナ・全角英数・半角カナは英数でもひらがなでもないので、
左 ⌘ で英数へ、右 ⌘ でひらがなへ抜けられる。

## 構成

| 型 | 役割 |
| --- | --- |
| `InputSourceTarget` / `CommandSide` | 切り替え先と、左右 ⌘ への割り当て |
| `InputSourceDescriptor` | `TISInputSource` から必要なプロパティだけ写した値型 |
| `InputSourceSelector` | 上のルールを実装した純粋関数 |
| `InputSourceRepository` | 一覧取得・現在値取得・選択のプロトコル。`CarbonInputSourceRepository` が TIS を呼ぶ |
| `InputSourceSwitcher` | `InputSourceSwitching` の実装。状態を集めてセレクタに渡し、結果を適用する |

Carbon は `CarbonInputSourceRepository` の内側だけに閉じているので、
切り替えのルールは実機の入力ソース構成に関係なくユニットテストできる。

⌘ の単独押下を検出する側（#3）からは、次の 1 本だけを呼ぶ。

```swift
switcher.activate(for: side)   // .left → 英数 / .right → かな
```

## 性能（N-01）

`TISCreateInputSourceList(nil, false)` は 0.164 ms/call（200 回平均、Apple Silicon）。
呼ぶのは ⌘ の単独押下を検出したときだけなので、キャッシュや
`kTISNotifyEnabledKeyboardInputSourcesChanged` の購読は入れていない。

## 実機での確認

入力ソースを実際に切り替えるテストは、環境変数 `EISUKANA_RUN_LIVE_TESTS=1` を
与えたときだけ動く（スキームの Test > Arguments にチェックを入れれば有効になる）。
テストの最後に元の入力ソースへ戻す。

## 残っている課題

- ABC などを無効にして IME だけを有効にしている環境では、英数の候補が 1 つも無い。
  `InputSourceSwitchResult.noCandidate` を返すところまでは用意してあるが、
  メニューでの案内は #5 / #6 で扱う。
- Google 日本語入力 / ATOK での実機確認は、Spike #1 から引き続き未検証。
  上のルールは、両者が `kTISPropertyInputModeID` に標準の値を返すことを前提にしている。
