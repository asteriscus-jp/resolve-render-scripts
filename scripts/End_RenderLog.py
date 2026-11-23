"""
End_RenderLog.py  —  レンダー結果を CSV に追記するサンプル（Python 版）
asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

配置先: Fusion/Scripts/Deliver（End_RenderNotify.lua と同じ）
設定  : デリバー > レンダー設定 > ビデオ > 詳細設定
        [✓] レンダー [終了] 時にスクリプト実行   スクリプト: End_RenderLog

出力  : ドキュメント/ResolveRenderLog.csv（UTF-8 BOM 付き、Excel でそのまま開ける）

Resolve が注入するグローバル変数（DaVinci Resolve 21.2 で実測）
  job    : ジョブID
  status : "RenderStarted" / "RenderCompleted" / "RenderCancelled" / "RenderFailed"
  error  : エラーメッセージ（成功時は ""）
  bmd    : bmd モジュール
"""
import csv
import datetime
import os

JOB = globals().get("job", "")
STATUS = globals().get("status", "")
ERRMSG = globals().get("error", "")

LOG_PATH = os.path.join(os.path.expanduser("~"), "Documents", "ResolveRenderLog.csv")
FIELDS = ["日時", "結果", "プロジェクト", "タイムライン", "ファイル", "保存先",
          "形式", "コーデック", "解像度", "処理時間(秒)", "エラー", "JobId"]


R = bmd.scriptapp("Resolve")
project = R.GetProjectManager().GetCurrentProject()

info = next((j for j in (project.GetRenderJobList() or []) if j.get("JobId") == JOB), {})
st = (project.GetRenderJobStatus(JOB) if info else None) or {}

ms = st.get("TimeTakenToRenderInMs")   # 21.2 では返らないため、通常は空欄になる
row = {
    "日時": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "結果": STATUS,
    "プロジェクト": project.GetName() if project else "",
    "タイムライン": info.get("TimelineName", ""),
    "ファイル": info.get("OutputFilename", ""),
    "保存先": info.get("TargetDir", ""),
    "形式": info.get("VideoFormat", ""),
    "コーデック": info.get("VideoCodec", ""),
    "解像度": f'{info["FormatWidth"]}x{info["FormatHeight"]}' if info.get("FormatWidth") else "",
    "処理時間(秒)": round(ms / 1000, 1) if ms else "",
    "エラー": ERRMSG,
    "JobId": JOB,
}

new_file = not os.path.exists(LOG_PATH)
with open(LOG_PATH, "a", newline="", encoding="utf-8-sig" if new_file else "utf-8") as f:
    w = csv.DictWriter(f, fieldnames=FIELDS)
    if new_file:
        w.writeheader()
    w.writerow(row)
