--[[
  End_RenderSummary.lua  —  キューのレンダーがすべて終わったら、まとめを 1 回だけ表示するサンプル
  asteriscus (asteriscus.jp)

  配置先（このフォルダに置くと「スクリプト」ドロップダウンに出る）
    Windows : %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Deliver
    macOS   : ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Deliver

  設定
    まとめに入れたい「すべてのジョブ」で
      [✓] レンダー [終了] 時にスクリプト実行   スクリプト: End_RenderSummary
    を選んでからレンダーキューに追加する（スクリプトの指定はジョブごとに保存される）。

  仕組み
    終了時スクリプトはジョブごとに 1 回ずつ実行される。毎回、自分のジョブの結果を
    Fusion のアプリデータ（fu:SetData）に追記し、WAIT_SEC 秒待ってからレンダーが
    続いているかを確認する。続いていなければ「自分が最後のジョブ」とみなして、
    たまった結果をまとめて表示し、記録を消す。
    ※ 所要時間は「最初に終わったジョブ」から「最後に終わったジョブ」までの目安。
       最初のジョブの開始時刻は終了時スクリプトでは分からないため。

  Resolve が注入するグローバル変数（DaVinci Resolve 21.2 で実測）
    job / status / error  （error は Lua 標準の error() を上書きするので、このスクリプト内で error() は使えない）
]]

-- 注入変数は最初にローカルへ退避しておく
local JOB    = job    or ""
local STATUS = status or ""
local ERRMSG = error  or ""

local OS = jit and jit.os or ""         -- "Windows" / "OSX" / "Linux"

local WAIT_SEC = 3                      -- 最後のジョブか判定する前に待つ秒数
local KEY = "asteriscus.RenderSummary.lua"

-- ===== 通知音の設定 =================================================
-- まとめの結果ごとに鳴らす音を win（Windows）/ mac（macOS）に書く。false = 鳴らさない。
--   1 件でも失敗があれば RenderFailed、失敗はなくキャンセルがあれば RenderCancelled、
--   すべて完了なら RenderCompleted の音を鳴らす。
--
-- Windows (win)
--   数値   : システムの音。実際の音は「コントロールパネル > サウンド」の割り当てに従う
--             0x40 = 一般の情報  0x30 = 警告  0x10 = システム エラー  0x20 = 問い合わせ  0x00 = 一般の警告音
--   文字列 : 音声ファイルのフルパス（例: [[D:\Sounds\done.mp3]]）。.wav / .mp3 / .m4a / .wma / .flac など。
--             Windows Media Player の再生エンジンで鳴らす（PowerShell 経由）。日本語を含むパスも可
-- macOS (mac)
--   名前     : /System/Library/Sounds/ の音（"Glass" "Basso" "Ping" "Hero" "Funk" など）
--   フルパス : 音声ファイル（例: "/Users/you/Sounds/done.mp3"）。.aiff / .wav / .mp3 / .m4a など
-- 指定したファイルが見つからないときは、システムの音で代わりに鳴らす。
local SOUND = {
    RenderCompleted = { win = 0x40, mac = "Glass" },   -- 例: win = [[D:\Sounds\done.mp3]]
    RenderCancelled = { win = 0x30, mac = "Funk"  },
    RenderFailed    = { win = 0x10, mac = "Basso" },   -- 例: mac = "/Users/you/Sounds/error.wav"
}
-- ====================================================================

------------------------------------------------------------
-- 自分のジョブの結果を記録する
------------------------------------------------------------
if STATUS == "RenderStarted" then return end      -- 開始時に設定された場合は何もしない

local function sleep(sec)
    if bmd and bmd.wait then bmd.wait(sec) else local t = os.time() + sec; while os.time() < t do end end
end
local function clean(s) return (tostring(s or ""):gsub("[\t\r\n]", " ")) end

local R       = Resolve()
local project = R:GetProjectManager():GetCurrentProject()

local info = {}
for _, j in ipairs(project and project:GetRenderJobList() or {}) do
    if j.JobId == JOB then info = j; break end
end

local line = table.concat({
    JOB, STATUS, os.date("%Y-%m-%d %H:%M:%S"),
    clean(info.OutputFilename), clean(info.TargetDir), clean(info.TimelineName), clean(ERRMSG),
}, "\t")
fu:SetData(KEY, (fu:GetData(KEY) or "") .. line .. "\n")

------------------------------------------------------------
-- 最後のジョブかどうかを判定する
------------------------------------------------------------
local function rendering()
    local p = Resolve():GetProjectManager():GetCurrentProject()
    return p and p:IsRenderingInProgress()
end
local function last_job_in_log()
    local last
    for l in (fu:GetData(KEY) or ""):gmatch("[^\n]+") do last = l end
    return last and last:match("^([^\t]*)")
end

sleep(WAIT_SEC)
if rendering() then return end                    -- 次のジョブがレンダー中 → まだ途中
sleep(1)
if rendering() or last_job_in_log() ~= JOB then return end   -- 後から別のジョブが終わっていた

local log = fu:GetData(KEY) or ""
fu:SetData(KEY, nil)                              -- 記録を消す（次のレンダーに持ち越さない）

------------------------------------------------------------
-- まとめを作る
------------------------------------------------------------
local LABEL = { RenderCompleted = "完了", RenderCancelled = "キャンセル", RenderFailed = "失敗" }
local rows, count = {}, { RenderCompleted = 0, RenderCancelled = 0, RenderFailed = 0 }
for l in log:gmatch("[^\n]+") do
    local f = {}
    for v in (l .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
    rows[#rows + 1] = { job = f[1], status = f[2], time = f[3], file = f[4], dir = f[5], timeline = f[6], err = f[7] }
    if count[f[2]] then count[f[2]] = count[f[2]] + 1 end
end
if #rows == 0 then return end

local function to_sec(t)
    local y, mo, d, h, mi, s = t:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    return y and os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s }) or nil
end
local span = "--"
local t1, t2 = to_sec(rows[1].time), to_sec(rows[#rows].time)
if t1 and t2 then
    local s = t2 - t1
    span = string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
end

local overall = (count.RenderFailed > 0 and "RenderFailed")
             or (count.RenderCancelled > 0 and "RenderCancelled") or "RenderCompleted"

------------------------------------------------------------
-- 通知音
------------------------------------------------------------
local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

-- Windows: 音声ファイルは PowerShell から Windows Media Player（WMPlayer.OCX）で鳴らす。
--   関連付けアプリは使わず、画面も出さない。使えない環境（N エディション等）やファイルが
--   無いときは PowerShell 側でシステムの音に切り替える。
local PS_PLAY = [[
$ErrorActionPreference = 'Stop'
$f = '%s'
try {
    if (-not (Test-Path -LiteralPath $f)) { throw 'not found' }
    Add-Type -AssemblyName System.Windows.Forms
    $p = New-Object -ComObject WMPlayer.OCX
    $p.settings.volume = 100
    $p.URL = $f
    $p.controls.play()
    # WMP は Windows のメッセージを処理しないと進まないので DoEvents を回しながら待つ
    $t = 0
    while ($p.playState -ne 3 -and $t -lt 50) {               # 3 = 再生中（最大 5 秒待つ）
        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100; $t++
    }
    if ($p.playState -ne 3) { throw 'cannot play' }
    $t = 0
    while ((3, 6, 9) -contains $p.playState -and $t -lt 600) {  # 再生が終わるまで（最大 60 秒）
        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100; $t++
    }
    $p.close()
} catch {
    [System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Milliseconds 800
}
]]

local function play_windows(v)
    local ffi = require("ffi")
    local bit = require("bit")
    pcall(ffi.cdef, [[
        int MessageBeep(unsigned int uType);
        int MultiByteToWideChar(unsigned int cp, unsigned long flags, const char* s, int n, wchar_t* w, int wn);
        typedef struct { unsigned long cb; void* lpReserved; void* lpDesktop; void* lpTitle;
            unsigned long dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            unsigned short wShowWindow, cbReserved2; void* lpReserved2; void* hStdInput; void* hStdOutput; void* hStdError;
        } RN_STARTUPINFOW;
        typedef struct { void* hProcess; void* hThread; unsigned long dwProcessId; unsigned long dwThreadId; } RN_PROCINFO;
        int CreateProcessW(const wchar_t* app, wchar_t* cmd, void* pa, void* ta, int inherit,
            unsigned long flags, void* env, const wchar_t* cwd, RN_STARTUPINFOW* si, RN_PROCINFO* pi);
        int CloseHandle(void* h);
    ]])
    local function beep(t) pcall(function() ffi.load("user32").MessageBeep(t) end) end
    if type(v) == "number" then beep(v) return end

    local path = v

    -- UTF-8 → UTF-16（wchar_t 配列と文字数）
    local function wide(s)
        local n = ffi.C.MultiByteToWideChar(65001, 0, s, -1, nil, 0)
        local w = ffi.new("wchar_t[?]", n)
        ffi.C.MultiByteToWideChar(65001, 0, s, -1, w, n)
        return w, n - 1
    end
    -- PowerShell の -EncodedCommand 用（UTF-16LE を Base64 化）
    local function encode_command(script)
        local w, n = wide(script)
        local bytes = ffi.cast("const unsigned char*", w)
        local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local out, len = {}, n * 2
        for i = 0, len - 1, 3 do
            local b1, b2, b3 = bytes[i], (i + 1 < len) and bytes[i + 1] or 0, (i + 2 < len) and bytes[i + 2] or 0
            local x = bit.bor(bit.lshift(b1, 16), bit.lshift(b2, 8), b3)
            out[#out + 1] = A:sub(bit.rshift(x, 18) + 1, bit.rshift(x, 18) + 1)
                .. A:sub(bit.band(bit.rshift(x, 12), 63) + 1, bit.band(bit.rshift(x, 12), 63) + 1)
                .. ((i + 1 < len) and A:sub(bit.band(bit.rshift(x, 6), 63) + 1, bit.band(bit.rshift(x, 6), 63) + 1) or "=")
                .. ((i + 2 < len) and A:sub(bit.band(x, 63) + 1, bit.band(x, 63) + 1) or "=")
        end
        return table.concat(out)
    end

    local ok = pcall(function()
        local script = PS_PLAY:format(path:gsub("'", "''"))
        local cmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand "
                    .. encode_command(script)
        local wcmd = wide(cmd)
        local si = ffi.new("RN_STARTUPINFOW"); si.cb = ffi.sizeof(si)
        local pi = ffi.new("RN_PROCINFO")
        -- CREATE_NO_WINDOW (0x08000000): コンソール窓を出さない
        assert(ffi.C.CreateProcessW(nil, wcmd, nil, nil, 0, 0x08000000, nil, nil, si, pi) ~= 0)
        ffi.C.CloseHandle(pi.hThread); ffi.C.CloseHandle(pi.hProcess)
    end)
    if not ok then beep(0x40) end      -- PowerShell を起動できないときはシステムの音
end

local function play_mac(v)
    local path = v:find("/") and v or ("/System/Library/Sounds/" .. v .. ".aiff")
    if not file_exists(path) then path = "/System/Library/Sounds/Glass.aiff" end
    os.execute("afplay '" .. path:gsub("'", "'\\''") .. "' &")
end

local snd = SOUND[overall] or {}
if OS == "Windows" and snd.win then
    play_windows(snd.win)
elseif OS == "OSX" and snd.mac then
    play_mac(snd.mac)
end

------------------------------------------------------------
-- ダイアログ
------------------------------------------------------------
local ui   = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local headline = string.format("レンダーがすべて終わりました（%d 件：完了 %d / キャンセル %d / 失敗 %d）",
    #rows, count.RenderCompleted, count.RenderCancelled, count.RenderFailed)

local win = disp:AddWindow({
    ID = "RenderSummary",
    WindowTitle = "Render Summary",
    WindowFlags = { Window = true, WindowStaysOnTopHint = true },
    Geometry = { 200, 200, 760, 360 },
    ui:VGroup{
        ui:Label{ Text = "<b>" .. headline .. "</b>", Weight = 0 },
        ui:Label{ Text = "最初の完了から最後の完了まで（目安）: " .. span
                         .. "　／　プロジェクト: " .. tostring(project and project:GetName() or "--"), Weight = 0 },
        ui:Tree{ ID = "List", SortingEnabled = false, SelectionMode = "SingleSelection",
                 Events = { ItemClicked = true, ItemDoubleClicked = true } },
        ui:HGroup{
            Weight = 0,
            ui:Label{ ID = "Hint", Text = "行を選ぶ（ダブルクリックで直接開く）と、そのジョブの保存先を開けます", Weight = 1 },
            ui:Button{ ID = "OpenDir", Text = "保存先を開く" },
            ui:Button{ ID = "OK", Text = "OK" },
        },
    },
})

local itm = win:GetItems()
local hdr = itm.List:NewItem()
hdr.Text[0], hdr.Text[1], hdr.Text[2], hdr.Text[3], hdr.Text[4] = "結果", "ファイル", "タイムライン", "終了時刻", "エラー"
itm.List:SetHeaderItem(hdr)
itm.List.ColumnCount = 5
itm.List.ColumnWidth[0], itm.List.ColumnWidth[1], itm.List.ColumnWidth[2], itm.List.ColumnWidth[3] = 80, 220, 120, 80

local dirs = {}
for i, r in ipairs(rows) do
    local it = itm.List:NewItem()
    it.Text[0] = LABEL[r.status] or r.status
    it.Text[1] = r.file ~= "" and r.file or "--"
    it.Text[2] = r.timeline ~= "" and r.timeline or "--"
    it.Text[3] = r.time:sub(12)
    it.Text[4] = r.err
    itm.List:AddTopLevelItem(it)
    dirs[i] = r.dir
end

-- 行を選ぶとその保存先を下に表示し、「保存先を開く」が押せるようになる。ダブルクリックでも開く。
local selected_dir = nil
itm.OpenDir.Enabled = false
local function select_row(item)
    local idx = itm.List:IndexOfTopLevelItem(item)
    selected_dir = idx and dirs[idx + 1] or nil
    local ok = selected_dir ~= nil and selected_dir ~= ""
    itm.OpenDir.Enabled = ok
    itm.Hint.Text = ok and ("保存先: " .. selected_dir) or "このジョブの保存先は分かりません"
    return ok
end
function win.On.List.ItemClicked(ev)
    select_row(ev.item)
end
function win.On.List.ItemDoubleClicked(ev)
    if select_row(ev.item) then bmd.openfileexternal("Open", selected_dir) end
end
function win.On.OpenDir.Clicked(ev)
    if selected_dir and selected_dir ~= "" then bmd.openfileexternal("Open", selected_dir) end
end
function win.On.OK.Clicked(ev)            disp:ExitLoop() end
function win.On.RenderSummary.Close(ev)   disp:ExitLoop() end

win:Show()
disp:RunLoop()
win:Hide()
