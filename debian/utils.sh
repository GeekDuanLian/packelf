#!/bin/false

# shellcheck disable=SC2034
pkg=(bash curl less grep diffutils yq-go htop broot traceroute rsync netcat-openbsd smartmontools)
bin=(/usr/bin/{bash,curl,less,grep,diff,yq,htop,broot,traceroute,rsync,nc} /usr/sbin/smartctl)
etc=(/etc/ssl/certs/ca-certificates.crt)

# bottom
curl -fsSL 'https://github.com/ClementTsang/bottom/releases/latest/download/'"bottom_${arch:?}-unknown-linux-gnu.tar.gz" |
tar -xzO btm | install /dev/stdin /usr/bin/btm
bin+=(/usr/bin/btm)

# edit
[[ "${arch}" != 'i686' ]] && {
    curl -fsSL "$( curl -fsSL 'https://api.github.com/repos/microsoft/edit/releases/latest' | yq -r '.assets[] | select(.name == "*-'"${arch:?}"'-linux-gnu.tar.gz") | .browser_download_url' )" |
    tar -xzO edit | install /dev/stdin /usr/bin/edit
    bin+=(/usr/bin/edit)
}

# home
install_dest home/bash_profile <<'EOF'
. ~/.bashrc
EOF
install_dest home/bashrc <<'EOF'
# env
export PATH='${dest:?}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export LANG='en_US.UTF-8'
export EDITOR='edit'; export VISUAL="${EDITOR}"; alias e="${EDITOR}"
export PAGER='less'
export LESSSECURE=1 LESSHISTFILE=- LESS='--RAW-CONTROL-CHARS --ignore-case --mouse --use-color --LONG-PROMPT --chop-long-lines --quit-on-intr --quit-if-one-screen'
export CURL_CA_BUNDLE='${dest:?}/etc/ssl/certs/ca-certificates.crt'
export HTOPRC='/dev/null'
# done
[[ "${-}" == *i* ]] || return 0

# bash
HISTSIZE='' HISTFILESIZE='' # 不限制历史记录数量
HISTTIMEFORMAT='%F %T ' # 历史记录显示执行时间
HISTCONTROL='ignoredups' # 不保存重复的历史记录
PROMPT_COMMAND='history -a' # 立即更新历史记录
shopt -s histappend # 不覆盖历史记录
shopt -s checkwinsize # 自动检测窗口大小
shopt -s extglob # 更多匹配操作符
shopt -s globstar # ** 遍历操作符
set +H # 禁用历史记录扩展

# PS1
[[ "${EUID}" == 0 ]] && : 31 || : 32
PS1='\[\e]0;${AssetID:+${AssetID} }\H ${PWD}\a\]\[\e[1;33m\]\t \[\e[36m\]\H \[\e[35m\]${AssetID:+${AssetID} }\[\e[34m\]\w \[\e[0;91m\]${?#0}\[\e[0m\]\n\[\e[1;'"${_}"'m\]${USER} \[\e[37m\]\$ \[\e[0m\]'

# color
alias ls='ls -hF --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto -ur'

# alias
alias ..='cd ..'
alias l="ls -la --time-style='+%Y-%m-%d %H:%M:%S'"
alias h='history'
alias lsport='lsof -i4 -i6 -nP | grep LISTEN'
zless () { zcat "${@}" | less; }
EOF
install_dest home/inputrc <<'EOF'
# 启用括号粘贴模式
set enable-bracketed-paste on
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

# esc,esc 删除全部内容
"\e\e": kill-whole-line
# ctrl+左 光标向前移动一个单词
"\e[1;5D": backward-word
# ctrl+右 光标向后移动一个单词
"\e[1;5C": forward-word
# cmd+左 光标向前移动一个单词
"\e[1;9D": backward-word
# cmd+右 光标向后移动一个单词
"\e[1;9C": forward-word
# pgup 光标向前移动一个单词
"\e[5~": backward-word
# pgdn 光标向后移动一个单词
"\e[6~": forward-word
# ctrl+上 根据已有输入向前查找历史记录
"\e[1;5A": history-search-backward
# ctrl+下 根据已有输入向后查找历史记录
"\e[1;5B": history-search-forward
# ctrl+backspace 删除前一个单词
"\e[3;5~": kill-word
# ctrl+delete 删除后一个单词
"\C-_": backward-kill-word
# Alt+Backspace 撤销
"\e\d": undo
EOF

# bottom
install_dest home/config/bottom/bottom.toml <<'EOF'
[flags]
processes.unnormalized_cpu = true
processes.default_memory_value = true
processes.process_command = true
processes.hide_k_threads = true
[styles]
theme = "nord"
[[row]]
    [[row.child]]
    type = "mem"
    [[row.child]]
    type = "cpu"
    [[row.child]]
    type = "net"
[[row]]
    ratio = 2
    [[row.child]]
    type = "proc"
    default = true
EOF
# broot
install_dest home/config/broot/launcher/refused </dev/null
install_dest home/config/broot/conf.hjson <<'EOF'
default_flags: -hip --sort-by-type-dirs-first
date_time_format: %Y-%m-%d %H:%M:%S
icon_theme: nerdfont
verbs: [
    {
        key: "home"
        execution: ":select_first"
    }
    {
        key: "end"
        execution: ":select_last"
    }
    {
        key: "ctrl-t"
        execution: ":toggle_tree"
    }
    {
        key: "ctrl-f"
        execution: ":total_search"
    }
    {
        key: "ctrl-s"
        execution: ":toggle_stage"
    }
    {
        key: "ctrl-g"
        execution: ":toggle_staging_area"
    }
    {
        invocation: "cd {path}"
        execution: ":focus {path}"
    }
    {
        invocation: "exec {cmd}"
        execution: "{cmd} {file}"
        set_working_dir: true
        leave_broot: false
    }
    {
        key: "F2"
        invocation: "mv {new_filename:file-name}"
        execution:  "mv {file} {parent}/{new_filename}"
        leave_broot: false
        auto_exec: false
    }
    {
        key: "F3"
        invocation: "cp {new_filename:file-name}"
        execution:  "cp {file} {parent}/{new_filename}"
        leave_broot: false
        auto_exec: false
    }
    {
        shortcut: "t"
        invocation: "touch {path}"
        execution:  "touch {path}"
        leave_broot: false
    }
    {
        shortcut: "s"
        invocation: "bash"
        execution:  "bash"
        set_working_dir: true
        leave_broot: false
    }
    {
        shortcut: "e"
        invocation: "edit"
        execution:  "$EDITOR +{line} {file}"
        apply_to: "file"
        leave_broot: false
    }
    {
        key: "enter"
        execution: ":edit"
        apply_to: "text_file"
    }
]
EOF
