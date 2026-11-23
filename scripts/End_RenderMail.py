"""
End_RenderMail.py  —  レンダー結果をメールで送るサンプル（終了時スクリプト）
asteriscus (asteriscus.jp)

配置先: Fusion/Scripts/Deliver
設定  : デリバー > レンダー設定 > ビデオ > 詳細設定
        [✓] レンダー [終了] 時にスクリプト実行   スクリプト: End_RenderMail

準備  : 送信に使うメールアカウントの SMTP 情報を下に書く。
        Gmail の場合は 2 段階認証を有効にし、「アプリ パスワード」を発行して
        SMTP_PASSWORD に入れる（通常のログインパスワードは使えない）。
注意  : パスワードを書いたこのファイルを人に渡したり、公開したりしないこと。
"""
import datetime
import os
import tempfile
import smtplib
import ssl
from email.message import EmailMessage

# ===== 設定 ==========================================================
SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 465                 # 465 = SSL / 587 = STARTTLS / 25 = 暗号化なし
SMTP_SECURITY = "ssl"           # "ssl" / "starttls" / "none"
SMTP_USER = "you@gmail.com"
SMTP_PASSWORD = "xxxx xxxx xxxx xxxx"
MAIL_FROM = "you@gmail.com"
MAIL_TO = ["you@gmail.com"]     # 複数可
NOTIFY_ON = {"RenderCompleted", "RenderFailed", "RenderCancelled"}   # 送る結果
TIMEOUT_SEC = 20
# ====================================================================

JOB = globals().get("job", "")
STATUS = globals().get("status", "")
ERRMSG = globals().get("error", "")

LABEL = {
    "RenderCompleted": "完了",
    "RenderCancelled": "キャンセル",
    "RenderFailed":    "失敗",
}


def job_info():
    R = bmd.scriptapp("Resolve")
    project = R.GetProjectManager().GetCurrentProject()
    info = next((j for j in (project.GetRenderJobList() or []) if j.get("JobId") == JOB), {})
    return project.GetName() if project else "", info


def build_message(project_name, info):
    msg = EmailMessage()
    msg["Subject"] = f"[Resolve] レンダー{LABEL.get(STATUS, STATUS)}: {info.get('OutputFilename', '?')}"
    msg["From"] = MAIL_FROM
    msg["To"] = ", ".join(MAIL_TO)
    body = [
        f"結果      : {LABEL.get(STATUS, STATUS)}（{STATUS}）",
        f"ファイル  : {info.get('OutputFilename', '?')}",
        f"保存先    : {info.get('TargetDir', '?')}",
        f"タイムライン: {info.get('TimelineName', '?')}",
        f"プロジェクト: {project_name}",
        f"形式      : {info.get('VideoFormat', '?')} / {info.get('VideoCodec', '?')}",
        f"時刻      : {datetime.datetime.now():%Y-%m-%d %H:%M:%S}",
        f"JobId     : {JOB}",
    ]
    if ERRMSG:
        body.append(f"エラー    : {ERRMSG}")
    msg.set_content("\n".join(body))       # UTF-8 で送られる
    return msg


def send(msg):
    if SMTP_SECURITY == "ssl":
        server = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=TIMEOUT_SEC,
                                  context=ssl.create_default_context())
    else:
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=TIMEOUT_SEC)
        if SMTP_SECURITY == "starttls":
            server.starttls(context=ssl.create_default_context())
    with server:
        if SMTP_USER:
            server.login(SMTP_USER, SMTP_PASSWORD)
        server.send_message(msg)


def log_error(text):
    path = os.path.join(tempfile.gettempdir(), "ResolveRenderNotify_error.log")
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} [Mail] {text}\n")


def main():
    if STATUS not in NOTIFY_ON:
        return
    try:
        project_name, info = job_info()
        send(build_message(project_name, info))
    except Exception as e:
        log_error(repr(e))


main()
