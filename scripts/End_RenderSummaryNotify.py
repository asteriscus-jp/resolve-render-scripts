"""
End_RenderSummaryNotify.py  —  キューのレンダーがすべて終わったら、まとめを 1 通だけ送るサンプル（終了時スクリプト）
asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

配置先: Fusion/Scripts/Deliver
設定  : まとめに入れたい「すべてのジョブ」で
        [✓] レンダー [終了] 時にスクリプト実行   スクリプト: End_RenderSummaryNotify
        を選んでからレンダーキューに追加する（スクリプトの指定はジョブごとに保存される）。

送り先: 下の SERVICE で "slack" / "discord" / "mail" を選び、それぞれの設定を書く。
名前  : ダイアログ版 End_RenderSummary.lua と同じ名前にすると一覧で 1 つにまとまってしまうため別名にしている。
注意  : Webhook URL やパスワードを書いたこのファイルを人に渡したり、公開したりしないこと。

仕組み: 終了時スクリプトはジョブごとに 1 回ずつ実行される。毎回、自分のジョブの結果を
        Fusion のアプリデータ（fusion.SetData）に追記し、WAIT_SEC 秒待ってからレンダーが
        続いているかを確認する。続いていなければ「自分が最後のジョブ」とみなして、
        たまった結果をまとめて送り、記録を消す。
        所要時間は「最初に終わったジョブ」から「最後に終わったジョブ」までの目安。
"""
import datetime
import json
import os
import smtplib
import ssl
import tempfile
import time
import urllib.request
from email.message import EmailMessage

# ===== 設定 ==========================================================
SERVICE = "slack"                      # "slack" / "discord" / "mail"

SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/XXXX/XXXX/XXXX"
DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/XXXX/XXXX"

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 465                        # 465 = SSL / 587 = STARTTLS / 25 = 暗号化なし
SMTP_SECURITY = "ssl"                  # "ssl" / "starttls" / "none"
SMTP_USER = "you@gmail.com"
SMTP_PASSWORD = "xxxx xxxx xxxx xxxx"  # Gmail はアプリ パスワード
MAIL_FROM = "you@gmail.com"
MAIL_TO = ["you@gmail.com"]            # 複数可

WAIT_SEC = 3                           # 最後のジョブか判定する前に待つ秒数
TIMEOUT_SEC = 20
# ====================================================================

JOB = globals().get("job", "")
STATUS = globals().get("status", "")
ERRMSG = globals().get("error", "")

KEY = "asteriscus.RenderSummaryNotify"
LABEL = {"RenderCompleted": "完了", "RenderCancelled": "キャンセル", "RenderFailed": "失敗"}

R = bmd.scriptapp("Resolve")                            # noqa: F821
FU = globals().get("fusion") or bmd.scriptapp("Fusion")  # noqa: F821


def current_project():
    return R.GetProjectManager().GetCurrentProject()


def record_my_job():
    project = current_project()
    info = next((j for j in (project.GetRenderJobList() or []) if j.get("JobId") == JOB), {})
    rec = {
        "job": JOB, "status": STATUS, "time": f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}",
        "file": info.get("OutputFilename", ""), "dir": info.get("TargetDir", ""),
        "timeline": info.get("TimelineName", ""), "error": ERRMSG,
    }
    FU.SetData(KEY, (FU.GetData(KEY) or "") + json.dumps(rec, ensure_ascii=False) + "\n")


def load_records():
    return [json.loads(l) for l in (FU.GetData(KEY) or "").splitlines() if l.strip()]


def is_last_job():
    time.sleep(WAIT_SEC)
    if current_project().IsRenderingInProgress():
        return False                                    # 次のジョブがレンダー中 → まだ途中
    time.sleep(1)
    recs = load_records()
    # 後から別のジョブが終わっていたら、そちらに任せる
    return not current_project().IsRenderingInProgress() and recs and recs[-1]["job"] == JOB


def summarize(recs):
    count = {k: sum(1 for r in recs if r["status"] == k) for k in LABEL}
    t1 = datetime.datetime.strptime(recs[0]["time"], "%Y-%m-%d %H:%M:%S")
    t2 = datetime.datetime.strptime(recs[-1]["time"], "%Y-%m-%d %H:%M:%S")
    overall = ("RenderFailed" if count["RenderFailed"] else
               "RenderCancelled" if count["RenderCancelled"] else "RenderCompleted")
    title = (f"レンダーがすべて終わりました（{len(recs)} 件：完了 {count['RenderCompleted']} / "
             f"キャンセル {count['RenderCancelled']} / 失敗 {count['RenderFailed']}）")
    project = current_project()
    meta = f"プロジェクト: {project.GetName() if project else '?'}　所要時間（目安）: {t2 - t1}"
    return overall, title, meta


def send_slack(recs, overall, title, meta):
    icon = {"RenderCompleted": ":white_check_mark:", "RenderCancelled": ":double_vertical_bar:",
            "RenderFailed": ":x:"}
    lines = [f"{icon[overall]} *{title}*", meta]
    for r in recs:
        line = f"{icon.get(r['status'], '')} {LABEL.get(r['status'], r['status'])}  `{r['file'] or '?'}`（{r['timeline']}）"
        if r["error"]:
            line += f"\n　　エラー: {r['error']}"
        lines.append(line)
    post_json(SLACK_WEBHOOK_URL, {"text": "\n".join(lines)})


def send_discord(recs, overall, title, meta):
    color = {"RenderCompleted": 0x2ECC71, "RenderCancelled": 0x95A5A6, "RenderFailed": 0xE74C3C}[overall]
    rows = []
    for r in recs:
        row = f"**{LABEL.get(r['status'], r['status'])}**　{r['file'] or '?'}（{r['timeline']}）"
        if r["error"]:
            row += f"\nエラー: {r['error']}"
        rows.append(row)
    desc = meta + "\n\n" + "\n".join(rows)
    post_json(DISCORD_WEBHOOK_URL, {
        "username": "DaVinci Resolve",
        "embeds": [{"title": title, "color": color, "description": desc[:4000],
                    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat()}],
    })


def send_mail(recs, overall, title, meta):
    msg = EmailMessage()
    msg["Subject"] = f"[Resolve] {title}"
    msg["From"] = MAIL_FROM
    msg["To"] = ", ".join(MAIL_TO)
    body = [title, meta, ""]
    for r in recs:
        body.append(f"{LABEL.get(r['status'], r['status']):<6} {r['time'][11:]}  {r['file'] or '?'}（{r['timeline']}）")
        body.append(f"        保存先: {r['dir']}")
        if r["error"]:
            body.append(f"        エラー: {r['error']}")
    msg.set_content("\n".join(body))
    if SMTP_SECURITY == "ssl":
        server = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=TIMEOUT_SEC, context=ssl.create_default_context())
    else:
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=TIMEOUT_SEC)
        if SMTP_SECURITY == "starttls":
            server.starttls(context=ssl.create_default_context())
    with server:
        if SMTP_USER:
            server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)


def post_json(url, payload):
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"), method="POST",
        headers={"Content-Type": "application/json", "User-Agent": "ResolveRenderNotify/1.0"},
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as res:
        return res.status


def log_error(msg):
    path = os.path.join(tempfile.gettempdir(), "ResolveRenderNotify_error.log")
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} [Summary] {msg}\n")


def main():
    if STATUS == "RenderStarted":
        return                                          # 開始時に設定された場合は何もしない
    try:
        record_my_job()
        if not is_last_job():
            return
        recs = load_records()
        FU.SetData(KEY, None)                           # 記録を消す（次のレンダーに持ち越さない）
        if not recs:
            return
        overall, title, meta = summarize(recs)
        {"slack": send_slack, "discord": send_discord, "mail": send_mail}[SERVICE](recs, overall, title, meta)
    except Exception as e:
        log_error(repr(e))


main()
