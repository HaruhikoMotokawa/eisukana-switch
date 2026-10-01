# 入力ソースの切り替え（英数 / かな）

F-01 / F-02 の実装メモ。左 ⌘ で英数、右 ⌘ でかなへ切り替える部分について書く。
⌘ の単独押下の検出は別（#3）。

## 方式: 「英数」「かな」キーを送る

⌘ の単独押下を検出したら、JIS キーボードの「英数」キー（`kVK_JIS_Eisu`）または
「かな」キー（`kVK_JIS_Kana`）の keyDown / keyUp を `CGEvent.post(tap: .cghidEventTap)` で送る（`JISKeySwitcher`）。

どの入力ソースへ移るかは、本物のキーを押したときと同じく IME が決める。ことえりなら、英数キーで
ABC（または英字モード）、かなキーでひらがなになる。そのため、入力ソースの一覧を調べて
切り替え先を選ぶ処理は持っていない。

## `TISSelectInputSource` をやめた理由（#32）

当初（#4）は `TISSelectInputSource` で入力ソースを直接選んでいた。しかし CJKV の IME を選ぶと、
メニューバーの表示は変わるのに、前面のアプリの入力モードは変わらない。別のアプリへ移って戻ると反映される。
macOS の既知の不具合で、[macism](https://github.com/laishulu/macism) などは、一瞬自分のウインドウを
前面に出して戻すことで回避している。

その回避策は新しい権限が要らない代わりに、フォーカスが一瞬移るので、その間に打った文字が落ちたり、
開いていたポップアップが閉じたりする。確実に切り替わることを優先して、キーを送る方式にした。

## 必要な許可

| 許可 | 用途 | 確認 | 要求 |
| --- | --- | --- | --- |
| 入力監視 | ⌘ キーが押されたことを知る（listen-only の `CGEventTap`） | `CGPreflightListenEventAccess` | `CGRequestListenEventAccess` |
| アクセシビリティ | 「英数」「かな」キーを送る | `AXIsProcessTrusted` | `CGRequestPostEventAccess` |

どちらかが未許可の間は監視を始めず、案内を出して許可を待つ（`SwitchingController`）。
許可されたかは 1 秒ごとに確かめ、そろったら再起動せずに監視を始める。

### アクセシビリティの確認に `CGPreflightPostEventAccess` を使わない理由

`CGPreflightPostEventAccess` は、プロセスを起動したときの結果を返し続ける。起動したあとに許可されても
true にならないので、再起動しないと気づけない。システム設定の「アクセシビリティ」のスイッチは
TCC の `kTCCServiceAccessibility` と `kTCCServicePostEvent` を一緒に切り替えるので、
その時々の状態を返す `AXIsProcessTrusted` で見ている（macOS 26.5.1 で確認）。

### 許可が外れたとき

- 入力監視: タップが `tapDisabledByUserInput` で無効になるので、それを合図に止める（`CommandKeyMonitor`）
- アクセシビリティ: 外されても知らせは来ず、送ったキーはエラーも出ずに捨てられる。そのため、キーを送る前に毎回確かめ、
  外れていたら監視を止めて許可を待つ。呼ばれるのは ⌘ の単独押下のときだけなので、毎回でも負担にならない（N-01）

## 開発中の注意: 許可が効かないとき

TCC は、許可をバンドル ID とコード署名の要件（designated requirement）で覚える。ad-hoc 署名のビルドでは、
要件がそのビルドの cdhash になる。バンドル ID が同じなので、システム設定では 1 行にまとめて表示されるが、
スイッチをオンにしても、記録されている cdhash と違うビルドには効かない。

ユニットテストはアプリをホストにして動くので、テストを実行するとアプリ本体も起動する。
以前はここで許可を要求していたため、ad-hoc 署名のテスト用ビルドが先に TCC に登録され、
正式な署名のアプリでは許可が効かなくなっていた。今はテストのホストとして起動されたときは
監視も許可の要求もしない（`AppDelegate`）。

それでも許可が効かないときは、記録を消して許可し直す。

```sh
tccutil reset ListenEvent io.github.haruhikomotokawa.EisuKanaSwitch
tccutil reset Accessibility io.github.haruhikomotokawa.EisuKanaSwitch
tccutil reset PostEvent io.github.haruhikomotokawa.EisuKanaSwitch
```

記録されている要件は、次のように確かめられる（ターミナルにフルディスクアクセスが要る）。
`cdhash H"..."` になっていたら、ad-hoc 署名のビルドで登録されている。

```sh
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select service, hex(csreq) from access where client = 'io.github.haruhikomotokawa.EisuKanaSwitch'"
# hex を xxd -r -p でバイナリに戻し、csreq -r <file> -t で読める形にする
```

## 残っている課題

- Google 日本語入力 / ATOK での実機確認は、Spike #1 から引き続き未検証。
  本物の「英数」「かな」キーと同じ扱いになるはずだが、確かめていない。
