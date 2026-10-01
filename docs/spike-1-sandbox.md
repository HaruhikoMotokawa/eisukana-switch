# Spike #1: App Sandbox 下でのキー検出・入力ソース切り替え

- 実施日: 2026-09-29
- 環境: macOS 26.5.1 (25F80) / Apple Silicon / 入力ソースは ABC とことえり（ローマ字入力）
- 検証アプリ: [`spike/SandboxSpike`](../spike/SandboxSpike)（App Sandbox 有効、アドホック署名）

## 結論

**「listen-only の CGEventTap（入力監視の権限だけ）」＋「`TISSelectInputSource`」の組み合わせを採用する。**
アクセシビリティとイベント送信（PostEvent）の権限は使わない。

> **追記（2026-10-01, #32）**: 方式 B（`TISSelectInputSource`）は、メニューバーの表示は変わっても
> 前面のアプリの入力モードが変わらないことがわかり、方式 A（キーイベントの送信）に切り替えた。
> 下の「切り替え後、文字を打っても問題なし」は、切り替えた Spike アプリ自身のウインドウで打って確かめたもので、
> 他のアプリでは確かめていなかった。詳しくは [input-source-switching.md](input-source-switching.md)。

## 結果

| 項目 | 必要な権限 | 結果 |
| --- | --- | --- |
| listen-only の `CGEventTap` で左右 ⌘ を区別して検出（keyCode 55 / 54） | 入力監視 | ✅ 動作 |
| ⌘ + 他キー（⌘C, ⌘V など）を単独押下と区別 | 入力監視 | ✅ `keyDown` が届くので除外できる |
| 方式 A: `kVK_JIS_Eisu` / `kVK_JIS_Kana` を `CGEvent.post` で送る | PostEvent（設定画面では「アクセシビリティ」） | ⚠️ 許可すれば動く。未許可だとエラーも出ずに捨てられる |
| 方式 B: `TISSelectInputSource` で ABC / ことえりを選ぶ | 不要 | ✅ 動作（`status=0`）。切り替え後、文字を打っても問題なし |

## わかったこと・注意点

- 入力監視の権限がないときでも、`CGEvent.tapCreate` は成功してしまう。ただしイベントは届かず、キー入力のたびに `tapDisabledByUserInput` が発生する。そのため、`CGPreflightListenEventAccess()` で権限を確認してから監視を始める（#6）。
- 権限は、許可したあとにアプリを再起動しないと反映されない。許可されたことを検知して、監視を開始し直す仕組みが必要（#6）。
- アドホック署名のアプリは、ビルドし直すたびに TCC からは別のアプリと見なされ、権限が外れる。システム設定の一覧に出てこないこともあった。開発中も Apple Development 証明書（無料の Personal Team で可）で署名する（#2）。
- 英数に切り替えるときは、IME の英字モード（`*.Roman`）が有効ならそれを選び、なければ `com.apple.keylayout.ABC` を選ぶ。

## 未検証（残っているリスク）

- **App Review の判断**: 審査を通るかは、実際に提出するまでわからない。アクセシビリティ系の API を使わないので、ガイドライン 2.4.5 によるリジェクトのリスクは低いと見ている（参考: [Apple Developer Forums 820594](https://developer.apple.com/forums/thread/820594)）。MVP ができた段階で、早めに TestFlight か審査に出して確かめる（#11）。
- Google 日本語入力 / ATOK での動作（この環境には入っていない）。
- ⌘ + クリック、⌘ + スクロールの除外（コード上はマウスイベントも監視しているが、実際の操作では確認していない）。
