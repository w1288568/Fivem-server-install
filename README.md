> 中文 | [English](README-en.md)

# FiveM 服务端一键部署脚本

三个脚本覆盖主流平台，快速部署 FiveM 服务端：

| 文件 | 平台 | 架构 | 备注 |
|------|------|------|------|
| `FiveM-server-install-Linux-ARM.sh` | Ubuntu 20.04/22.04/24.04 | aarch64 | 通过 FEX-Emu 模拟 x86 |
| `FiveM-server-install-Linux-x86.sh` | Ubuntu / Debian / CentOS / Rocky / Alma / Fedora / Arch | x86_64 | 原生运行 |
| `FiveM-server-install-Windows.ps1` | Windows Server 2016+ / Win10+ | AMD64 | 需 PowerShell 5.1+ |

## 功能

- **10 项交互菜单**：安装、启动、状态/日志、编辑配置、防火墙、更新核心、卸载、txAdmin 配置
- **txAdmin 支持**：可选 MariaDB/MySQL 数据库安装、端口 40120 放行、面板访问
- **更新回滚**：更新核心时自动备份，失败恢复
- **防火墙管理**：检测并一键添加缺失的端口规则（30120 游戏端口 + 40120 管理端口）
- **多发行版兼容**（Linux x86）：自动识别包管理器和防火墙工具

## 使用

```bash
# Linux
chmod +x FiveM-server-install-Linux-x86.sh
./FiveM-server-install-Linux-x86.sh

# Windows（以管理员身份运行）
.\FiveM-server-install-Windows.ps1
```

## 前置条件

- 到 [Cfx.re Keymaster](https://keymaster.fivem.net/) 申请 License Key
- 服务器公网 IP 需放行端口 30120（TCP+UDP）
- GTA V 经典版（Legacy）游戏文件（增强版暂不支持）

## 参考

- [Cfx.re Forum: Deploying a FiveM server in Ubuntu on aarch64/ARM64 machine](https://forum.cfx.re/t/deploying-a-fivem-server-in-ubuntu-on-aarch64-arm64-machine/5185384)
