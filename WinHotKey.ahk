; ============================================================================
;  WinHotKey-AHK
;  用 AutoHotkey v2 实现 WinHotKey(https://directedge.us/content/winhotkey/) 类工具
;  —— 配置文件驱动 + 系统托盘菜单, 支持多种动作：
;        run     启动程序(可带参数)
;        open    用默认程序打开文档 / URL
;        folder  在资源管理器中打开文件夹
;        type    向当前/指定窗口输入文本
;        window  窗口控制(最小化/最大化/还原/关闭/置顶/激活/隐藏/显示)
;        app     启动/唤起/最小化切换应用(未运行启动/最小化还原/遮挡置前/前台则最小化)
;        overview 弹出“快捷键总览”画布(居中略偏下, 列出全部已设快捷键)
;
;  运行：本机安装 AutoHotkey v2 后双击本文件;
;        或双击 build.bat 编译成 WinHotKey.exe 免安装运行。
;  配置：同目录 hotkeys.ini(首次运行会自动生成模板), 修改后
;        在托盘图标右键菜单点“重载配置”即生效, 无需重启/重新编译。
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

#include lib\Bubble.ahk
#include lib\Config.ahk
#include lib\Actions.ahk
#include lib\HotkeyManager.ahk

; ---------------------------------------------------------------------------
; 全局运行状态 (顶层赋值即全局变量)
; ---------------------------------------------------------------------------
CONFIG_PATH := ResolveConfigPath()          ; 配置 ini 的完整路径
CFG := { records: [], warnings: [] }        ; 最近一次加载结果
SUSPENDED := false                          ; 是否处于"暂停热键"状态
A_IconTip := 'WinHotKey-AHK — 自定义全局快捷键'

; ---------------------------------------------------------------------------
; 内置默认配置模板(仅在目标机器上第一次运行、配置文件不存在时写出)
; ---------------------------------------------------------------------------
DEFAULT_CONFIG := "
(
; ============================================================
;  WinHotKey-AHK 默认配置模板 (首次运行自动生成)
;  每个 [小节] 定义一条快捷键; 支持整行注释(; 或 # 开头)。
;  修改保存后: 托盘图标右键 -> “重载配置”, 立即生效。
;  字段/语法详细说明见同目录 README.md。
; ============================================================

[示例-启动记事本]
hotkey = Win+Ctrl+B
action = run
target = notepad.exe
desc = 启动记事本

[示例-打开网址]
hotkey = Win+Ctrl+D
action = open
target = https://www.autohotkey.com
desc = 用默认浏览器打开网址

[示例-打开文件夹]
hotkey = Win+Ctrl+E
action = folder
target = C:\Users\Public
desc = 打开文件夹

[示例-输入文本]
hotkey = Win+Ctrl+U
action = type
target = WinHotKey-AHK by AutoHotkey v2
desc = 输入一段示例文本

[示例-记事本窗口置顶]
hotkey = Win+Ctrl+T
action = window
target = topmost
title = ahk_exe notepad.exe
desc = 切换记事本窗口置顶

[示例-最小化当前窗口]
hotkey = Win+Ctrl+M
action = window
target = minimize
desc = 最小化当前活动窗口

[示例-启动并唤起 Chrome]
hotkey = Alt+C
action = app
target = chrome.exe
title = ahk_exe chrome.exe
desc = 启动 / 唤起 Chrome

[示例-快捷键总览]
; overview = 弹出“快捷键总览”画布(居中略偏下)。
; 注意: Alt+? 实际是 Alt+Shift+/ (问号在 / 键上); 非英文键盘建议换 Win+Ctrl+H。
hotkey = Alt+?
action = overview
desc = 弹出已设置快捷键列表
)"

; ---------------------------------------------------------------------------
; auto-execute
; ---------------------------------------------------------------------------
if !FileExist(CONFIG_PATH) {
    try {
        FileAppend(DEFAULT_CONFIG, CONFIG_PATH, 'UTF-8')
        ShowBubble('配置文件不存在, 已生成默认模板:`n' CONFIG_PATH, 'WinHotKey-AHK')
    } catch as e {
        MsgBox('无法创建配置文件:`n' CONFIG_PATH '`n`n' e.Message, 'WinHotKey-AHK', 16)
        ExitApp()
    }
}

ReloadConfig()      ; 首次加载 + 注册热键 + 构建托盘菜单
Persistent()        ; 本脚本全部热键为运行时动态注册, 须显式保持常驻

; ===========================================================================
; 函数区
; ===========================================================================

; ---------------------------------------------------------------------------
; 配置路径：命令行参数(第一个) 优先; 否则取脚本/exe 同目录 hotkeys.ini
;   用法示例:  WinHotKey.exe "D:\my\keys.ini"      (指定配置文件)
;             WinHotKey.exe "D:\my\configs"        (指定目录 -> 目录下 hotkeys.ini)
; ---------------------------------------------------------------------------
ResolveConfigPath() {
    if A_Args.Length > 0 {
        p := StripOuterQuotes(A_Args[1])
        if DirExist(p)
            return RTrim(p, '\') . '\hotkeys.ini'
        if p != ''
            return p
    }
    return A_ScriptDir . '\hotkeys.ini'
}

StripOuterQuotes(p) {
    if StrLen(p) >= 2 and SubStr(p, 1, 1) = '"' and SubStr(p, -1) = '"'
        return SubStr(p, 2, -1)                 ; v2 允许负数长度
    return p
}

; ---------------------------------------------------------------------------
; (重新)加载配置：注销旧热键 -> 解析 -> 注册新热键 -> 重建托盘菜单
; ---------------------------------------------------------------------------
ReloadConfig() {
    global CFG, CONFIG_PATH, SUSPENDED
    HotkeyManager.Clear()
    CFG := LoadConfig(CONFIG_PATH)

    if CFG.warnings.Length > 0 {
        msg := '配置文件有 ' CFG.warnings.Length ' 条问题, 对应条目已被忽略:`n`n'
        shown := 0
        for w in CFG.warnings {
            shown += 1
            if shown <= 10
                msg .= '- ' w '`n'
        }
        if CFG.warnings.Length > 10
            msg .= '- ... 其余 ' (CFG.warnings.Length - 10) ' 条从略`n'
        msg .= '`n文件: ' CONFIG_PATH
        MsgBox(msg, 'WinHotKey-AHK 配置警告', 48)
    }

    HotkeyManager.RegisterAll(CFG.records)
    BuildMenu()
    UpdateActionNotifyCheck()
    tip := '已加载 ' CFG.records.Length ' 个热键'
    if SUSPENDED
        tip .= ' (热键当前处于暂停状态)'
    ShowBubble(tip, 'WinHotKey-AHK')
}

; ---------------------------------------------------------------------------
; 重建托盘菜单 (每次加载后调用; 点击条目 = 手动触发一次该动作)
; ---------------------------------------------------------------------------
BuildMenu() {
    global CFG
    tm := A_TrayMenu
    tm.Delete()

    if CFG.records.Length = 0 {
        tm.Add('(暂无已配置的热键, 请编辑配置文件后点“重载配置”)', (*) => '')
        tm.Disable('1&')                    ; 按位置禁用第 1 项
    } else {
        for rec in CFG.records {
            name := rec.desc != '' ? rec.desc : rec.section
            label := EscapeMenu(name) . '   [' . rec.hotkey . ']'
            tm.Add(label, MakeMenuHandler(rec))
        }
    }

    tm.Add()                                    ; 分隔线
    ; 注意: 菜单回调会被传入 3 个参数, 回调必须声明 * (变参),
    ; 因此这里统一用 (*) => 包装, 不能直接传裸函数引用。
    tm.Add('打开配置文件', (*) => OpenConfigFile())
    tm.Add('重载配置', (*) => ReloadConfig())
    tm.Add('快捷键总览', (*) => ShowOverview())
    tm.Add('暂停 / 恢复热键', (*) => ToggleSuspend())
    tm.Add('动作气泡提示', (*) => ToggleActionNotify())
    tm.Add('关于 WinHotKey-AHK', (*) => ShowAbout())
    tm.Add()
    tm.Add('退出', (*) => ExitApp())
    tm.Default := '打开配置文件'                ; 双击托盘图标 = 打开配置文件
}

; 同步“动作气泡提示”开关的勾选状态(在 BuildMenu 重建后反映当前值)
UpdateActionNotifyCheck() {
    global ACTION_NOTIFY
    item := '动作气泡提示'
    if ACTION_NOTIFY
        A_TrayMenu.Check(item)
    else
        A_TrayMenu.Uncheck(item)
}

; 切换动作成功后托盘气泡提示的开关
ToggleActionNotify() {
    global ACTION_NOTIFY
    ACTION_NOTIFY := !ACTION_NOTIFY
    UpdateActionNotifyCheck()
    ShowBubble(ACTION_NOTIFY ? '动作气泡提示: 已开启' : '动作气泡提示: 已关闭', 'WinHotKey-AHK')
}

EscapeMenu(s) {
    return StrReplace(s, '&', '&&')
}

; ---------------------------------------------------------------------------
; 暂停 / 恢复全部热键 (不退出程序)
; ---------------------------------------------------------------------------
ToggleSuspend() {
    global SUSPENDED
    SUSPENDED := !SUSPENDED
    Suspend(SUSPENDED)                          ; v2: Suspend(true/false)
    item := '暂停 / 恢复热键'
    if SUSPENDED
        A_TrayMenu.Check(item)
    else
        A_TrayMenu.Uncheck(item)
    ShowBubble(SUSPENDED ? '所有热键已暂停' : '所有热键已恢复', 'WinHotKey-AHK')
}

; ---------------------------------------------------------------------------
; 用记事本打开配置文件(便于编辑)
; ---------------------------------------------------------------------------
OpenConfigFile() {
    global CONFIG_PATH
    if FileExist(CONFIG_PATH) {
        Run('notepad.exe "' . CONFIG_PATH . '"')
        return
    }
    MsgBox('配置文件不存在: ' CONFIG_PATH, 'WinHotKey-AHK', 16)
}

; ---------------------------------------------------------------------------
; 关于对话框
; ---------------------------------------------------------------------------
ShowAbout() {
    global CFG, CONFIG_PATH
    body := (
        'WinHotKey-AHK  v1.0.0`n'
        . '用 AutoHotkey v2 实现的 WinHotKey 类全局快捷键工具。`n`n'
        . '当前已注册热键: ' CFG.records.Length ' 个`n'
        . '配置文件: ' CONFIG_PATH '`n`n'
        . '支持的动作:`n'
        . '  run    启动程序`n'
        . '  open   用默认程序打开文档 / URL`n'
        . '  folder 打开文件夹`n'
        . '  type   输入文本`n'
        . '  window 窗口控制(最小化/最大化/还原/关闭/置顶/激活/隐藏/显示)`n'
        . '  app    启动/唤起/最小化切换应用(未运行启动/最小化还原/遮挡置前/前台最小化)`n'
        . '  overview 快捷键总览(居中画布列出全部快捷键)'
    )
    MsgBox(body, '关于 WinHotKey-AHK', 64)
}
