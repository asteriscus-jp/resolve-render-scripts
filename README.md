# resolve-render-scripts

DaVinci Resolve のデリバーページ「レンダー［開始／終了］時にスクリプト実行」で使うスクリプトの作成事例です。

解説記事（設定方法・簡易サンプルの説明）: https://asteriscus.jp/

> ここにあるのは説明なしの作成事例です。動作は無保証で、個別のサポートは行っていません。

## 使い方

1. 使いたいスクリプトを次のフォルダに置き、Resolve を再起動する
   - Windows: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Deliver`
   - macOS: `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Deliver`
2. デリバーページ > レンダー設定 > 詳細設定 で「レンダー［開始］／［終了］時にスクリプト実行」にチェックし、スクリプトを選ぶ
3. 設定はジョブごと。複数ジョブでまとめたいときは、すべてのジョブに同じスクリプトを指定する

各ファイル冒頭のコメントに、設定する値（通知音、Webhook URL など）を書いています。

## 一覧

| ファイル | 実行 | 内容 | Studio | 無償版 |
|---|---|---|:-:|:-:|
| [End_RenderMarker.lua](scripts/End_RenderMarker.lua) | 終了時 | 結果をコンソールに表示し、全ジョブ終了後にタイムラインへ結果の色でマーカー、エディットページへ切替 | ○ | ○ |
| [End_RenderNotify.lua](scripts/End_RenderNotify.lua) | 終了時 | 完了ダイアログ（保存先を開く）＋通知音（システム音／音声ファイル） | ○ | × |
| [End_RenderSummary.lua](scripts/End_RenderSummary.lua) | 終了時 | 全ジョブ終了後に、結果の一覧ダイアログ＋通知音 | ○ | × |
| [End_RenderLog.py](scripts/End_RenderLog.py) | 終了時 | 結果を CSV（ドキュメント/ResolveRenderLog.csv）に追記 | ○ | × |
| [End_RenderSlack.py](scripts/End_RenderSlack.py) | 終了時 | Slack に結果を送信 | ○ | × |
| [End_RenderDiscord.py](scripts/End_RenderDiscord.py) | 終了時 | Discord に結果を送信 | ○ | × |
| [End_RenderMail.py](scripts/End_RenderMail.py) | 終了時 | メールで結果を送信 | ○ | × |
| [End_RenderSummaryNotify.py](scripts/End_RenderSummaryNotify.py) | 終了時 | 全ジョブ終了後に、まとめを Slack / Discord / メールで 1 通送信 | ○ | × |
| [Start_RenderTimer.py](scripts/Start_RenderTimer.py) | 開始時 | ジョブの終了まで見張り、開始・終了・処理時間を CSV に記録 | ○ | × |

## 無償版について

無償版（21.2 Build 6 で確認）でも Lua の開始／終了時スクリプトは実行されますが、次の機能が使えません。

- Python スクリプト（一覧に表示されない）
- ファイルの読み書き（`io`）、`require`（ffi）、外部コマンド（`os.execute`）、`bmd.openfileexternal`
- ダイアログ（UIManager）

そのため、無償版で使えるのは End_RenderMarker.lua だけです。

## 注意

- Webhook URL やパスワードを書いたファイルを、人に渡したり公開したりしないでください。
- 同じ名前の `.lua` と `.py` を同じフォルダに置くと、一覧ではどちらか一方しか表示されません。
- レンダー中（開始時スクリプト、および複数ジョブで最後以外のジョブの終了時）は、ページ切替やマーカー追加などの操作が反映されません。

## 動作確認環境

- DaVinci Resolve Studio 21.2 Build 6 / DaVinci Resolve 21.2 Build 6（無償版）
- Windows 11（macOS は未検証）

## ライセンス

[MIT](LICENSE) © asteriscus
