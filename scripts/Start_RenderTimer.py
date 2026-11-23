"""
Start_RenderTimer.py  —  開始時スクリプトでレンダーの処理時間を計るサンプル（Python 版）
asteriscus (asteriscus.jp)

配置先: Fusion/Scripts/Deliver
設定  : デリバー > レンダー設定 > ビデオ > 詳細設定
        [✓] レンダー [開始] 時にスクリプト実行   スクリプト: Start_RenderTimer

出力  : ドキュメント/ResolveRenderTimes.csv（UTF-8 BOM 付き）

仕組み
  開始時スクリプトはレンダーと並行して動く（レンダーを止めない）。
  そこで開始時刻を控えたまま、ジョブの状態を 1 秒ごとに見張り、
  終わったら「開始・終了・処理時間・結果」を 1 行書き出す。
  21.2 では GetRenderJobStatus() が TimeTakenToRenderInMs を返さないため、その代わりになる。
"""
import csv
import datetime
import os
import time

JOB = globals().get("job", "")
STATUS = globals().get("status", "")

LOG_PATH = os.path.join(os.path.expanduser("~"), "Documents", "ResolveRenderTimes.csv")
FIELDS = ["開始", "終了", "処理時間(秒)", "結果", "タイムライン", "ファイル", "保存先", "JobId"]
POLL_SEC = 1.0
TIMEOUT_SEC = 24 * 3600


def is_finished(job_status):
    # "Complete" / "Failed" / "Cancelled" / "Background Render Cancelled" など
    return job_status in ("Complete", "Failed") or "Cancelled" in job_status


def main():
    if STATUS != "RenderStarted":          # 終了時に設定された場合は何もしない
        return

    t0 = time.time()
    started = datetime.datetime.now()

    R = bmd.scriptapp("Resolve")
    project = R.GetProjectManager().GetCurrentProject()
    info = next((j for j in (project.GetRenderJobList() or []) if j.get("JobId") == JOB), {})

    result = "Timeout"
    while time.time() - t0 < TIMEOUT_SEC:
        time.sleep(POLL_SEC)
        js = (project.GetRenderJobStatus(JOB) or {}).get("JobStatus", "")
        if not js:                         # 途中でジョブが削除された
            result = "JobRemoved"
            break
        if is_finished(js):
            result = js
            break

    row = {
        "開始": started.strftime("%Y-%m-%d %H:%M:%S"),
        "終了": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "処理時間(秒)": round(time.time() - t0, 1),
        "結果": result,
        "タイムライン": info.get("TimelineName", ""),
        "ファイル": info.get("OutputFilename", ""),
        "保存先": info.get("TargetDir", ""),
        "JobId": JOB,
    }

    new_file = not os.path.exists(LOG_PATH)
    with open(LOG_PATH, "a", newline="", encoding="utf-8-sig" if new_file else "utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        if new_file:
            w.writeheader()
        w.writerow(row)


main()
