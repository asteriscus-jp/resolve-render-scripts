--[[
  End_RenderNotify.lua  —  レンダー終了時に結果ダイアログを出すサンプル
  asteriscus  https://asteriscus.jp/  X: @asteriscus_jp

  配置先（このフォルダに置くと「スクリプト」ドロップダウンに出る）
    Windows : %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Deliver
    macOS   : ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Deliver

  設定
    デリバー > レンダー設定 > ビデオ > 詳細設定
      [✓] レンダー [終了] 時にスクリプト実行   スクリプト: End_RenderNotify

  処理時間について
    このスクリプトは処理時間を表示しない。終了時スクリプトでは処理時間を返すはずの
    TimeTakenToRenderInMs が返らず（21.2 で確認）、開始時スクリプトで計る方法では
    エラー内容（下の error）が受け取れないため。処理時間が必要なら開始時スクリプトで計る（別記事で紹介予定）。

  通知音の変え方
    下の「通知音の設定」で、結果ごとに鳴らす音を指定する。システムの音のほか、
    好きな音声ファイルもフルパスで指定できる。

  Resolve が注入するグローバル変数（DaVinci Resolve 21.2 で実測）
    job    : ジョブID (string)
    status : "RenderStarted" / "RenderCompleted" / "RenderCancelled" / "RenderFailed"
    error  : エラーメッセージ (string)。成功時は ""。失敗時は UI 言語のメッセージ
             ※ Lua 標準の error() 関数を上書きするので、このスクリプト内で error() は使えない
]]

-- 注入変数は最初にローカルへ退避しておく
local JOB    = job    or ""
local STATUS = status or ""
local ERRMSG = error  or ""

local OS = jit and jit.os or ""         -- "Windows" / "OSX" / "Linux"

-- ===== 通知音の設定 =================================================
-- 結果ごとに鳴らす音を win（Windows）/ mac（macOS）に書く。false = 鳴らさない。
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
-- ジョブ情報の取得
--   スクリプトはジョブごとに 1 回実行される。GetRenderJobList() はキュー全体を
--   返すので、「今終わったジョブ」は job（JobId）と一致するものを探す。
--   （jobs[#jobs] はキューの最後のジョブであって、今終わったジョブとは限らない）
------------------------------------------------------------
local R       = Resolve()
local project = R:GetProjectManager():GetCurrentProject()

local info = nil
for _, j in ipairs(project and project:GetRenderJobList() or {}) do
    if j.JobId == JOB then info = j; break end
end

------------------------------------------------------------
-- 表示用テキスト
------------------------------------------------------------
local TITLE = {
    RenderCompleted = "レンダーが完了しました",
    RenderCancelled = "レンダーがキャンセルされました",
    RenderFailed    = "レンダーに失敗しました",
}

local target_dir = info and info.TargetDir or ""
local rows = {
    { "タイムライン", info and tostring(info.TimelineName or "--") or "--" },
    { "ファイル",     info and tostring(info.OutputFilename or "--") or "--" },
    { "保存先",       target_dir ~= "" and target_dir or "--" },
    { "形式",         info and string.format("%s / %s", tostring(info.VideoFormat or "--"), tostring(info.VideoCodec or "--")) or "--" },
    { "解像度",       info and info.FormatWidth and string.format("%d x %d", info.FormatWidth, info.FormatHeight) or "--" },
    { "ジョブID",     JOB },
}
if ERRMSG ~= "" then rows[#rows + 1] = { "エラー", ERRMSG } end

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

local snd = SOUND[STATUS] or {}
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

local body = {}
for _, r in ipairs(rows) do
    body[#body + 1] = ui:HGroup{
        Weight = 0,
        ui:Label{ Text = r[1], Weight = 0, MinimumSize = { 90, 0 } },
        ui:Label{ Text = r[2], Weight = 1, WordWrap = true,
                  TextInteractionFlags = { TextSelectableByMouse = true } },
    }
end

local win = disp:AddWindow({
    ID = "RenderNotify",
    WindowTitle = "Render Notify",
    WindowFlags = { Window = true, WindowStaysOnTopHint = true },
    Geometry = { 200, 200, 560, 0 },
    ui:VGroup{
        ui:Label{ Text = "<b>" .. (TITLE[STATUS] or STATUS) .. "</b>", Weight = 0 },
        ui:VGroup(body),
        ui:HGroup{
            Weight = 0,
            ui:HGap(0, 1),
            ui:Button{ ID = "OpenDir", Text = "保存先を開く", Enabled = target_dir ~= "" },
            ui:Button{ ID = "OK", Text = "OK" },
        },
    },
})

function win.On.OpenDir.Clicked(ev)
    bmd.openfileexternal("Open", target_dir)
end
function win.On.OK.Clicked(ev)           disp:ExitLoop() end
function win.On.RenderNotify.Close(ev)   disp:ExitLoop() end

win:Show()
disp:RunLoop()
win:Hide()
