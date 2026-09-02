; ============================================================================
;  WinHotKey-AHK — lib/Actions.ahk
;  各动作的执行器 + 通知辅助
;     run   启动程序(可带参数)
;     open  用默认程序打开文档/URL
;     folder  在资源管理器中打开文件夹
;     type  向当前/指定窗口输入文本
;     window 窗口操作: minimize|maximize|restore|close|topmost|activate|hide|show
;     app   启动/唤起/最小化切换某应用(未运行启动; 最小化还原; 遮挡置前; 已在前台则最小化)
;     overview 弹出“快捷键总览”画布(居中略偏下, 列出已设置的快捷键)
; ============================================================================

__Overview := 0                     ; “快捷键总览”画布窗口(Gui), 0 = 未显示
OVERVIEW_Y_RATIO := 0.56            ; 画布垂直位置: 0.5=正中, >0.5 略偏下

; ---------------------------------------------------------------------------
; 统一入口：执行一条动作记录
; ---------------------------------------------------------------------------
ExecuteAction(rec) {
    switch StrLower(rec.action) {
        case 'run', 'open', 'folder':
            return RunTarget(rec)
        case 'type':
            return TypeText(rec)
        case 'window':
            return WindowOp(rec)
        case 'app':
            return RaiseApp(rec)
        case 'overview', 'list', 'help':
            return ShowOverview()
        default:
            Notify('未知动作类型: ' rec.action, 'WinHotKey-AHK', 3)
            return false
    }
}

; ---------------------------------------------------------------------------
; run / open / folder：本质都是 Run(), 区别在传参方式与提示语
; ---------------------------------------------------------------------------
RunTarget(rec) {
    target := rec.target
    if target = '' {
        Notify('动作 ' rec.action ' 缺少 target', 'WinHotKey-AHK', 3)
        return false
    }

    switch StrLower(rec.action) {
        case 'folder':
            cmd := QuotePath(target)          ; 文件夹整串加引号, 交给 ShellExecute
        case 'open':
            cmd := (LooksLikeUrl(target) or StartsWithQuote(target)) ? target : QuotePath(target)
        default:                              ; run —— 原样传递, 由用户自行加引号
            cmd := target
    }

    try {
        Run(cmd)
    } catch as e {
        Notify('[' rec.section '] 运行失败: ' target '`n' e.Message, 'WinHotKey-AHK', 3)
        return false
    }
    Notify('已执行: ' target, '[' rec.section ']')
    return true
}

; ---------------------------------------------------------------------------
; type：把文本发送到当前活动窗口, 或先激活 title 指定的窗口再发送。
; 用 SendText 逐字符投递, 现代 Windows 全部可用(不依赖已被移除的 SendKeys)。
; ---------------------------------------------------------------------------
TypeText(rec) {
    text := rec.target
    if rec.title != '' {
        if !WinExist(rec.title) {
            Notify('未找到目标窗口: ' rec.title, '[' rec.section ']', 3)
            return false
        }
        WinActivate(rec.title)
        if !WinWaitActive(rec.title, '', 3) {
            Notify('无法激活目标窗口: ' rec.title, '[' rec.section ']', 3)
            return false
        }
        Sleep(120)
    }
    SendText(text)
    Notify('已输入文本(' StrLen(text) ' 字符)', '[' rec.section ']')
    return true
}

; ---------------------------------------------------------------------------
; window：对"活动窗口"或 title 指定的窗口做窗口操作
; ---------------------------------------------------------------------------
WindowOp(rec) {
    op := StrLower(Trim(rec.target))

    if rec.title != '' {
        hwnd := WinExist(rec.title)
        if !hwnd {
            Notify('未找到窗口: ' rec.title, '[' rec.section ']', 3)
            return false
        }
    } else {
        hwnd := WinExist('A')                 ; 当前活动窗口
        if !hwnd {
            Notify('未找到活动窗口', '[' rec.section ']', 3)
            return false
        }
    }
    h := Format('ahk_id 0x{:X}', hwnd)

    switch op {
        case 'minimize':
            WinMinimize(h)
        case 'maximize', 'max':
            WinMaximize(h)
        case 'restore':
            WinRestore(h)
        case 'close':
            WinClose(h)
        case 'topmost', 'alwaysontop', 'ontop':
            on := (WinGetExStyle(h) & 0x8) != 0    ; 当前是否已置顶(WS_EX_TOPMOST)
            WinSetAlwaysOnTop(on ? 0 : 1, h)       ; 取反
            Notify('置顶状态: ' (on ? '已关闭' : '已开启'), '[' rec.section ']')
            return true
        case 'activate', 'focus':
            WinActivate(h)
        case 'hide':
            WinHide(h)
        case 'show':
            WinShow(h)
        default:
            Notify('未知的窗口操作: "' op '" (可用: minimize|maximize|restore|close|topmost|activate|hide|show)', '[' rec.section ']', 3)
            return false
    }
    Notify('窗口操作完成: ' op, '[' rec.section ']')
    return true
}

; ---------------------------------------------------------------------------
; app：启动 / 唤起 / 最小化 循环切换一个应用 —— 一个键就能“切过来, 再切走”
;   1) 未运行              -> 启动 target, 窗口出现后再激活一次
;   2) 已运行但最小化       -> 还原
;   3) 已运行但被遮挡/非活动 -> 激活置前
;   4) 已在前台且未最小化    -> 最小化(再按一下切走)
; target = 启动命令(未运行时用);  title = 窗口匹配, 推荐 ahk_exe xxx.exe;
;          未写 title 时尝试从 target 的 exe 名自动推断。
; ---------------------------------------------------------------------------
RaiseApp(rec) {
    title := rec.title
    if title = '' {
        exe := ExtractExeName(rec.target)
        if exe = '' {
            Notify('动作 app 缺少 title, 且无法从 target 推断进程名: ' rec.target, '[' rec.section ']', 3)
            return false
        }
        title := 'ahk_exe ' exe
    }

    hwnd := WinExist(title)
    if !hwnd {
        ; —— 未运行：先启动
        try
            Run(rec.target)
        catch as e {
            Notify('[' rec.section '] 启动失败: ' rec.target '`n' e.Message, 'WinHotKey-AHK', 3)
            return false
        }
        ; 等窗口出现(最多 6 秒)后激活一次, 让“一键唤起”体验一致
        if WinWait(title, '', 6) {
            WinActivate(title)
            Notify('已启动: ' rec.target, '[' rec.section ']')
        } else {
            Notify('已启动(等待窗口超时): ' rec.target, '[' rec.section ']')
        }
        return true
    }

    ; —— 已运行
    h := Format('ahk_id 0x{:X}', hwnd)
    isMin := WinGetMinMax(h) = -1          ; -1 = 最小化
    if WinActive(title) && !isMin {
        ; 已在前台且未最小化: 再按一次 = 最小化(切走), 下次再按会重新唤起
        WinMinimize(h)
        Notify('最小化: ' title, '[' rec.section ']')
        return true
    }

    if isMin
        WinRestore(h)
    WinActivate(h)
    Notify('唤起: ' title, '[' rec.section ']')
    return true
}

; 从启动命令里提取 exe 文件名(用于推断进程名)
;   例: chrome.exe                    -> chrome.exe
;       "C:\Program Files\...\x.exe" a -> x.exe
ExtractExeName(cmd) {
    c := Trim(cmd)
    if c = ''
        return ''
    prog := c
    if SubStr(c, 1, 1) = '"' {
        parts := StrSplit(c, '"')
        prog := (parts.Length >= 3) ? parts[2] : ''   ; 首对引号内是程序路径
        if prog = ''
            return ''
    } else {
        sp := InStr(c, ' ')
        if sp
            prog := SubStr(c, 1, sp - 1)
    }
    if RegExMatch(prog, '[^\\/]+$', &m)
        return m[0]
    return ''
}

; ---------------------------------------------------------------------------
; overview：弹出"快捷键总览"画布 —— 居中略偏下的浅色小面板,
;   列出当前已配置的全部快捷键(hotkey / 动作 / 说明)。
;   若画布已显示则关闭它(toggle); 点击面板任一行, 或约 8 秒后自动关闭。
; ---------------------------------------------------------------------------
ShowOverview() {
    global __Overview, CFG
    if __Overview {                     ; 已开着 -> 关掉(toggle)
        DestroyOverview()
        return true
    }

    records := CFG.records
    count   := records.Length

    bgClr := 'F2F2F2'
    w := Gui('+AlwaysOnTop -Caption +ToolWindow +DPIScale')
    w.BackColor := bgClr
    w.MarginX := 22
    w.MarginY := 16

    ; 标题行(可点击关闭)
    w.SetFont('s12 c333333 Bold')
    ctlTitle := w.Add('Text', '', '快捷键总览  (' count ' 项)')
    ctlTitle.OnEvent('Click', (*) => CloseOverview(w))
    w.SetFont('s9 c888888 Norm')
    ctlTip := w.Add('Text', 'y+2', '点击面板可关闭 · 约 8 秒后自动消失 · 再按该热键可切换')
    ctlTip.OnEvent('Click', (*) => CloseOverview(w))

    if count = 0 {
        w.SetFont('s11 c666666')
        ctlEmpty := w.Add('Text', 'y+14', '( 暂未配置任何热键, 请编辑 hotkeys.ini )')
        ctlEmpty.OnEvent('Click', (*) => CloseOverview(w))
    } else {
        ; 逐条列出(最多 20 条, 防面板过高)
        shown := 0
        for rec in records {
            shown += 1
            if shown > 20
                break
            name := rec.desc != '' ? rec.desc : rec.section
            line := rec.hotkey '    ' name '    [' rec.action ']'
            w.SetFont('s10 c2B2B2B')
            ctl := w.Add('Text', 'w360 y+8', line)
            ctl.OnEvent('Click', (*) => CloseOverview(w))
        }
        if count > 20 {
            w.SetFont('s9 c999999')
            ctlMore := w.Add('Text', 'w360 y+8', '…… 其余 ' (count - 20) ' 条省略, 请打开 hotkeys.ini 查看')
            ctlMore.OnEvent('Click', (*) => CloseOverview(w))
        }
    }

    ; 拿到自动尺寸后, 居中略偏下显示
    w.Show('Hide')
    w.GetPos(&x, &y, &wd, &ht)
    cx := (A_ScreenWidth  - wd) // 2
    cy := Round(A_ScreenHeight * OVERVIEW_Y_RATIO) - ht // 2
    if cy < 0
        cy := 0
    w.Show('NA x' . cx . ' y' . cy)

    hwnd := w.Hwnd
    rgn := DllCall('CreateRoundRectRgn', 'Int', 0, 'Int', 0
        , 'Int', wd, 'Int', ht, 'Int', 16, 'Int', 16, 'UPtr')
    if rgn
        DllCall('SetWindowRgn', 'Ptr', hwnd, 'Ptr', rgn, 'Int', 1)
    WinSetTransparent(246, 'ahk_id ' . hwnd)

    __Overview := w
    SetTimer((*) => CloseOverview(w), -8000)
    return true
}

; 关闭指定画布(仅当它是当前显示的画布时才清空全局引用, 避免误关新画布)
CloseOverview(w) {
    global __Overview
    if __Overview = w
        __Overview := 0
    try
        w.Destroy()
    catch
        return
}

; 销毁当前快捷键总览画布(toggle 用)
DestroyOverview() {
    global __Overview
    if __Overview
        CloseOverview(__Overview)
}

; ---------------------------------------------------------------------------
; 工具
; ---------------------------------------------------------------------------

; 动作成功后的通知气泡总开关:
;   1 = 开启(默认) —— 按热键/点菜单触发动作后, 用居中气泡显示执行结果
;   0 = 关闭 —— 成功动作静默, 不弹提示
; 无论开关如何, 错误/警告提示(opts 2/3)始终显示。
; 也可在托盘菜单里点“动作气泡提示”随时切换, 无需改这里。
ACTION_NOTIFY := 1

; 通知统一走自绘"居中气泡"(lib/Bubble.ahk), 不使用 Windows 通知。
Notify(text, title := 'WinHotKey-AHK', opts := 1) {
    global ACTION_NOTIFY
    ; opts: 0/1 = 普通信息(受开关控制), 2/3 = 警告/错误(始终显示)
    if (opts < 2 && !ACTION_NOTIFY)
        return
    ShowBubble(text, title, opts >= 2)
}

QuotePath(p) {
    return StartsWithQuote(p) ? p : ('"' . p . '"')
}

StartsWithQuote(p) {
    return SubStr(p, 1, 1) = '"'
}

LooksLikeUrl(p) {
    return RegExMatch(p, 'i)^[a-z][a-z0-9+.-]*://')
}
