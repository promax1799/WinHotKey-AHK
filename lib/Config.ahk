; ============================================================================
;  WinHotKey-AHK — lib/Config.ahk
;  配置解析 + 热键写法规范化
;
;  配置文件格式（INI，用“小节”组织，每个小节 = 一条热键）:
;
;   [小节名称]              ; 每行一条
;   hotkey  = Win+Ctrl+B    ; 必填。支持友好写法(见 NormalizeHotkey)
;   action  = run           ; 必填。run|open|folder|type|window|app|overview
;   target  = notepad.exe   ; 必填(overview 除外)。含义随 action 而定
;   title   =               ; 可选。窗口标题/条件，type/window/app 用到
;   desc    = 说明          ; 可选。显示在托盘菜单里
;
;   ; 整行以 ; 或 # 开头视为注释。不支持行尾注释。
; ============================================================================

; ---------------------------------------------------------------------------
; LoadConfig(路径) -> 对象 { records: 记录数组, warnings: 字符串数组 }
; 逐行自解析(非 IniRead)，从而彻底避开编码/转义差异，
; 并允许 UTF-8(带或不带 BOM)、UTF-16 文件。
; ---------------------------------------------------------------------------
LoadConfig(path) {
    result := { records: [], warnings: [] }
    if !FileExist(path) {
        result.warnings.Push('配置文件不存在: ' path)
        return result
    }

    warnings := []
    text := FileRead(path)          ; v2 默认 UTF-8，且自动识别 BOM
    if SubStr(text, 1, 1) = Chr(0xFEFF)
        text := SubStr(text, 2)     ; 防御：若 BOM 未被剥离则去掉
    text := StrReplace(StrReplace(text, "`r`n", "`n"), "`r", "`n")
    sections := ParseIniText(text, &warnings)

    seen := Map()                   ; native 热键 -> 小节名，用于查重
    for sec in sections {
        rec := BuildRecord(sec, &warnings)
        if Type(rec) != 'Object'
            continue

        try
            native := NormalizeHotkey(rec.hotkey)
        catch as e {
            warnings.Push('[' sec.name '] ' e.Message)
            continue
        }
        rec.native := native

        ; 托盘/提示里展示用的文字
        rec.display := rec.desc != '' ? rec.desc : (sec.name . ' (' . native . ')')

        if seen.Has(native) {
            warnings.Push('重复热键 "' native '" ([' sec.name ']) 被忽略, 保留 [' seen[native] ']')
            continue
        }
        seen[native] := sec.name
        result.records.Push(rec)
    }
    result.warnings := warnings
    return result
}

; ---------------------------------------------------------------------------
; 把 INI 文本解析成小节数组：[ {name, keys: Map(小写键->值)}, ... ]
; ---------------------------------------------------------------------------
ParseIniText(text, &warnings) {
    sections := []
    cur := 0
    hasSection := false             ; 是否已进入一个小节(避免对象与 0 比较)
    for line in StrSplit(text, "`n") {
        t := Trim(line, " `t`r")
        if t = ''
            continue
        first := SubStr(t, 1, 1)
        if first = ';' or first = '#'
            continue                ; 整行注释

        if first = '[' {
            if RegExMatch(t, '^\[(.*)\]\s*$', &m) {
                cur := { name: Trim(m[1]), keys: Map() }
                sections.Push(cur)
                hasSection := true
            } else {
                warnings.Push('忽略无法解析的小节标题: ' t)
                hasSection := false
            }
            continue
        }

        if !hasSection {
            warnings.Push('忽略第一个小节之外的配置行: ' t)
            continue
        }

        eq := InStr(t, '=')
        if eq = 0 {
            warnings.Push('忽略无法解析的配置行: ' t)
            continue
        }
        k := Trim(SubStr(t, 1, eq - 1), ' `t')
        v := Trim(SubStr(t, eq + 1), ' `t')
        if k = ''
            continue
        cur.keys[StrLower(k)] := v  ; 键名统一小写, 便于大小写不敏感
    }
    return sections
}

; ---------------------------------------------------------------------------
; 由一个小节生成一条动作记录; 字段不合法时返回 0 并追加警告。
; ---------------------------------------------------------------------------
BuildRecord(sec, &warnings) {
    k := sec.keys
    secName := sec.name
    name := '[' secName '] '

    action := GetK(k, 'action')
    if action = '' {
        warnings.Push(name '缺少 action 字段(action = run|open|folder|type|window|app|overview), 已跳过')
        return 0
    }
    action := StrLower(action)
    static validActions := Map('run', 1, 'open', 1, 'folder', 1, 'type', 1, 'window', 1, 'app', 1, 'overview', 1, 'list', 1, 'help', 1)
    if !validActions.Has(action) {
        warnings.Push(name '未知的 action: "' action '"')
        return 0
    }

    hotkey := GetK(k, 'hotkey')
    if hotkey = '' {
        warnings.Push(name '缺少 hotkey 字段, 已跳过')
        return 0
    }

    ; overview/list/help = 弹出"快捷键总览", 不需要 target
    needsTarget := (action != 'overview' && action != 'list' && action != 'help')

    ; target：优先取 target 字段; 也接受各动作的惯用别名
    target := ''
    if needsTarget {
        target := GetK(k, 'target')
        if target = '' {
            for a in ['program', 'exe', 'command', 'document', 'file', 'path', 'folder', 'text', 'op', 'operation', 'window', 'value'] {
                v := GetK(k, a)
                if v != '' {
                    target := v
                    break
                }
            }
        }
        if target = '' {
            warnings.Push(name '缺少 target/内容字段, 已跳过')
            return 0
        }
    }

    rec := {
        action:  action,
        hotkey:  hotkey,
        target:  target,
        title:   GetK(k, 'title'),
        desc:    GetK(k, 'desc'),
        section: secName
    }
    return rec
}

GetK(m, key) {
    return m.Has(key) ? m[key] : ''
}

; ---------------------------------------------------------------------------
; NormalizeHotkey(输入) -> AHK v2 原生热键写法
;
; 1) 友好写法：用 + 连接修饰键与按键, 大小写不敏感, 顺序不限。
;      Win+Ctrl+B  ==  Ctrl+Win+B  ==  #^b
;    可用修饰键: Win / LWin / RWin / Ctrl / Alt / Shift
;              (L/R 前缀 = 仅左/右侧那个键)
; 2) 直接写 AHK 原生语法(以 # ^ ! + < > * ~ $ 之一开头)则原样透传。
; 3) 无 + 的单个按键(如 F13)也原样透传。
; ---------------------------------------------------------------------------
NormalizeHotkey(input) {
    s := Trim(input)
    if s = ''
        throw ValueError('热键为空')

    ; 原生 AHK 语法：以修饰符/通配符等符号开头
    if RegExMatch(s, '^[#^!+<>*~$]')
        return s

    if !InStr(s, '+')
        return s                    ; 无修饰键的单个按键(如 F12 / Numpad0)

    parts := StrSplit(s, '+')
    n := parts.Length
    if n < 2
        throw ValueError("无法解析热键: '" input "'")

    mods := ''
    key := ''
    for i, tokRaw in parts {
        tok := Trim(tokRaw, ' `t')
        if tok = ''
            throw ValueError("无法解析热键: '" input "', 存在空的组合项")
        if i < n {
            switch StrLower(tok) {
                case 'win':             mods .= '#'
                case 'lwin':            mods .= '<#'
                case 'rwin':            mods .= '>#'
                case 'ctrl', 'control': mods .= '^'
                case 'lctrl', 'lcontrol': mods .= '<^'
                case 'rctrl', 'rcontrol': mods .= '>^'
                case 'alt':             mods .= '!'
                case 'lalt':            mods .= '<!'
                case 'ralt':            mods .= '>!'
                case 'shift':           mods .= '+'
                case 'lshift':          mods .= '<+'
                case 'rshift':          mods .= '>+'
                default:
                    throw ValueError("无法识别的修饰键 '" tok "' (可用: Win/Ctrl/Alt/Shift 或其 L/R 变体, 也可直接写原生语法如 #^b)")
            }
        } else {
            key := tok
        }
    }
    if key = ''
        throw ValueError("无法解析热键: '" input "', 缺少按键部分")

    ; 上档字符按键: '?' 位于 '/' 键上, 需补 Shift 修饰, 例如 Alt+? => !+/
    if key = '?' {
        if SubStr(mods, -1) = '+'      ; 已含 Shift, 不必再加
            return mods . '/'
        return mods . '+/'
    }

    return mods . key
}
