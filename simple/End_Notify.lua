--[[
  End_Notify.lua  -  レンダーが終わったら、ダイアログと音で知らせる（Studio 版）
  asteriscus  https://asteriscus.jp/  X: @asteriscus_jp
--]]
local LABEL = { RenderCompleted = "完了", RenderFailed = "失敗", RenderCancelled = "中止" }
local label = LABEL[status] or tostring(status)

-- 今終わったジョブの情報
local project = Resolve():GetProjectManager():GetCurrentProject()
local info = {}
for _, j in ipairs(project:GetRenderJobList()) do
    if j.JobId == job then info = j break end
end

-- 音を鳴らす
if package.config:sub(1, 1) == "\\" then          -- Windows：システムの音
    local ffi = require("ffi")
    pcall(ffi.cdef, "int MessageBeep(unsigned int uType);")
    ffi.load("user32").MessageBeep(0x40)
else                                               -- macOS
    os.execute("afplay /System/Library/Sounds/Glass.aiff &")
end

-- ダイアログを出す
local text = "ファイル : " .. (info.OutputFilename or "?") .. "\n保存先 : " .. (info.TargetDir or "?")
if error ~= "" then text = text .. "\nエラー : " .. error end

local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)
local win = disp:AddWindow({
    ID = "Notify", WindowTitle = "レンダー" .. label,
    Geometry = { 300, 300, 520, error ~= "" and 200 or 140 },   -- エラー文があるときは高くする
    ui:VGroup{
        ui:Label{ Text = text, WordWrap = true, Weight = 1 },
        ui:HGroup{ Weight = 0, ui:HGap(0, 1), ui:Button{ ID = "OK", Text = "OK", Weight = 0, MinimumSize = { 100, 0 } } },
    },
})
function win.On.OK.Clicked(ev)     disp:ExitLoop() end
function win.On.Notify.Close(ev)   disp:ExitLoop() end
win:Show()
disp:RunLoop()
win:Hide()
