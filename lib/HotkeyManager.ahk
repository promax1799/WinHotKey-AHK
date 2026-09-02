; ============================================================================
;  WinHotKey-AHK — lib/HotkeyManager.ahk
;  动态热键引擎：注册 / 全部注销 / 批量注册
;
;  说明：本脚本的热键全部通过 Hotkey() 函数在运行时动态创建，
;  因此主程序需要在 auto-execute 末尾调用 Persistent() 保持常驻。
; ============================================================================

class HotkeyManager {
    static keys := []                       ; 已注册的原生热键名(字符串数组)

    ; ---- 注销所有热键(供“重载配置”使用) ----
    static Clear() {
        for native in this.keys
            this.OffHotkey(native)
        this.keys := []
    }

    ; ---- 注销单个热键(不存在时静默忽略) ----
    static OffHotkey(native) {
        try
            Hotkey(native, 'Off')       ; v2: 第二个参数传 "Off" 即注销
        catch
            return                      ; 该键不存在/已被注销, 忽略
    }

    ; ---- 批量注册 ----
    static RegisterAll(records) {
        count := 0
        for rec in records {
            if this.Register(rec)
                count += 1
        }
        return count
    }

    ; ---- 注册单个热键 ----
    ; Options 必须带 "On": 若该键此前被 Clear() 用 "Off" 禁用过,
    ; 仅传回调重注册会保持禁用状态(见官方 Hotkey 文档说明)。
    static Register(rec) {
        try {
            Hotkey(rec.native, MakeHotkeyHandler(rec), 'On')
        } catch as e {
            Notify('热键注册失败: ' rec.hotkey '  ->  ' rec.native '`n' e.Message, 'WinHotKey-AHK', 3)
            return false
        }
        this.keys.Push(rec.native)
        return true
    }
}

; ---------------------------------------------------------------------------
; 生成闭包：把动作记录 rec 绑定进热键回调
; ---------------------------------------------------------------------------
MakeHotkeyHandler(rec) {
    return (*) => ExecuteAction(rec)
}

; ---------------------------------------------------------------------------
; 生成托盘菜单点击处理器(点击条目 = 手动触发一次该动作)
; ---------------------------------------------------------------------------
MakeMenuHandler(rec) {
    return (*) => ExecuteAction(rec)
}
