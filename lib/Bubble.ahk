; ============================================================================
;  WinHotKey-AHK — lib/Bubble.ahk
;  自绘"屏幕居中气泡"通知 —— 不依赖 Windows 通知(TrayTip/Toast)
;
;  特性:
;    * 无边框小卡片, 屏幕水平居中、垂直位于屏幕中下方(默认约 92% 高度处, 贴近底部)。
;    * 浅灰半透明背景 + 圆角 + 深灰文字(错误态为浅红底+深红文字)。
;    * 只显示正文, 不显示标题。
;    * 不激活、不抢焦点, 点击可穿透, 约 1.9 秒后自动消失。
;    * 同时只显示一条, 新通知会顶掉上一条。
; ============================================================================

__Bubble := 0                       ; 当前气泡窗口(Gui 对象), 0 = 无
BUBBLE_Y_RATIO := 0.92              ; 垂直位置: 屏幕高度的比例 (0.5 = 正中, >0.5 偏下; 0.92 贴近底部)

; ---------------------------------------------------------------------------
; ShowBubble(文本, 标题 := '', 是否错误 := false)
;   注意: 标题参数仅作兼容保留, 气泡内不再显示标题, 只显示 text 正文。
;   isError=true 时用浅红底+深红文字, 用于错误/警告提示。
; ---------------------------------------------------------------------------
ShowBubble(text, title := '', isError := false) {
    global __Bubble

    ; 先收起上一条气泡, 避免重叠
    if __Bubble {
        try
            __Bubble.Destroy()
        catch
            __Bubble := 0
    }

    ; 浅灰半透明主题: 普通=浅灰底+深灰字; 错误=浅红底+深红字
    bgColor   := isError ? 'F6DDDD' : 'F0F0F0'   ; 窗口背景(浅灰/浅红)
    bodyClr   := isError ? '7A1F1F' : '2B2B2B'   ; 正文字色(深灰/深红)
    prefix    := isError ? '⚠ ' : ''
    bodyText  := prefix . text

    w := Gui('+AlwaysOnTop -Caption +ToolWindow +DPIScale')
    w.BackColor := bgColor
    w.MarginX := 18
    w.MarginY := 12

    ; 过长文本限制宽度自动换行, 短文本保持紧凑(小气泡)
    capped := StrLen(text) > 48

    ; 只显示正文(不再添加标题行)
    w.SetFont('s11 c' . bodyClr)
    bodyOpt := capped ? 'w320' : ''
    w.Add('Text', bodyOpt, bodyText)

    ; 首次 Show 触发自动尺寸; 先隐藏实例化, 拿到尺寸后居中再显示
    w.Show('Hide')
    w.GetPos(&x, &y, &wd, &ht)

    cx := (A_ScreenWidth  - wd) // 2
    cy := Round(A_ScreenHeight * BUBBLE_Y_RATIO) - ht // 2
    if cy < 0
        cy := 0
    ; 避免超出屏幕底部(多行文本/高分缩放时)
    maxCy := A_ScreenHeight - ht - 24
    if cy > maxCy
        cy := maxCy
    w.Show('NA x' . cx . ' y' . cy)

    ; 圆角(气泡感)
    hwnd := w.Hwnd
    rgn := DllCall('CreateRoundRectRgn', 'Int', 0, 'Int', 0
        , 'Int', wd, 'Int', ht, 'Int', 14, 'Int', 14, 'UPtr')
    if rgn {
        DllCall('SetWindowRgn', 'Ptr', hwnd, 'Ptr', rgn, 'Int', 1)
    }
    ; 更透明: 220 -> 190 (值越小越透)
    WinSetTransparent(190, 'ahk_id ' . hwnd)
    WinSetExStyle('+0x20', 'ahk_id ' hwnd)       ; WS_EX_TRANSPARENT

    __Bubble := w
    SetTimer((*) => DestroyBubble(w), -1900)     ; 一次性, 1.9s 后自动消失
}

; 定时销毁气泡
DestroyBubble(w) {
    global __Bubble
    if __Bubble = w
        __Bubble := 0
    try
        w.Destroy()
    catch
        return
}
