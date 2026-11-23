# resolve-render-scripts

DaVinci Resolve のデリバーページ「レンダー［開始／終了］時にスクリプト実行」で使うスクリプトです。

- `simple/`：解説記事で説明している簡易版のサンプル
- `scripts/`：機能を足した完全版（説明なしの作成事例）

解説記事（設定方法・簡易版の説明）: https://asteriscus.jp/

> 動作は無保証で、個別のサポートは行っていません。

## 使い方

1. 使いたいスクリプトを次のフォルダに置く（Deliver フォルダが無ければ作る）。
   - Windows: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Deliver`
   - macOS: `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Deliver`
2. デリバーページ > レンダー設定 > 詳細設定 で「レンダー［開始］／［終了］時にスクリプト実行」にチェックし、スクリプトを選ぶ（ドロップダウンは開くたびにフォルダを読み直すので、再起動は不要）
3. 設定はジョブごと。複数ジョブでまとめたいときは、すべてのジョブに同じスクリプトを指定する

各ファイル冒頭のコメントに、設定する値（通知音、Webhook URL など）を書いています。

## 簡易版（simple/）— 記事のサンプル

解説記事で説明している、機能を 1 つに絞ったサンプルです。

| ファイル | 実行 | 内容 | Studio | 無償版 |
|---|---|---|:-:|:-:|
| [End_Notify.lua](simple/End_Notify.lua) | 終了時 | ダイアログとシステムの音で知らせる | ○ | × |
| [End_Marker.lua](simple/End_Marker.lua) | 終了時 | 結果をコンソールに表示し、全ジョブ終了後にタイムラインへ結果の色でマーカー、エディットページへ切替 | ○ | ○ |
| [End_Log.py](simple/End_Log.py) | 終了時 | 結果を CSV（ドキュメント/ResolveRenderLog.csv）に追記 | ○ | × |
| [End_Slack.py](simple/End_Slack.py) | 終了時 | Slack に結果を送信 | ○ | × |
| [End_Discord.py](simple/End_Discord.py) | 終了時 | Discord に結果を送信 | ○ | × |
| [End_Mail.py](simple/End_Mail.py) | 終了時 | メールで結果を送信 | ○ | × |

## 完全版（scripts/）— 作成事例

> 説明なしの作成事例です。簡易版に機能を足したもので、改造の参考用です。

| ファイル | 実行 | 内容 | Studio | 無償版 |
|---|---|---|:-:|:-:|
| [End_RenderNotify.lua](scripts/End_RenderNotify.lua) | 終了時 | 完了ダイアログ（保存先を開く）＋通知音（システム音／音声ファイル） | ○ | × |
| [End_RenderSummary.lua](scripts/End_RenderSummary.lua) | 終了時 | 全ジョブ終了後に、結果の一覧ダイアログ＋通知音 | ○ | × |
| [End_RenderMarker.lua](scripts/End_RenderMarker.lua) | 終了時 | 簡易版 End_Marker に、メモ欄の時刻・処理結果の表示を足したもの | ○ | ○ |
| [End_RenderLog.py](scripts/End_RenderLog.py) | 終了時 | 項目の多い CSV ログ | ○ | × |
| [End_RenderSlack.py](scripts/End_RenderSlack.py) | 終了時 | Slack に結果を送信（見やすく整えた形式） | ○ | × |
| [End_RenderDiscord.py](scripts/End_RenderDiscord.py) | 終了時 | Discord に結果を送信（埋め込み形式） | ○ | × |
| [End_RenderMail.py](scripts/End_RenderMail.py) | 終了時 | メールで結果を送信（SSL / STARTTLS 切替可） | ○ | × |
| [End_RenderSummaryNotify.py](scripts/End_RenderSummaryNotify.py) | 終了時 | 全ジョブ終了後に、まとめを Slack / Discord / メールで 1 通送信 | ○ | × |
| [Start_RenderTimer.py](scripts/Start_RenderTimer.py) | 開始時 | ジョブの終了まで見張り、開始・終了・処理時間を CSV に記録 | ○ | × |

簡易版と完全版は名前を分けているので、同じ Deliver フォルダに置いても混ざりません。

## 無償版について

無償版（21.2 Build 6 で確認）でも Lua の開始／終了時スクリプトは実行されますが、次の機能が使えません。

- Python スクリプト（一覧に表示されない）
- ファイルの読み書き（`io`）、`require`（ffi）、外部コマンド（`os.execute`）、`bmd.openfileexternal`
- ダイアログ（UIManager）

そのため、無償版で使えるのは End_Marker.lua（簡易版）と End_RenderMarker.lua（完全版）だけです。

## 注意

- Webhook URL やパスワードを書いたファイルを、人に渡したり公開したりしないでください。
- 同じ名前の `.lua` と `.py` を同じフォルダに置くと、一覧ではどちらか一方しか表示されません。
- レンダー中（開始時スクリプト、および複数ジョブで最後以外のジョブの終了時）は、ページ切替やマーカー追加などの操作が反映されません。
- 複数ジョブをまとめるスクリプト（End_Marker / End_RenderMarker / End_RenderSummary / End_RenderSummaryNotify）は、キュー全体のレンダーが止まるまで待ってから、最後に記録したジョブの分がまとめを出します。キューの最後のジョブに別のスクリプトが指定されていても動きます。

## 動作確認環境

- DaVinci Resolve Studio 21.2 Build 6 / DaVinci Resolve 21.2 Build 6（無償版）
- Windows 11 / macOS 26.6（Apple Silicon）
- Slack / Discord / メール（Gmail）への送信は Windows で確認。macOS での送信と App Store 版の Resolve は未確認

## 作者

asteriscus
- Web: https://asteriscus.jp/
- X: [@asteriscus_jp](https://x.com/asteriscus_jp)

## ライセンス

[MIT](LICENSE) © asteriscus
