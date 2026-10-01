# リリース手順（Developer ID / GitHub Releases）

`v1.2.3` のようなタグを push すると、[Release ワークフロー](../.github/workflows/release.yml) が次を順に実行する。

1. タグからバージョンを決める（`MARKETING_VERSION` はタグ、`CURRENT_PROJECT_VERSION` はワークフローの実行番号）
2. Developer ID Application 証明書で署名してアーカイブ・エクスポートする
3. `.app` を `notarytool` で公証し、staple して zip にする
4. その `.app` を入れた dmg を作り、署名・公証・staple する
5. zip / dmg / `SHA256SUMS.txt` を GitHub Releases に上げる（リリースノートは自動生成）

`v1.2.3-beta.1` のように `-` の付いたタグはプレリリースとして公開する。この場合も `CFBundleShortVersionString` は `1.2.3` になる。

## 前提

- Apple Developer Program に登録していること
- 「Developer ID Application」証明書を作成済みであること（Xcode の Settings → Accounts → Manage Certificates で作れる）

## GitHub Secrets

リポジトリの Settings → Secrets and variables → Actions に、次の 5 つを登録する。Team ID は証明書の名前から取り出すので登録しなくてよい。

| Secret | 内容 |
| --- | --- |
| `DEVELOPER_ID_CERT_P12_BASE64` | Developer ID Application 証明書と秘密鍵を書き出した `.p12` を base64 にしたもの |
| `DEVELOPER_ID_CERT_PASSWORD` | `.p12` を書き出したときに付けたパスワード |
| `ASC_API_KEY_P8_BASE64` | App Store Connect API キー（`.p8`）を base64 にしたもの |
| `ASC_API_KEY_ID` | API キーの Key ID |
| `ASC_API_ISSUER_ID` | API キーの Issuer ID |

### 証明書（.p12）

1. キーチェーンアクセスで「Developer ID Application: 〜」を秘密鍵ごと選び、「書き出す」で `.p12` にする（パスワードを付ける）
2. base64 にしてクリップボードに入れ、Secret に貼る

```sh
base64 -i DeveloperID.p12 | pbcopy
```

### App Store Connect API キー（公証用）

1. App Store Connect → ユーザとアクセス → 統合 → App Store Connect API で、「Developer」ロールのチームキーを作る
2. `AuthKey_XXXXXXXXXX.p8` をダウンロードする（一度しかダウンロードできない）
3. 画面に出ている Key ID と Issuer ID を Secret に登録し、`.p8` は base64 にして登録する

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

書き出した `.p12` / `.p8` は、Secret に登録したら手元から消しておく。

## リリースする

```sh
git switch main
git pull
git tag v0.1.0
git push origin v0.1.0
```

Actions タブで Release ワークフローの完了を待つ。公証は通常数分で終わるが、Apple 側が混んでいると長引く（各 30 分でタイムアウト）。

失敗したときは、原因を直してからタグを付け直す。

```sh
gh release delete v0.1.0 --yes   # リリースが作られていた場合だけ
git push origin :refs/tags/v0.1.0
git tag -f v0.1.0
git push origin v0.1.0
```

### 公証に失敗したとき

ログに出ている submission ID を使って、手元で理由を確認できる。

```sh
xcrun notarytool log <submission-id> --key AuthKey_XXXXXXXXXX.p8 --key-id <Key ID> --issuer <Issuer ID>
```

## 手元での確認

ダウンロードした成果物が署名・公証済みであることは、次のコマンドで確かめられる。

```sh
xcrun stapler validate EisuKanaSwitch.app
spctl --assess --type execute --verbose=4 EisuKanaSwitch.app
# → accepted / source=Notarized Developer ID
```
