"""
End_RenderSlack.py  —  レンダー結果を Slack に送るサンプル（終了時スクリプト）
asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

配置先: Fusion/Scripts/Deliver
設定  : デリバー > レンダー設定 > ビデオ > 詳細設定
        [✓] レンダー [終了] 時にスクリプト実行   スクリプト: End_RenderSlack

準備  : Slack で Incoming Webhook を作り、URL を下の WEBHOOK_URL に貼る
        （https://api.slack.com/messaging/webhooks）
注意  : Webhook URL を知っている人は誰でもそのチャンネルに投稿できる。
        URL を書いたこのファイルを人に渡したり、公開したりしないこと。
"""
import datetime
import json
import os
import tempfile
import urllib.request

# ===== 設定 ==========================================================
WEBHOOK_URL = "https://hooks.slack.com/services/XXXX/XXXX/XXXX"
NOTIFY_ON = {"RenderCompleted", "RenderFailed", "RenderCancelled"}   # 送る結果
TIMEOUT_SEC = 10
# ====================================================================

JOB = globals().get("job", "")
STATUS = globals().get("status", "")
ERRMSG = globals().get("error", "")

LABEL = {
    "RenderCompleted": ":white_check_mark: レンダー完了",
    "RenderCancelled": ":double_vertical_bar: レンダーがキャンセルされました",
    "RenderFailed":    ":x: レンダー失敗",
}


def job_info():
    R = bmd.scriptapp("Resolve")
    project = R.GetProjectManager().GetCurrentProject()
    info = next((j for j in (project.GetRenderJobList() or []) if j.get("JobId") == JOB), {})
    return project.GetName() if project else "", info


def build_text(project_name, info):
    lines = [
        f"*{LABEL.get(STATUS, STATUS)}*",
        f"ファイル: `{info.get('OutputFilename', '?')}`",
        f"タイムライン: {info.get('TimelineName', '?')}（{project_name}）",
        f"保存先: {info.get('TargetDir', '?')}",
        f"時刻: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}",
    ]
    if ERRMSG:
        lines.append(f"エラー: {ERRMSG}")
    return "\n".join(lines)


def post_json(url, payload):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "ResolveRenderNotify/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as res:
        return res.status


def log_error(msg):
    # 失敗しても Resolve には何も出ないので、OS の一時フォルダにログを残す
    # （Windows: %TEMP% / macOS: $TMPDIR）
    path = os.path.join(tempfile.gettempdir(), "ResolveRenderNotify_error.log")
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} [Slack] {msg}\n")


def main():
    if STATUS not in NOTIFY_ON:
        return
    try:
        project_name, info = job_info()
        post_json(WEBHOOK_URL, {"text": build_text(project_name, info)})
    except Exception as e:
        log_error(repr(e))


main()
