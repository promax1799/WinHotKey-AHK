# WinHotKey-AHK

用 **AutoHotkey v2** 实现经典工具 **[WinHotKey](https://directedge.us/content/winhotkey/)** 全部功能的自定义全局快捷键工具：
**配置文件驱动 + 系统托盘菜单**，无需图形界面即可增删快捷键，改完配置一键重载。

> 为什么做这个？原版 WinHotKey 0.70 已多年未更新、最高支持 Windows 10；
> 本工具基于持续维护的 AutoHotkey v2，在 Windows 11 / 10 上均可运行，
> 且配置文件为纯文本、可放进版本库、可编译成免安装 exe 分发。

---

## 目录

1. [功能总览](#1-功能总览)
2. [文件结构](#2-文件结构)
3. [快速开始](#3-快速开始)
4. [配置说明](#4-配置说明)
5. [热键写法](#5-热键写法)
6. [动作详解](#6-动作详解)
7. [窗口定位 title](#7-窗口定位-title)
8. [托盘菜单](#8-托盘菜单)
9. [编译成 exe](#9-编译成-exe)
10. [开机自启](#10-开机自启)
11. [命令行参数](#11-命令行参数)
12. [与原版 WinHotKey 的差异](#12-与原版-winhotkey-的差异)
13. [常见问题 FAQ](#13-常见问题-faq)
14. [许可](#14-许可)

---

## 1. 功能总览

| 功能 | 说明 |
| --- | --- |
| 启动程序 | `run`：运行程序/命令，可带命令行参数 |
| 打开文档 | `open`：用系统默认程序打开文档、文件夹或 URL |
| 打开文件夹 | `folder`：在资源管理器中打开文件夹 |
| 输入文本 | `type`：向当前或指定窗口逐字输入一段文本 |
| 控制窗口 | `window`：最小化 / 最大化 / 还原 / 关闭 / 置顶 / 激活 / 隐藏 / 显示 |
| 启动并唤起应用 | `app`：一键循环切换某应用 —— 未运行则启动，最小化则还原，被遮挡则置前，已在前台则最小化 |
| 快捷键总览 | `overview`：`Alt+?` 弹出居中略偏下画布，列出已配置的全部快捷键 |
| 配置文件驱动 | 所有快捷键写在 `hotkeys.ini` 里，纯文本，改完即重载 |
| 托盘菜单 | 图标驻留系统托盘：查看/点击触发热键、打开配置、重载、暂停、退出 |
| 居中气泡通知 | 提示用**自绘的屏幕居中气泡**展示（屏幕中下方的浅灰半透明小卡片，不抢焦点、自动消失），**不使用 Windows 通知** |
| 出错保护 | 单条配置不合法只跳过该条并提示，不会让整个工具崩溃 |
| 编译分发 | 可一键编译为独立 `.exe`，目标机器无需安装任何东西 |

---

## 2. 文件结构

```
WinHotKey-AHK/
├── WinHotKey.ahk        # 主程序（也是编译入口）
├── build.bat            # Windows 一键编译脚本（输出 WinHotKey.exe）
├── hotkeys.ini          # 快捷键配置（示例）；与主程序同目录，首次运行可自动生成
├── lib/
│   ├── Bubble.ahk       # 自绘“屏幕居中气泡”通知（不依赖 Windows 通知）
│   ├── Config.ahk       # INI 解析、热键写法规范化（友好写法→AHK 原生）
│   ├── Actions.ahk      # 各动作的执行器 + 通知开关封装
│   └── HotkeyManager.ahk# 热键动态注册 / 注销 / 批量注册引擎
└── README.md            # 本文档
```

- **源码方式运行**：`lib/` 三个文件必须与 `WinHotKey.ahk` 保持相对位置。
- **编译为 exe 后**：三个 `.ahk` 库文件会被合并进 exe，此时只需保留
  `WinHotKey.exe` 与 `hotkeys.ini`（甚至不需要 `hotkeys.ini` —— 首次运行会自动生成模板）。

---

## 3. 快速开始

### 方式 A：源码直接运行（需要 AutoHotkey v2）

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/download/)（安装时勾选 v2）。
2. 双击 `WinHotKey.ahk`。
3. 首次运行会在同目录自动生成一份 `hotkeys.ini` 模板并立即生效。
4. 系统托盘出现绿色「H」图标 → 右键可看到热键列表与管理菜单。

### 方式 B：编译成 exe（目标机器零依赖）

见 [第 9 节](#9-编译成-exe)。

### 验证是否生效

按模板里的 `Win+Ctrl+E`（示例动作：打开文件夹）——如果弹出资源管理器即成功。

---

## 4. 配置说明

`hotkeys.ini` 采用 **INI 格式**：每个 `[小节]` 定义一条快捷键。

```ini
[给浏览器留的说明性小节名]
hotkey = Win+Ctrl+B      ; 必填：触发按键
action = run             ; 必填：动作类型
target = notepad.exe     ; 必填：动作内容（随 action 变化）
title  =                 ; 可选：窗口定位（type / window 用）
desc   = 说明文字        ; 可选：显示在托盘菜单里
```

### 4.1 语法规则

- **注释**：`;` 或 `#` 开头的**整行**为注释。**不支持行尾注释**。
- `键 = 值` 两边的空格会被忽略；键名不区分大小写。
- 值若含空格，一般不需要引号（`run` 启动带空格的 exe 时按 [6.1](#61-run-启动程序) 的引号规则）。
- 修改保存后 → 托盘图标右键 → **重载配置**，立即生效，无需重启、无需重新编译。
- 配置文件编码：保存为 **UTF-8**（Windows 记事本默认即 UTF-8）。
- 重复的热键、缺失必填字段的小节会被**跳过**并弹出警告，其余正常加载。

### 4.2 字段总表

| 字段 | 必填 | 适用动作 | 说明 |
| --- | :-: | --- | --- |
| `hotkey` | ✅ | 全部 | 触发组合键，见 [第 5 节](#5-热键写法) |
| `action` | ✅ | 全部 | `run` / `open` / `folder` / `type` / `window` / `app` / `overview` |
| `target` | ✅* | 全部 | 动作内容（见各动作小节；也可用下列别名键代替）。*`overview` 除外，可不填 |
| `title` | — | `type` `window` `app` | 目标窗口条件；`type`/`window` 留空=作用于当前活动窗口；`app` 留空=尝试自动推断 |
| `desc` | — | 全部 | 说明，显示在托盘菜单条目上 |

**`target` 的惯用别名**（写了 `target` 就不必理会，二者取其一即可）：

| action | target 别名 |
| --- | --- |
| run | `program` `exe` `command` |
| app | `program` `exe` `command` |
| open | `document` `file` |
| folder | `folder` `path` |
| type | `text` |
| window | `op` `operation` `window` |

例：`action = run` 时也可以写 `program = notepad.exe`，效果等同于 `target = notepad.exe`。

---

## 5. 热键写法

### 5.1 友好写法（推荐）

用 `+` 把修饰键与按键连起来，**顺序任意、大小写不限**：

```ini
hotkey = Win+Ctrl+B      ; 即 Win + Ctrl + B
hotkey = Ctrl+Win+B      ; 同上（顺序无所谓）
hotkey = Win+Alt+F4      ; Win + Alt + F4
hotkey = Shift+Win+S
```

| 修饰键写法 | 含义 |
| --- | --- |
| `Win` | ⊞ Win 键 |
| `LWin` / `RWin` | 仅左 / 右 Win |
| `Ctrl`（或 `Control`） | Ctrl |
| `LCtrl` / `RCtrl` | 仅左 / 右 Ctrl |
| `Alt` | Alt |
| `LAlt` / `RAlt` | 仅左 / 右 Alt |
| `Shift` | Shift |
| `LShift` / `RShift` | 仅左 / 右 Shift |

按键部分可写：单个字母 `B`、数字 `1`、功能键 `F13`、方向键 `Up`、
`Space`、`Enter`、`Tab`、`Esc`、`Numpad0`、`PrintScreen`、`Delete`、
`Home` / `End` / `PgUp` / `PgDn`、`CapsLock`、`ScrollLock`、媒体键等
（与 AutoHotkey v2 的按键名称一致）。

### 5.2 原生 AHK 写法（进阶透传）

只要是 **以 `# ^ ! + < > * ~ $` 之一开头**（或没有 `+` 的单个按键）的写法，
会被**原样透传**给 AutoHotkey 引擎：

```ini
hotkey = #^b              ; 等价于 Win+Ctrl+B
hotkey = ^!r              ; Ctrl+Alt+R
hotkey = *F12             ; 任意修饰键下的 F12（通配符）
hotkey = ~#Space          ; ~ = 不拦截按键本身
```

### 5.3 注意事项

- **强烈建议使用 `Win` 键组合**（如 `Win+Ctrl+X`）。Windows 自身占用大量
  `Win+X`、`Ctrl+Alt+Del` 等组合，单一 `Ctrl`/`Alt` 极易与其它软件冲突。
- `Ctrl+Alt+Delete` 是系统安全组合，**任何方式都无法注册**。
- 不要给 `type` 之外的日常操作绑裸字母键（如仅 `B`），否则该字母在所有程序里都会被劫持。
- **上档字符按键**：`Alt+?` 会按 `Alt+Shift+/` 处理（`?` 位于 `/` 键上），
  适用于欧美键盘布局；非英文布局请改用字母键组合。

---

## 6. 动作详解

### 6.1 run —— 启动程序

```ini
[启动记事本]
hotkey = Win+Ctrl+B
action = run
target = notepad.exe
desc = 打开记事本
```

**引号规则**（重要）：

| target 例子 | 效果 |
| --- | --- |
| `notepad.exe` | 运行 PATH 中的程序 |
| `C:\Tools\app.exe` | 全路径、无空格 |
| `"C:\Program Files\App\app.exe"` | 路径含空格 → **exe 路径用双引号包住** |
| `"C:\Program Files\App\app.exe" -new` | 同上，参数放引号外 |
| `"C:\Program Files\App\app.exe" "D:\my notes.txt"` | 参数本身也含空格 → 参数也加引号 |

### 6.2 open —— 用默认程序打开文档 / URL

```ini
[打开我的笔记]
hotkey = Win+Ctrl+D
action = open
target = C:\Users\Me\Documents\notes.txt

[打开官网]
hotkey = Win+Ctrl+O
action = open
target = https://www.autohotkey.com
```

- 本地文件：含空格也会**自动加引号**，无需手动处理。
- `http(s)://` 等 URL：自动识别、不加引号，交给默认浏览器。

### 6.3 folder —— 打开文件夹

```ini
[打开下载目录]
hotkey = Win+Ctrl+E
action = folder
target = C:\Users\Me\Downloads
desc = 打开资源管理器
```

支持本地路径、UNC 网络路径（`\\server\share`）等。

### 6.4 type —— 输入文本

```ini
[输入版权符号]
hotkey = Win+Ctrl+U
action = type
target = © 2025 ReasoniX. 保留所有权利。
desc = 输入一行文本
```

- **无 `title`**：把文本输入到**当前活动窗口**的光标处（先切到目标窗口再按热键）。
- **有 `title`**：自动激活该窗口后再输入。
- 使用 AutoHotkey 的 `SendText`，逐字符按 Unicode 投递，**现代 Windows 均可用**——
  原版 WinHotKey 的“自动输入”因依赖旧 SendKeys 在 Vista/7+ 失效，这里不受影响。
- 中文、emoji、`{ }` `^` `+` 等字符都会原样输入，无需转义。
- 每次触发默认输入一次。若需“先粘贴后回车”等复杂流程，可在 target 文本中加入
  换行符以外的按键（见 6.4.1）。

#### 6.4.1 输入换行 / Tab / 其它按键

配置是**单行文本**。如需包含换行 / Tab，可用反引号转义——触发时由
`SendText` 解释（源码运行与编译版行为一致），例如：

```ini
target = 第一行`n第二行
```

（`` ` `` 是键盘左上角的**反引号**：`` `n `` = 回车、`` `t `` = Tab、`` `b `` = 退格。）

### 6.5 window —— 窗口控制

```ini
[最小化当前窗口]
hotkey = Win+Ctrl+M
action = window
target = minimize          ; 不写 title = 作用于活动窗口

[切换记事本置顶]
hotkey = Win+Ctrl+T
action = window
target = topmost
title = ahk_exe notepad.exe ; 指定窗口（见第 7 节）
```

`target`（即操作名）取值：

| 值 | 效果 |
| --- | --- |
| `minimize` | 最小化 |
| `maximize` / `max` | 最大化 |
| `restore` | 还原 |
| `close` | 关闭窗口 |
| `topmost` / `alwaysontop` / `ontop` | 切换“窗口置顶”（再按一次取消） |
| `activate` / `focus` | 激活 / 聚焦 |
| `hide` | 隐藏窗口（需用其它方式再显示） |
| `show` | 显示隐藏的窗口 |

### 6.6 app —— 启动并唤起应用（一键切到某应用）

```ini
[启动 / 唤起 Chrome]
hotkey = Alt+C
action = app
target = chrome.exe
title = ahk_exe chrome.exe
desc = 一键切到 Chrome
```

`app` 动作把“启动、切到前台、最小化”合并成一个按键循环切换，逻辑如下：

| 当前状态 | 效果 |
| --- | --- |
| 程序未运行 | 启动 `target`，窗口出现后再激活一次 |
| 已运行但**最小化** | 还原（显示） |
| 已运行但**被遮挡 / 非活动** | 激活并放到最前面 |
| 已在前台（激活）且未最小化 | **最小化**（再按一下切走，下次再按会重新唤起） |

要点：

- `target`：程序未运行时的启动命令（可带参数/路径，路径含空格用双引号）。
- `title`：**推荐显式填写**运行中窗口的匹配条件，一般用 `ahk_exe 进程名.exe`。
- `title` 留空时会尝试从 `target` 的 exe 名**自动推断**（如 `target = chrome.exe` → `ahk_exe chrome.exe`）。
- 可替代 WinHotKey 时代“Ctrl+Alt+某键唤起浏览器/编辑器”的习惯，把多个应用各绑一个键即可快速切换。
- 注：目标窗口若以管理员身份运行而本程序不是，可能无法激活（UIPI 隔离），可改用管理员运行本程序。

### 6.7 overview —— 快捷键总览

```ini
[快捷键总览]
hotkey = Alt+?
action = overview
desc = 弹出已设置快捷键列表
```

`overview` 动作会弹出一个**居中略偏下**的浅色小画布，列出当前**已配置的全部快捷键**
（每行显示 `按键 · 说明 · [动作类型]`），方便随时查自己设了哪些键。

行为说明：

- **`target` 不需要填写**（`overview` 是唯一不要求 `target` 的动作）。
- 显示期间**不抢焦点**；**点击画布任意处**立即关闭，或约 **8 秒**后自动消失。
- 再按一次该热键 = 切换（关闭）当前画布。
- 托盘的 **“快捷键总览”** 菜单项与它等价，可随时点开查看。
- 画布内容随“重载配置”实时更新（重新弹一次即是新列表）。

> 提示：`Alt+?` 在键盘上其实是 `Alt + Shift + /`（问号在 `/` 键上）。
> 想换成其它键（如 `Win+Ctrl+H`）直接改 `hotkey` 即可。

---

## 7. 窗口定位 title

`title` 支持 AutoHotkey v2 的窗口条件语法，常见写法：

| title 写法 | 匹配范围 |
| --- | --- |
| `未命名 - 记事本` | 标题包含该文本的窗口 |
| `ahk_exe notepad.exe` | 指定进程名的窗口（最常用） |
| `ahk_class Notepad` | 指定窗口类（用 Window Spy 查看） |
| `ahk_pid 1234` | 指定进程 ID |

`type` 与 `window` 动作：**`title` 留空 = 作用到“当前活动窗口”**。
`app` 动作：**`title` 留空 = 尝试从 `target` 的 exe 名自动推断**。

---

## 8. 托盘菜单

程序驻留系统托盘（图标旁悬停可看提示）。**右键图标**：

| 菜单项 | 作用 |
| --- | --- |
| 每个热键一行（`说明 [按键]`） | 点击 = **手动触发一次**该动作，方便测试 |
| 打开配置文件 | 用记事本打开 `hotkeys.ini` |
| 重载配置 | 重新读取配置文件并注册热键（改完配置用它） |
| 快捷键总览 | 弹出画布列出全部快捷键（等同 `overview` 动作） |
| 暂停 / 恢复热键 | 临时停用 / 恢复全部热键（菜单项有勾选标记） |
| 动作气泡提示 | 开关"触发动作后的居中气泡通知"（见下） |
| 关于 WinHotKey-AHK | 版本与信息 |
| 退出 | 退出程序（所有热键失效） |

**双击**托盘图标 = 打开配置文件。

**关于通知（居中气泡）**：程序**不使用 Windows 通知**，提示一律用**自绘的屏幕居中气泡**显示——
位于屏幕**中下方**，**浅灰半透明**圆角小卡片 + 深灰文字，不激活不抢焦点、点击可穿透、
约 2 秒后自动消失（错误提示为浅红底、深红文字）。气泡**不显示标题**，只显示一行正文。

- 程序状态提示（如重载后"已加载 N 个热键"、暂停/恢复）**始终**用居中气泡显示。
- **按热键/点菜单触发动作后会弹气泡**显示执行结果（如"已启动…""已唤起…"）——默认**开启**；
  若觉得太频繁，在托盘菜单点 **动作气泡提示** 取消勾选即可关闭（再点恢复）。
- **错误/警告提示**（如热键注册失败、运行失败、配置问题）无论开关如何**始终**显示。

---

## 9. 编译成 exe

> 目标：把脚本 + AutoHotkey 解释器打包成一个 **`WinHotKey.exe`**，
> 拷到任何 Windows 10/11（32/64 位）机器双击即用，**无需安装 AutoHotkey**。

### 9.1 前置：安装 Ahk2Exe（编译器）

> ⚠️ **AutoHotkey v2 主程序默认不带 `Ahk2Exe.exe`**，需要单独安装一次。

- **方法一（推荐）**：开始菜单打开 **AutoHotkey**（即 Dash 面板）→ 点 **Compile** →
  它会自动检测并**下载安装 Ahk2Exe**，装好后 `Ahk2Exe.exe` 会出现在
  `C:\Program Files\AutoHotkey\v2\`（或当前用户安装的 `%LocalAppData%\Programs\AutoHotkey\v2\`）。
- **方法二（手动）**：到 <https://github.com/AutoHotkey/Ahk2Exe/releases> 下载 `Ahk2Exe.zip`，
  解压得到 `Ahk2Exe.exe`，放到 AutoHotkey v2 安装目录（与 `AutoHotkey64.exe` 同级），
  或在系统环境变量里新增 `AHK2EXE_EXE` 指向它的完整路径。

### 9.2 在 Windows 上一键编译

1. 确认已装 AutoHotkey v2 且已装 Ahk2Exe（见上）。
2. 双击 `build.bat`。
3. 同目录生成 `WinHotKey.exe`。

`build.bat` 会自动在常见安装目录查找 `Ahk2Exe.exe`；
找不到时会打印指引（见上 9.1）。

### 9.3 手动命令行

```bat
Ahk2Exe.exe /in WinHotKey.ahk /out WinHotKey.exe
```

加自定义图标：

```bat
Ahk2Exe.exe /in WinHotKey.ahk /out WinHotKey.exe /icon icon.ico /compress 1
```

> **重要（编码）**：本仓库所有 `.ahk` 与 `hotkeys.ini` 已保存为 **UTF-8 带 BOM**。
> AutoHotkey 官方要求含非 ASCII 字符的脚本使用 UTF-8 **带 BOM**，
> 否则在中文 Windows（默认 ANSI 代码页 GBK）上会被按 GBK 误读而乱码。
> 若你以后用编辑器改这些文件，请保持 **UTF-8 with BOM** 另存。

### 9.4 在 Linux（Wine）下交叉编译

本仓库在 Kali Linux 上编写；如需在 Linux 上直接产出 exe，可用 wine：

```bash
# 先下载 AutoHotkey v2 便携版并解压到 win 目录（含 Compiler/Ahk2Exe.exe）
wine "C:/path/to/Ahk2Exe.exe" /in WinHotKey.ahk /out WinHotKey.exe
```

### 9.5 部署

```
分发目录/
├── WinHotKey.exe     # 只此一个即可
└── hotkeys.ini       # 可选：没有的话首次运行自动生成
```

把 exe 拷给别人时，把 `lib/*.ahk` 一起删掉也没关系（已合并进 exe）。

---

## 10. 开机自启

1. 按下 `Win + R`，输入 `shell:startup` 回车，打开“启动”文件夹。
2. 把 `WinHotKey.exe`（或 `WinHotKey.ahk` 的快捷方式）放进去。
3. 以后开机自动运行。

---

## 11. 命令行参数

```bat
WinHotKey.exe                      ; 使用 exe 同目录 hotkeys.ini
WinHotKey.exe "D:\my\keys.ini"     ; 指定配置文件
WinHotKey.exe "D:\my\configs"      ; 指定目录 → 读取 目录\hotkeys.ini
```

---

## 12. 与原版 WinHotKey 的差异

| 对比项 | 原版 WinHotKey 0.70 | 本工具 |
| --- | --- | --- |
| 语言/框架 | C++，≤Win10，已停更 | AutoHotkey v2，持续维护，支持 Win10/11 |
| 交互 | 图形界面（向导式） | 配置文件 + 托盘菜单（改文本即增删快捷键） |
| 输入文本动作 | Vista/7+ 失效 | 基于 `SendText`，现代系统可用 |
| 编译 | 作者发布 exe | `build.bat` 一键编译，可自定图标 |
| 扩展性 | 固定动作 | 热键写法可直接透传 AHK 原生语法（通配符/钩子等） |

> 若你更想要**图形化增删**的体验，可在本仓库基础上加一层 GUI
> （读取同一份 `hotkeys.ini`），配置文件格式保持不变。

---

## 13. 常见问题 FAQ

**Q1：按了热键没反应？**
先看托盘图标是否还在（程序是否在运行）。然后在托盘菜单里点对应条目看能否手动触发；
若只有热键不行，多半是该组合被其它程序/系统占用 —— 换成 `Win+Ctrl+某键` 试试。

**Q2：屏幕弹出“热键注册失败”？**
该组合与系统或其它软件冲突（如 `Win+L`、`Ctrl+Alt+Del`、某些应用注册的全局热键）。
修改 `hotkeys.ini` 换成别的组合后重载。

**Q3：改完 hotkeys.ini 不生效？**
保存后要在托盘菜单点 **重载配置**；确认文件保存为 **UTF-8**；
留意弹出的“配置警告”对话框，问题条目会被跳过。

**Q4：type 没输入任何东西 / 输到别处去了？**
`type` 发往**当前活动窗口**，先点击目标输入框再按热键；
若窗口以管理员身份运行而本程序不是（UIPI 隔离），模拟输入会被系统拦截 —— 以管理员运行本程序即可。

**Q5：置顶后怎么取消？**
再按一次同一条热键即可（`topmost` 是切换）。

**Q6：exe 能拷去别的电脑用吗？**
能。`WinHotKey.exe` 是独立 exe（含解释器）；配置文件放同目录即可，
首次运行会自动生成模板。

**Q7：配置里有中文，运行时乱码？**
配置文件请保存为 **UTF-8**。Windows 10 1809+ 的记事本默认就是 UTF-8。

**Q8：如何完全卸载？**
退出程序（托盘菜单 → 退出），删除整个 `WinHotKey-AHK` 文件夹即可，无残留。

**Q9：双击 build.bat 报一串“不是内部或外部命令”，还带着残缺的单词？**
这是 `build.bat` 的**换行符被存成了 LF**（Unix 行尾）导致 `cmd.exe` 解析错乱。
本仓库中的 `build.bat` 已是 CRLF（Windows 行尾），直接从仓库拷贝即可；
若你曾在 Linux / 某些编辑器里改过它，请用支持选择行尾的编辑器
（VSCode 右下角 `LF`→`CRLF`、Notepad++ `编辑→EOL 转换→Windows`）另存后再运行。

**Q10：编译时报找不到 `Ahk2Exe.exe` / 装完 v2 没有 Ahk2Exe？**
AutoHotkey v2 **默认不包含** Ahk2Exe 编译器，需要单独安装：
开始菜单打开 **AutoHotkey** → 点 **Compile** 让其自动下载安装；
或到 <https://github.com/AutoHotkey/Ahk2Exe/releases> 下载 `Ahk2Exe.zip`，
把 `Ahk2Exe.exe` 放到 AutoHotkey v2 安装目录（与 `AutoHotkey64.exe` 同级）后重试 build.bat。
详见 [第 9.1 节](#91-前置安装-ahk2exe编译器)。

**Q11：运行/编译后界面中文乱码？**
含中文的 `.ahk` / `.ini` 必须保存为 **UTF-8 带 BOM**（本仓库文件均已带）。
若你编辑过导致乱码，用编辑器改为 UTF-8 with BOM 另存即可。

---

## 14. 许可

- 本工具为教学/自用示例，按 **MIT** 精神开源使用（代码可自由修改分发）。
- 名称致敬原版 [WinHotKey](https://directedge.us/content/winhotkey/)（directedge.us，免费软件），
  与原版无任何从属关系。
- AutoHotkey 为 [GPL 许可](https://www.autohotkey.com/license/) 的开源项目；按原项目条款遵守即可。

---

*本代码在 Linux 环境下编写，已按 AutoHotkey v2 官方文档逐项核对 API；
如在真实 Windows/AHK 环境发现小问题，欢迎指正。*
