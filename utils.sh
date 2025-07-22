#!/bin/false

pkg=(bash curl less grep diffutils htop broot btop micro traceroute rsync netcat-openbsd)
bin=(/usr/bin/{bash,curl,less,grep,diff,htop,broot,btop,micro,traceroute,rsync,nc})
etc=(/etc/ssl/certs/ca-certificates.crt)
: "${pkg:?}" "${bin:?}" "${etc:?}"

# home
install_dest home/bashrc <<'EOF'
AssetID=

# env
PS1='\[\e]0;${AssetID:+${AssetID} }\H ${PWD}\a\]\[\e[1;33m\]\t \[\e[36m\]\H \[\e[35m\]${AssetID:+${AssetID} }\[\e[34m\]\w \[\e[0;91m\]${?#0}\[\e[0m\]\n\[\e[1;$(_ps1_c0)m\]\u \[\e[37m\]\$ \[\e[0m\]'
_ps1_c0 () { [[ "${EUID}" == 0 ]] && { echo 31; return; }; echo 32; }
export VISUAL='micro' EDITOR='micro'; alias e="${EDITOR}"
export LESSSECURE=1 LESSHISTFILE=- LESS='--no-init --RAW-CONTROL-CHARS --ignore-case --use-color --LONG-PROMPT --chop-long-lines --quit-on-intr --quit-if-one-screen'

# bash
HISTSIZE='' HISTFILESIZE='' # 不限制历史记录数量
HISTTIMEFORMAT='%F %T ' # 历史记录显示执行时间
HISTCONTROL=ignoredups # 不保存重复的历史记录
PROMPT_COMMAND='history -a' # 立即更新历史记录
shopt -s histappend # 不覆盖历史记录
shopt -s checkwinsize # 自动检测窗口大小
shopt -s extglob # 更多匹配操作符
shopt -s globstar # ** 遍历操作符
set +H # 禁用历史记录扩展

# color
alias ls='ls -hF --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto -ur'

# alias
alias l="ls -lA --time-style='+%Y-%m-%d %H:%M:%S'"
alias h='history'
alias br='broot -ds'
alias lsport='lsof -i4 -i6 -nP | grep LISTEN'
EOF
install_dest home/inputrc <<'EOF'
# 启用括号粘贴模式
set enable-bracketed-paste on
# 不要响铃而是显示视觉效果
set bell-style visible
# 立即显示补全
set show-all-if-ambiguous on
set show-all-if-unmodified on
# 始终进行补全
set skip-completed-text on
# 自动补全忽略大小写
set completion-ignore-case on
# 自动补全视 - _ 为相同
set completion-map-case on
# 自动补全忽略 . 开头的文件
set match-hidden-files off
# 自动补全指向目录的符号链接时最后加上 /
set mark-symlinked-directories on
# 自动补全显示文件状态
set visible-stats on
# 自动补全显示文件类型的颜色
set colored-stats on
# 自动补全使用颜色区分已输入的前缀
set colored-completion-prefix on
# 历史记录保存光标位置
set history-preserve-point on

# Esc,Esc 删除全部内容
"\e\e": kill-whole-line
# Ctrl+左 光标向前移动一个单词
"\e[1;5D": backward-word
# Ctrl+右 光标向后移动一个单词
"\e[1;5C": forward-word
# PgUp 光标向前移动一个单词
"\e[5~": backward-word
# PgDn 光标向后移动一个单词
"\e[6~": forward-word
# Ctrl+上 根据已有输入向前查找历史记录
"\e[1;5A": history-search-backward
# Ctrl+下 根据已有输入向后查找历史记录
"\e[1;5B": history-search-forward
# Ctrl+Backspace 删除前一个单词
"\e[3;5~": kill-word
# Ctrl+Delete 删除后一个单词
"\C-_": backward-kill-word
# Ctrl+Shift+Backspace 删除光标之前所有
"\xC2\x9F": backward-kill-line
# Ctrl+Shift+Delete 删除光标之后所有
"\e[3;6~": kill-line
# Alt+Backspace 撤销
"\e\d": undo
EOF

# config
# htop
install_dest config/htop/htoprc 444 </dev/null
# btop
install_dir  config/btop/themes 711
install_dest config/btop/btop.conf <<'EOF'
proc_gradient = False
proc_filter_kernel = True
proc_tree = True
EOF
# broot
install_dir  config/broot/launcher 711
install_dest config/broot/launcher/refused 444 </dev/null
install_dest config/broot/conf.hjson 444 <<'EOF'
// 默认启动参数
default_flags: -hip --sort-by-type-dirs-first
// 内容搜索最大文件大小
content_search_max_file_size: 10MB
// 日期格式
date_time_format: %Y-%m-%d %H:%M:%S
// 使用三角标记聚焦行
show_selection_mark: true
// 快捷键
verbs: [
    {
        key: Home
        execution: ":select_first"
    }
    {
        key: End
        execution: ":select_last"
    }
    {
        key: Ctrl-Down
        execution: ":back"
    }
    {
        key: Ctrl-d
        execution: ":quit"
    }
    {
        key: Ctrl-x
        execution: ":quit"
    }
    {
        key: Ctrl-e
        execution: ":toggle_tree"
    }
    {
        key: F4
        execution: ":toggle_stage"
    }
    {
        key: Ctrl-b
        shortcut: b
        invocation: bash
        execution: "bash"
        set_working_dir: true
        leave_broot: false
    }
    {
        shortcut: e
        invocation: edit
        execution: "micro +{line} {file}"
        apply_to: file
        leave_broot: false
    }
    {
        key: enter
        execution: ":edit"
        apply_to: text_file
    }
]
EOF
# micro
install_dir  config/micro/buffers 711
install_dir  config/micro/backups 711
install_dest config/micro/settings.json 444 <<'EOF'
{
    "pluginchannels": [], // 不加载远程插件列表
    "savehistory": false, // 不保存历史命令
    "statusformatl": "  $(filename) $(modified)", // 状态栏左侧文本
    "statusformatr": "$(opt:filetype) | $(opt:fileformat) | $(opt:encoding) | $(line),$(col) | $(lines) 行 $(percentage)%  ", // 状态栏右侧文本
    "scrollbar": true, // 显示滚动条
    "clipboard": "terminal", // 剪切板使用 OSC 52
    "fileformat": "unix", // 文件换行格式
    "hlsearch": true, // 高亮所有搜索匹配
    "hltrailingws": true, // 高亮尾随空格
    "diffgutter": true, // 提示已更改行
    "tabstospaces": true // Tab 键入空格
}
EOF
install_dest config/micro/bindings.json 444 <<'EOF'
{
    "CtrlLeft"   : "SelectLeft",
    "CtrlRight"  : "SelectRight",
    "CtrlUp"     : "SelectUp",
    "CtrlDown"   : "SelectDown",
    "CtrlHome"   : "SelectToStartOfText",
    "CtrlEnd"    : "SelectToEndOfLine",
    "AltHome"    : "CursorStart",
    "AltEnd"     : "CursorEnd",
    "CtrlAltHome": "SelectToStart",
    "CtrlAltEnd" : "SelectToEnd",
    "Ctrl-g": "JumpLine",
    "Alt-," : "FindPrevious",
    "Alt-." : "FindNext",
    "Alt-e" : "CommandMode",
    "Alt-m" : "command-edit:setlocal filetype ",
    "Ctrl-d": "Quit"
}
EOF

# setup
install_setup <<'EOF'
# etc
ln -vsf {${dest},}/etc/ssl/certs/ca-certificates.crt
EOF
