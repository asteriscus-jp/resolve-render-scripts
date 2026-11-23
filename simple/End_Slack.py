"""
End_Slack.py  -  レンダー結果を Slack に送る（Studio 版）
asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

準備: Slack で Incoming Webhook を作り、URL を下の WEBHOOK_URL に貼る。
注意: URL を知っている人は誰でも投稿できるので、このファイルを人に渡さないこと。
"""
import json
import urllib.request

WEBHOOK_URL = "https://hooks.slack.com/services/XXXX/XXXX/XXXX"

LABEL = {"RenderCompleted": "完了", "RenderFailed": "失敗", "RenderCancelled": "中止"}

# 今終わったジョブの情報
project = bmd.scriptapp("Resolve").GetProjectManager().GetCurrentProject()
info = next((j for j in project.GetRenderJobList() if j["JobId"] == job), {})

text = f"レンダー{LABEL.get(status, status)}: {info.get('OutputFilename', '?')}"
if error:
    text += f"\nエラー: {error}"

req = urllib.request.Request(
    WEBHOOK_URL,
    data=json.dumps({"text": text}).encode("utf-8"),
    headers={"Content-Type": "application/json"},
)
urllib.request.urlopen(req, timeout=10)
