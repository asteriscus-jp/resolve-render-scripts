--[[
  End_Marker.lua  -  レンダー結果をタイムラインのマーカーで残す（無償版でも動く）
  asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

  完了 = 緑 / 失敗 = 赤 / 中止 = 黄 のマーカーを、レンダー範囲の先頭に付ける。
  レンダー中はマーカーを付けられないので、結果をいったん貯めておき、
  すべてのジョブが終わったら、まとめて付けてエディットページに切り替える。
--]]
local KEY = "asteriscus.Marker"
local COLOR = { RenderCompleted = "Green", RenderFailed = "Red", RenderCancelled = "Yellow" }
local LABEL = { RenderCompleted = "完了", RenderFailed = "失敗", RenderCancelled = "中止" }

local resolve = Resolve()
local project = resolve:GetProjectManager():GetCurrentProject()

-- 今終わったジョブの情報
local info = {}
for _, j in ipairs(project:GetRenderJobList()) do
    if j.JobId == job then info = j break end
end

-- コンソールに表示し、結果を貯める（ジョブID | タイムライン名 | 開始フレーム | 色 | 結果 | ファイル名）
local label = LABEL[status] or tostring(status)
print("[レンダー" .. label .. "] " .. (info.OutputFilename or "?") .. " " .. error)
local rec = table.concat({ job, info.TimelineName or "", info.MarkIn or 0, COLOR[status] or "Blue",
                           label, info.OutputFilename or "" }, "|")
fu:SetData(KEY, (fu:GetData(KEY) or "") .. rec .. "\n")

-- キュー全体のレンダーが止まるまで待つ（3 秒続けて止まっていれば終わりとみなす）
local idle = 0
while idle < 3 do
    bmd.wait(1)
    idle = project:IsRenderingInProgress() and 0 or idle + 1
end

-- 最後に記録したジョブのスクリプトだけが、まとめてマーカーを付ける
local data = fu:GetData(KEY) or ""
if data:sub(-#rec - 1) ~= rec .. "\n" then return end
fu:SetData(KEY, "")
for line in data:gmatch("[^\n]+") do
    local _, name, markin, color, lbl, file = line:match("^(.-)|(.-)|(.-)|(.-)|(.-)|(.*)$")
    for i = 1, project:GetTimelineCount() do
        local tl = project:GetTimelineByIndex(i)
        if tl:GetName() == name then
            local frame = tonumber(markin) - tl:GetStartFrame()
            for k = 0, 9 do   -- 同じ位置にマーカーがあれば 1 フレームずらす
                if tl:AddMarker(frame + k, color, "レンダー" .. lbl, file, 1, "") then break end
            end
        end
    end
end
resolve:OpenPage("edit")
