--[[
  End_RenderMarker.lua  -  無償版でも使えるレンダー終了スクリプト
  asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

  ・ジョブが終わるたびに、結果をコンソールに表示（ワークスペース > コンソール）
  ・すべてのジョブが終わったら
      書き出したタイムラインのレンダー範囲の先頭に、結果の色でマーカーを付ける
        完了 = 緑 / 失敗 = 赤 / 中止 = 黄
      エディットページに切り替える
  ※レンダー中はマーカーを付けられないため、結果をいったん貯めておき、
    キュー全体のレンダーが止まってから、まとめて付ける。
--]]

local KEY = "asteriscus.RenderMarker"
local resolve = Resolve()
local project = resolve:GetProjectManager():GetCurrentProject()

local RESULT = {
    RenderCompleted = { "完了", "Green"  },
    RenderFailed    = { "失敗", "Red"    },
    RenderCancelled = { "中止", "Yellow" },
}
local label, color = unpack(RESULT[status] or { tostring(status), "Blue" })

-- 今終わったジョブの情報
local info = {}
for _, j in ipairs(project:GetRenderJobList()) do
    if j.JobId == job then info = j break end
end

-- コンソールに表示
local msg = os.date("%H:%M:%S") .. "  " .. (info.OutputFilename or "?") .. "  " .. label
if error ~= "" then msg = msg .. "  " .. error end
msg = msg:gsub("[\t\r\n]", " ")
print("[レンダー] " .. msg)

-- 結果を貯める（ジョブID / タイムライン名 / 開始フレーム / 色 / 名前 / メモ）
local rec = table.concat({ job, info.TimelineName or "", info.MarkIn or "", color, "レンダー" .. label, msg }, "\t")
local saved = fu:GetData(KEY) or ""
fu:SetData(KEY, saved == "" and rec or (saved .. "\n" .. rec))

-- キュー全体のレンダーが止まるまで待つ（3 秒続けて止まっていれば終わりとみなす）。
-- 最後のジョブに別の種類のスクリプトが指定されていても、マーカーが付くようにするため。
local idle = 0
while idle < 3 do
    bmd.wait(1)
    idle = project:IsRenderingInProgress() and 0 or idle + 1
end

-- 最後に記録したジョブのスクリプトだけが、まとめてマーカーを付ける
local data = fu:GetData(KEY) or ""
local last
for l in data:gmatch("[^\n]+") do last = l end
if last ~= rec then return end
fu:SetData(KEY, "")

local function find_timeline(name)
    for i = 1, project:GetTimelineCount() do
        local tl = project:GetTimelineByIndex(i)
        if tl:GetName() == name then return tl end
    end
end

for line in data:gmatch("[^\n]+") do
    local _, name, markin, col, title, note = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
    local tl = name and find_timeline(name)
    if tl then
        local frame = (tonumber(markin) or tl:GetStartFrame()) - tl:GetStartFrame()
        for k = 0, 9 do   -- 同じ位置にマーカーがあれば 1 フレームずつずらす
            if tl:AddMarker(frame + k, col, title, note, 1, "") then break end
        end
    end
end
resolve:OpenPage("edit")
