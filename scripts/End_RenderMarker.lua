--[[
  End_RenderMarker.lua  -  無償版でも使えるレンダー終了スクリプト
  asteriscus (asteriscus.jp)

  ・ジョブが終わるたびに、結果をコンソールに表示（ワークスペース > コンソール）
  ・すべてのジョブが終わったら
      書き出したタイムラインのレンダー範囲の先頭に、結果の色でマーカーを付ける
        完了 = 緑 / 失敗 = 赤 / 中止 = 黄
      エディットページに切り替える
  ※レンダー中はマーカーを付けられないため、結果をいったん貯めておき、
    最後にまとめて付ける。
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
print("[レンダー] " .. msg)

-- 結果を貯める（タイムライン名 / 開始フレーム / 色 / 名前 / メモ）
local rec = table.concat({ info.TimelineName or "", info.MarkIn or "", color, "レンダー" .. label, msg }, "\t")
local saved = fu:GetData(KEY) or ""
fu:SetData(KEY, saved == "" and rec or (saved .. "\n" .. rec))

-- 3 秒待ってもレンダー中なら、次のジョブに任せて終わる
bmd.wait(3)
if project:IsRenderingInProgress() then return end

-- ここからは最後のジョブ：貯めた結果をマーカーにする
local function find_timeline(name)
    for i = 1, project:GetTimelineCount() do
        local tl = project:GetTimelineByIndex(i)
        if tl:GetName() == name then return tl end
    end
end

for line in (fu:GetData(KEY) or ""):gmatch("[^\n]+") do
    local name, markin, col, title, note = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
    local tl = name and find_timeline(name)
    if tl then
        local frame = (tonumber(markin) or tl:GetStartFrame()) - tl:GetStartFrame()
        for k = 0, 9 do   -- 同じ位置にマーカーがあれば 1 フレームずつずらす
            if tl:AddMarker(frame + k, col, title, note, 1, "") then break end
        end
    end
end
fu:SetData(KEY, "")
resolve:OpenPage("edit")
