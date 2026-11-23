"""
End_RenderDiscord.py  —  レンダー結果を Discord に送るサンプル（終了時スクリプト）
asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

配置先: Fusion/Scripts/Deliver
設定  : デリバー > レンダー設定 > ビデオ > 詳細設定
        [✓] レンダー [終了] 時にスクリプト実行   スクリプト: End_RenderDiscord

準備  : Discord のチャンネル設定 > 連携サービス > ウェブフック で URL を作り、
        下の WEBHOOK_URL に貼る
注意  : Webhook URL を知っている人は誰でもそのチャンネルに投稿できる。
        URL を書いたこのファイルを人に渡したり、公開したりしないこと。
"""
import datetime
import json
import os
import tempfile
import urllib.request

# ===== 設定 ==========================================================
WEBHOOK_URL = "https://discord.com/api/webhooks/XXXX/XXXX"
NOTIFY_ON = {"RenderCompleted", "RenderFailed", "RenderCancelled"}   # 送る結果
TIMEOUT_SEC = 10
# ====================================================================

JOB = globals().get("job", "")
STATUS = globals().get("status", "")
ERRMSG = globals().get("error", "")

# 埋め込み（embed）の見出しと左端の色
STYLE = {
    "RenderCompleted": ("レンダー完了", 0x2ECC71),
    "RenderCancelled": ("レンダーがキャンセルされました", 0x95A5A6),
    "RenderFailed":    ("レンダー失敗", 0xE74C3C),
}


def job_info():
    R = bmd.scriptapp("Resolve")
    project = R.GetProjectManager().GetCurrentProject()
    info = next((j for j in (project.GetRenderJobList() or []) if j.get("JobId") == JOB), {})
    return project.GetName() if project else "", info


def build_payload(project_name, info):
    title, color = STYLE.get(STATUS, (STATUS, 0x7F8C8D))
    fields = [
        {"name": "ファイル", "value": info.get("OutputFilename", "?"), "inline": True},
        {"name": "タイムライン", "value": f"{info.get('TimelineName', '?')}（{project_name}）", "inline": True},
        {"name": "保存先", "value": info.get("TargetDir", "?") or "?", "inline": False},
    ]
    if ERRMSG:
        fields.append({"name": "エラー", "value": ERRMSG[:1000], "inline": False})
    return {
        "username": "DaVinci Resolve",
        "embeds": [{
            "title": title,
            "color": color,
            "fields": fields,
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }],
    }


def post_json(url, payload):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        # Discord は Python 既定の User-Agent（Python-urllib/x.x）を弾くことがあるので明示する
        headers={"Content-Type": "application/json", "User-Agent": "ResolveRenderNotify/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as res:
        return res.status


def log_error(msg):
    path = os.path.join(tempfile.gettempdir(), "ResolveRenderNotify_error.log")
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} [Discord] {msg}\n")


def main():
    if STATUS not in NOTIFY_ON:
        return
    try:
        project_name, info = job_info()
        post_json(WEBHOOK_URL, build_payload(project_name, info))
    except Exception as e:
        log_error(repr(e))


main()
