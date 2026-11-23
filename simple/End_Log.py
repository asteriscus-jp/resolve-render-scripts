"""
End_Log.py  -  レンダー結果を CSV ファイルに 1 行ずつ追記する（Studio 版）
asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

保存先: ドキュメント/ResolveRenderLog.csv（Excel でそのまま開ける）
"""
import csv
import datetime
import os

LOG_PATH = os.path.join(os.path.expanduser("~"), "Documents", "ResolveRenderLog.csv")

# 今終わったジョブの情報
project = bmd.scriptapp("Resolve").GetProjectManager().GetCurrentProject()
info = next((j for j in project.GetRenderJobList() if j["JobId"] == job), {})

row = [
    datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    status,
    info.get("TimelineName", ""),
    info.get("OutputFilename", ""),
    error,
]

# 初回だけ見出し行を書く
new_file = not os.path.exists(LOG_PATH)
with open(LOG_PATH, "a", newline="", encoding="utf-8-sig" if new_file else "utf-8") as f:
    writer = csv.writer(f)
    if new_file:
        writer.writerow(["日時", "結果", "タイムライン", "ファイル", "エラー"])
    writer.writerow(row)
