#!/bin/bash

# ================================
#  FiveM 服务端管理脚本
#  适用于 x86_64 Linux
#  支持 Ubuntu / Debian / CentOS / Rocky / AlmaLinux / Fedora / Arch
# ================================

RED='\033[0;31m';    GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

BASE_DIR="$HOME/FXServer"
SERVER_DIR="$BASE_DIR/server"
DATA_DIR="$BASE_DIR/server-data"
CFG_PATH="$DATA_DIR/server.cfg"

# ================================
#  发行版检测
# ================================
detect_distro() {
    if [ ! -f /etc/os-release ]; then
        err "无法检测操作系统"; exit 1
    fi
    . /etc/os-release
    info "系统：$ID $VERSION_ID (x86_64)"

    case "$ID" in
        ubuntu|debian)
            PKG_INSTALL="apt install -y"
            PKG_UPDATE="apt update"
            FIREWALL_CMD="ufw"
            IPTABLES_SAVE="apt install -y iptables-persistent 2>/dev/null; netfilter-persistent save"
            BASE_PKGS="wget curl git xz-utils screen tar nano"
            DB_INSTALL="apt install -y mariadb-server"
            DB_SERVICE="mariadb"
            ;;
        centos|rocky|almalinux|rhel)
            if command -v dnf &>/dev/null; then
                PKG_INSTALL="dnf install -y"; PKG_UPDATE="dnf check-update"
            else
                PKG_INSTALL="yum install -y"; PKG_UPDATE="yum check-update"
            fi
            FIREWALL_CMD="firewall-cmd"
            IPTABLES_SAVE="dnf install -y iptables-services 2>/dev/null; service iptables save"
            BASE_PKGS="wget curl git xz screen tar nano"
            DB_INSTALL="dnf install -y mariadb-server"
            DB_SERVICE="mariadb"
            if command -v dnf &>/dev/null; then
                dnf install -y epel-release 2>/dev/null || true
            else
                yum install -y epel-release 2>/dev/null || true
            fi
            ;;
        fedora)
            PKG_INSTALL="dnf install -y"; PKG_UPDATE="dnf check-update"
            FIREWALL_CMD="firewall-cmd"
            IPTABLES_SAVE="dnf install -y iptables-services 2>/dev/null; service iptables save"
            BASE_PKGS="wget curl git xz screen tar nano"
            DB_INSTALL="dnf install -y mariadb-server"
            DB_SERVICE="mariadb"
            ;;
        arch)
            PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Syu"
            FIREWALL_CMD=""
            IPTABLES_SAVE=""
            BASE_PKGS="wget curl git xz screen tar nano"
            DB_INSTALL="pacman -S --noconfirm mariadb"
            DB_SERVICE="mariadb"
            ;;
        *)
            err "未适配的发行版：$ID"; exit 1 ;;
    esac

    ok "环境检查通过：$ID $VERSION_ID (x86_64)"
}

# ================================
#  防火墙辅助
# ================================
add_firewall_rule() {
    local port=$1 proto=$2 desc=$3
    if command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --add-port=$port/$proto --permanent 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        ok "$desc ($port/$proto) firewalld 规则已添加"
    elif command -v iptables &>/dev/null; then
        local chain="INPUT"
        sudo iptables -I $chain 6 -m state --state NEW -p $proto --dport $port -j ACCEPT 2>/dev/null || true
        if [ -n "$IPTABLES_SAVE" ]; then
            eval "$IPTABLES_SAVE" 2>/dev/null || true
        fi
        ok "$desc ($port/$proto) iptables 规则已添加"
    else
        warn "未检测到防火墙工具，请手动放行端口 $port"
    fi
}

check_firewall_rule() {
    local port=$1 proto=$2
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --list-ports 2>/dev/null | grep -q "$port/$proto" && return 0 || return 1
    elif command -v iptables &>/dev/null; then
        sudo iptables -L INPUT -n 2>/dev/null | grep -q "$proto.*dpt:$port" && return 0 || return 1
    else
        return 1
    fi
}

# ================================
#  菜单
# ================================
show_menu() {
    clear
    echo -e "${BLUE}==================================${NC}"
    echo -e "${BLUE}  FiveM 服务端管理脚本${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo
    echo "  1.  安装 FiveM 服务端"
    echo "  2.  启动服务端"
    echo "  3.  查看运行状态 / 最近日志"
    echo "  4.  重新编辑 server.cfg"
    echo "  5.  检查防火墙 / 端口放行"
    echo "  6.  更新服务端核心"
    echo "  7.  卸载 FiveM 服务端"
    echo "  8.  配置 txAdmin 环境"
    echo "  9.  打开 txAdmin 面板"
    echo "  0.  退出脚本"
    echo
}

# ================================
#  安装
# ================================
install_fivem() {
    echo
    info "===== 安装 FiveM 服务端 ====="

    info "请先在 https://keymaster.fivem.net/ 注册并获取 License Key"
    read -rp "请输入你的 FiveM License Key: " LICENSE_KEY
    [ -z "$LICENSE_KEY" ] && { err "License Key 不能为空"; return; }

    echo
    info "请打开以下链接，找到最新版 fx.tar.xz："
    info "  https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
    read -rp "请输入 fx.tar.xz 的完整下载链接: " ARTIFACTS_URL
    [ -z "$ARTIFACTS_URL" ] && { err "下载链接不能为空"; return; }

    echo
    info "更新系统并安装依赖..."
    eval "$PKG_UPDATE" || true
    eval "$PKG_INSTALL $BASE_PKGS"
    ok "系统依赖安装完成"

    info "开放 30120 端口..."
    add_firewall_rule 30120 tcp "游戏端口"
    add_firewall_rule 30120 udp "游戏端口"
    warn "如使用云服务商，请同时在安全组中放行端口 30120"

    mkdir -p "$SERVER_DIR"
    info "下载 FiveM 服务端核心..."
    wget "$ARTIFACTS_URL" -O /tmp/fx.tar.xz || { err "下载失败"; return; }
    info "解压缩..."
    tar xf /tmp/fx.tar.xz -C "$SERVER_DIR" && rm /tmp/fx.tar.xz || { err "解压失败"; return; }
    ok "服务端核心解压完成"

    cd "$BASE_DIR"
    if [ -d "$DATA_DIR" ]; then
        info "server-data 目录已存在，更新中..."
        cd "$DATA_DIR" && git pull && cd "$BASE_DIR"
    else
        git clone https://github.com/citizenfx/cfx-server-data.git server-data
    fi
    ok "服务端数据模板已就绪"

    info "生成 server.cfg..."
    cat > "$CFG_PATH" << CFGEOF
# ================================
#  FiveM 服务器配置文件
# ================================

endpoint_add_tcp "0.0.0.0:30120"
endpoint_add_udp "0.0.0.0:30120"

ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap
ensure rconlog

sv_scriptHookAllowed 0

#set rcon_password "你的强密码"

sets tags "default"
sets locale "root-AQ"

sv_hostname "我的 FiveM 服务器"
sets sv_projectName "我的 FiveM 项目"
sets sv_projectDesc "FiveM 服务器"
sv_enforceGameBuild 2699

#exec server_internal.cfg
#load_server_icon myLogo.png
set temp_convar "hello world!"

#sv_master1 ""

add_ace group.admin command allow
add_ace group.admin command.quit deny
add_principal identifier.fivem:1 group.admin

set onesync on
sv_maxclients 48

set steam_webApiKey ""

sv_licenseKey "$LICENSE_KEY"

# ================================
#  配置结束
# ================================
CFGEOF
    ok "server.cfg 已生成，正在打开编辑器..."
    echo
    warn "请检查和修改：sv_hostname / add_principal / sets locale"
    read -rp "按 Enter 键打开 nano 编辑 server.cfg ..."
    nano "$CFG_PATH"
    ok "server.cfg 配置完成"

    echo
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}  FiveM 服务端安装完成！${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo
    echo "启动命令："
    echo "  cd $DATA_DIR && $SERVER_DIR/run.sh +exec server.cfg"
    echo
    echo "后台运行："
    echo "  screen -dmS fivem bash -c \"cd $DATA_DIR && $SERVER_DIR/run.sh +exec server.cfg\""
    echo
    echo "或使用本脚本选项 2 直接启动"
    echo
    info "验证：启动日志中出现 Public endpoint is ... 即注册成功"

    read -rp "按 Enter 键返回菜单"
}

# ================================
#  启动服务端
# ================================
start_fivem() {
    local from_menu=${1:-true}
    [ ! -f "$SERVER_DIR/run.sh" ] && { err "未找到服务端文件，请先安装"; [ "$from_menu" = true ] && read -rp "按 Enter 键返回菜单"; return; }
    [ ! -f "$CFG_PATH" ] && { err "未找到 server.cfg，请先安装"; [ "$from_menu" = true ] && read -rp "按 Enter 键返回菜单"; return; }

    if pgrep -x "FXServer" > /dev/null 2>&1; then
        warn "服务端已在运行中 (PID: $(pgrep -x FXServer))"
        read -rp "是否重启？(y/n): " r
        [ "$r" != "y" ] && [ "$r" != "Y" ] && return
        pkill -x FXServer 2>/dev/null; sleep 2
    fi

    info "正在启动 FiveM 服务端..."
    cd "$DATA_DIR"
    screen -dmS fivem bash -c "$SERVER_DIR/run.sh +exec server.cfg"
    sleep 1

    if pgrep -x "FXServer" > /dev/null 2>&1; then
        ok "服务端已启动 (screen -r fivem 可查看日志)"
    else
        err "启动失败，请检查配置"
    fi
    [ "$from_menu" = true ] && read -rp "按 Enter 键返回菜单"
}

# ================================
#  查看状态 / 最近日志
# ================================
check_status() {
    if pgrep -x "FXServer" > /dev/null 2>&1; then
        ok "服务端状态：运行中 (PID: $(pgrep -x FXServer))"
    else
        warn "服务端状态：未运行"
    fi

    echo
    info "最近日志："
    local log_dir="$DATA_DIR/logs"
    if [ -d "$log_dir" ]; then
        local latest=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            echo "  文件: $latest"
            echo "  大小: $(du -h "$latest" | cut -f1)"
            echo "  修改时间: $(stat -c '%y' "$latest" 2>/dev/null || date -r "$latest")"
            echo
            echo "  -- 末尾 20 行 --"
            tail -20 "$latest"
        else
            info "  logs 目录为空"
        fi
    else
        info "  logs 目录不存在，服务端尚未产生日志"
    fi

    read -rp "按 Enter 键返回菜单"
}

# ================================
#  编辑 server.cfg
# ================================
edit_config() {
    [ ! -f "$CFG_PATH" ] && { err "未找到 server.cfg，请先安装"; read -rp "按 Enter 键返回菜单"; return; }
    info "正在打开 server.cfg ..."
    nano "$CFG_PATH"
    ok "编辑完成"
    read -rp "按 Enter 键返回菜单"
}

# ================================
#  检查防火墙
# ================================
check_firewall() {
    info "检查防火墙规则..."
    echo
    info "游戏端口 30120："
    if check_firewall_rule 30120 tcp; then ok "  TCP 30120: 已放行"; else warn "  TCP 30120: 未配置"; fi
    if check_firewall_rule 30120 udp; then ok "  UDP 30120: 已放行"; else warn "  UDP 30120: 未配置"; fi
    echo
    info "管理端口 40120（txAdmin）："
    if check_firewall_rule 40120 tcp; then ok "  TCP 40120: 已放行"; else warn "  TCP 40120: 未配置"; fi

    echo
    read -rp "是否添加缺失的规则？(y/n): " r
    if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
        add_firewall_rule 30120 tcp "游戏端口" 2>/dev/null
        add_firewall_rule 30120 udp "游戏端口" 2>/dev/null
        add_firewall_rule 40120 tcp "管理端口" 2>/dev/null
    fi
    read -rp "按 Enter 键返回菜单"
}

# ================================
#  更新服务端核心
# ================================
update_core() {
    [ ! -d "$SERVER_DIR" ] && { err "尚未安装服务端，请先使用选项 1"; read -rp "按 Enter 键返回菜单"; return; }

    echo
    info "===== 更新服务端核心 ====="
    warn "此操作将替换 server 目录，server-data 保持不变"
    echo
    info "请打开以下链接，找到最新版 fx.tar.xz："
    info "  https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
    read -rp "请输入 fx.tar.xz 的完整下载链接: " ARTIFACTS_URL
    [ -z "$ARTIFACTS_URL" ] && { err "下载链接不能为空"; return; }

    local backup_dir="$BASE_DIR/server.backup.$(date +%Y%m%d%H%M%S)"
    info "备份当前 server 目录..."
    mv "$SERVER_DIR" "$backup_dir"

    mkdir -p "$SERVER_DIR"
    info "下载最新服务端核心..."
    wget "$ARTIFACTS_URL" -O /tmp/fx.tar.xz || {
        err "下载失败"
        info "正在恢复备份..."
        rm -rf "$SERVER_DIR"; mv "$backup_dir" "$SERVER_DIR"
        read -rp "按 Enter 键返回菜单"; return
    }

    info "解压缩..."
    tar xf /tmp/fx.tar.xz -C "$SERVER_DIR" && rm /tmp/fx.tar.xz || {
        err "解压失败"
        info "正在恢复备份..."
        rm -rf "$SERVER_DIR"; mv "$backup_dir" "$SERVER_DIR"
        read -rp "按 Enter 键返回菜单"; return
    }

    rm -rf "$backup_dir"
    ok "服务端核心更新完成"
    read -rp "按 Enter 键返回菜单"
}

# ================================
#  卸载
# ================================
uninstall_fivem() {
    [ ! -d "$BASE_DIR" ] && { err "未检测到 FiveM 安装目录"; read -rp "按 Enter 键返回菜单"; return; }

    warn "===== 卸载 FiveM 服务端 ====="
    warn "将删除以下目录："
    warn "  $BASE_DIR"
    echo

    if pgrep -x "FXServer" > /dev/null 2>&1; then
        warn "服务端正在运行，卸载前将自动关闭"
    fi

    read -rp "确定要卸载吗？此操作不可恢复！(yes/no): " r
    [ "$r" != "yes" ] && { info "已取消"; read -rp "按 Enter 键返回菜单"; return; }

    pkill -x FXServer 2>/dev/null; sleep 1
    rm -rf "$BASE_DIR"
    ok "卸载完成，$BASE_DIR 已删除"

    # 清理 screen 会话
    screen -S fivem -X quit 2>/dev/null || true

    read -rp "按 Enter 键返回菜单"
}

# ================================
#  配置 txAdmin
# ================================
config_txadmin() {
    [ ! -f "$SERVER_DIR/run.sh" ] && { err "请先安装 FiveM 服务端（选项 1）"; read -rp "按 Enter 键返回菜单"; return; }

    echo
    info "===== 配置 txAdmin ====="
    echo

    info "txAdmin 需要数据库支持，选择要安装的数据库："
    echo "  1. MariaDB（推荐，资源占用低）"
    echo "  2. MySQL"
    read -rp "请输入选项 (1-2)，默认 1: " db_choice
    if [ -z "$db_choice" ] || [ "$db_choice" = "1" ]; then
        local db_name="MariaDB"
        local db_pkg_cmd="$DB_INSTALL"
        local db_bin="mariadbd"
        local db_service="mariadb"
    else
        local db_name="MySQL"
        local db_pkg_cmd=$(echo "$DB_INSTALL" | sed 's/mariadb-server/mysql-server/')
        local db_bin="mysqld"
        local db_service="mysql"
    fi

    info "检查 $db_name 安装状态..."
    local db_installed=false
    if command -v "$db_bin" &>/dev/null; then
        db_installed=true
    elif systemctl is-active --quiet "$db_service" 2>/dev/null; then
        db_installed=true
    fi

    if ! $db_installed; then
        warn "未检测到 $db_name"
        read -rp "是否安装 $db_name？(y/n): " r
        if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
            info "正在安装 $db_name ..."
            eval "$db_pkg_cmd"
            if [ $? -eq 0 ]; then
                ok "$db_name 安装完成"
                # 启动并启用服务
                if command -v systemctl &>/dev/null; then
                    sudo systemctl enable "$db_service" 2>/dev/null || true
                    sudo systemctl start "$db_service" 2>/dev/null || true
                fi
                warn "请手动配置数据库 root 密码"
            else
                err "安装失败，请手动安装"
            fi
        fi
    else
        ok "$db_name 已就绪"
    fi

    echo
    info "开放 40120 端口..."
    add_firewall_rule 40120 tcp "txAdmin 管理端口"

    echo
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}  txAdmin 配置指引${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo
    info "1. 确保数据库服务已启动"
    info "2. 使用选项 2 启动 FiveM 服务端"
    info "3. 通过浏览器访问 http://你的服务器IP:40120"
    info "4. 在 txAdmin 网页向导中配置服务器"
    info "5. 建议在云服务商安全组中也放行 40120"
    echo

    read -rp "按 Enter 键返回菜单"
}

# ================================
#  打开 txAdmin 面板（Linux 版打印地址）
# ================================
open_txadmin() {
    if ! pgrep -x "FXServer" > /dev/null 2>&1; then
        warn "服务端未运行，请先使用选项 2 启动"
        read -rp "是否立即启动？(y/n): " r
        if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
            start_fivem false
            if ! pgrep -x "FXServer" > /dev/null 2>&1; then
                return
            fi
        else
            return
        fi
    fi

    echo
    info "获取服务器公网 IP..."
    local ext_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "无法获取")

    info "===== txAdmin 访问信息 ====="
    echo
    if [ "$ext_ip" != "无法获取" ]; then
        ok "公网地址：http://$ext_ip:40120"
    else
        warn "公网地址：无法自动获取，请手动查询"
    fi
    ok "内网地址：http://localhost:40120"
    echo
    echo
    info "检查 txAdmin 服务状态..."
    if curl -s --max-time 3 http://localhost:40120 &>/dev/null; then
        ok "txAdmin 服务正常运行 ✓"
    else
        warn "txAdmin 服务未响应，可能原因："
        warn "  - 服务端尚未完全启动（等待 10-30 秒后重试）"
        warn "  - server.cfg 中未启用 txAdmin"
        warn "  - 端口 40120 被其他程序占用"
    fi

    read -rp "按 Enter 键返回菜单"
}

# ================================
#  主循环
# ================================
detect_distro

while true; do
    show_menu
    read -rp "请输入选项 (0-9): " choice
    case "$choice" in
        1) install_fivem ;;
        2) start_fivem true ;;
        3) check_status ;;
        4) edit_config ;;
        5) check_firewall ;;
        6) update_core ;;
        7) uninstall_fivem ;;
        8) config_txadmin ;;
        9) open_txadmin ;;
        0) echo "再见！"; exit 0 ;;
        *) warn "无效选项，请重新输入"; sleep 1 ;;
    esac
done
