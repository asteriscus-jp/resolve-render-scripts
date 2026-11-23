"""
End_Mail.py  -  レンダー結果をメールで送る（Studio 版）
asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

準備: 送信に使うメールの SMTP 情報を下に書く。
      Gmail は 2 段階認証を有効にして「アプリ パスワード」を発行し、PASSWORD に入れる。
注意: パスワードを書いたこのファイルを人に渡さないこと。
"""
import smtplib
from email.message import EmailMessage

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 465
USER = "you@gmail.com"
PASSWORD = "xxxx xxxx xxxx xxxx"
MAIL_TO = "you@gmail.com"

LABEL = {"RenderCompleted": "完了", "RenderFailed": "失敗", "RenderCancelled": "中止"}

# 今終わったジョブの情報
project = bmd.scriptapp("Resolve").GetProjectManager().GetCurrentProject()
info = next((j for j in project.GetRenderJobList() if j["JobId"] == job), {})

msg = EmailMessage()
msg["Subject"] = f"レンダー{LABEL.get(status, status)}: {info.get('OutputFilename', '?')}"
msg["From"] = USER
msg["To"] = MAIL_TO
msg.set_content(f"ファイル: {info.get('OutputFilename', '?')}\n"
                f"保存先: {info.get('TargetDir', '?')}\n"
                f"エラー: {error or 'なし'}")

with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=20) as server:
    server.login(USER, PASSWORD)
    server.send_message(msg)
