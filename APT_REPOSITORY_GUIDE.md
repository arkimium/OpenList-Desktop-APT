# OpenList APT Repository Guide

本指南说明如何使用OpenList的APT仓库功能，实现通过`apt`命令直接安装和更新OpenList。

## 🚀 快速开始

### 方法1：一键安装（推荐）
```bash
curl -fsSL https://github.com/YOUR_USERNAME/OpenList-DEB/releases/latest/download/install-apt.sh | bash
```

### 方法2：手动配置（现代系统 - Ubuntu 22.04+, Debian 12+）
```bash
echo "Types: deb
URIs: https://gh.pry.assets.991081.xyz/https://github.com/YOUR_USERNAME/OpenList-DEB/releases/latest/download/
Suites: ./
Trusted: yes" | sudo tee /etc/apt/sources.list.d/openlist.sources

sudo apt update
sudo apt install openlist
```

### 方法3：手动配置（传统系统）
```bash
echo "deb [trusted=yes] https://gh.pry.assets.991081.xyz/https://github.com/YOUR_USERNAME/OpenList-DEB/releases/latest/download/ ./" | sudo tee /etc/apt/sources.list.d/openlist.list

sudo apt update
sudo apt install openlist
```

## 📋 工作原理

这个APT仓库系统的工作原理如下：

1. **��动构建**：当OpenList主项目发布新版本时，GitHub Actions会自动构建DEB包
2. **生成APT元数据**：构建过程中会生成`Packages`和`Release`文件
3. **发布到Release**：所有文件（DEB包、APT元数据、配置文件）都会上传到GitHub Release
4. **代理访问**：使用`gh.pry.assets.991081.xyz`代理GitHub Release，使APT能够正确访问

## 📁 生成的文件

每次发布都会包含以下文件：

### DEB包文件
- `openlist_VERSION-1_amd64.deb` - AMD64架构的DEB包
- `openlist_VERSION-1_arm64.deb` - ARM64架构的DEB包

### APT仓库元数据
- `Packages` - 包信息文件
- `Packages.gz` - 压缩的包信息文件
- `Release` - 仓库元数据和校验和

### 配置文件
- `openlist.sources` - 现代APT源配置文件
- `openlist.list` - 传统APT源配置文件
- `install-apt.sh` - 自动安装脚本
- `README-APT.md` - APT仓库使用说明

## 🔧 使用示例

### 安装OpenList
```bash
# 添加仓库后
sudo apt update
sudo apt install openlist
```

### 更新OpenList
```bash
sudo apt update
sudo apt upgrade openlist
```

### 查看可用版本
```bash
apt list --upgradable | grep openlist
```

### 服务管理
```bash
# 查看服务状态
sudo systemctl status openlist

# 启动/停止/重启服务
sudo systemctl start openlist
sudo systemctl stop openlist
sudo systemctl restart openlist

# 查看日志
sudo journalctl -u openlist -f
```

## 🗑️ 卸载

### 移除软件包但保留数据
```bash
sudo apt remove openlist
```

### 完全移除（包括数据）
```bash
sudo apt purge openlist
```

### 移除APT仓库
```bash
# 移除现代格式的源
sudo rm -f /etc/apt/sources.list.d/openlist.sources

# 移除传统格式的源
sudo rm -f /etc/apt/sources.list.d/openlist.list

# 更新包列表
sudo apt update
```

## 🛠️ 技术细节

### APT源配置格式

#### 现代格式（推荐）
```
Types: deb
URIs: https://gh.pry.assets.991081.xyz/https://github.com/YOUR_USERNAME/OpenList-DEB/releases/latest/download/
Suites: ./
Trusted: yes
```

#### 传统格式
```
deb [trusted=yes] https://gh.pry.assets.991081.xyz/https://github.com/YOUR_USERNAME/OpenList-DEB/releases/latest/download/ ./
```

### 代理URL说明

使用`gh.pry.assets.991081.xyz`代理的原因：
- GitHub Release的直接URL不完全兼容APT协议
- 代理服务器提供了APT所需的HTTP头和响应格式
- 确保APT能够正确下载和验证包文件

### 文件位置

安装后的文件位置：
- **二进制文件**: `/var/lib/openlist/openlist`
- **工作目录**: `/var/lib/openlist`
- **服务文件**: `/usr/lib/systemd/system/openlist.service`
- **命令链接**: `/usr/bin/openlist`
- **用户**: `openlist`
- **组**: `openlist`

## 🔍 故障排除

### 仓库无法访问
```bash
# 检查网络连接
curl -I https://gh.pry.assets.991081.xyz/

# 检查GitHub Release是否存在
curl -I https://github.com/YOUR_USERNAME/OpenList-DEB/releases/latest/download/Packages
```

### 包安装失败
```bash
# 修复依赖问题
sudo apt-get install -f

# 检查系统架构
dpkg --print-architecture

# 手动下载并安装
wget https://github.com/YOUR_USERNAME/OpenList-DEB/releases/latest/download/openlist_*_amd64.deb
sudo dpkg -i openlist_*_amd64.deb
```

### 服务启动失败
```bash
# 查看详细日志
sudo journalctl -u openlist -f

# 检查二进制文件权限
ls -la /var/lib/openlist/openlist

# 手动测试二进制文件
sudo -u openlist /var/lib/openlist/openlist --help
```

## 📝 自定义配置

### 修改仓库URL

如果需要使用不同的代理或仓库：

1. 编辑源文件：
```bash
sudo nano /etc/apt/sources.list.d/openlist.sources
```

2. 修改URIs行：
```
URIs: https://your-custom-proxy.com/path/to/repo/
```

3. 更新包列表：
```bash
sudo apt update
```

### 使用特定版本

如果需要安装特定版本而不是最新版本：

1. 修改URIs指向特定的release：
```
URIs: https://gh.pry.assets.991081.xyz/https://github.com/YOUR_USERNAME/OpenList-DEB/releases/download/v4.0.8/
```

2. 更新并安装：
```bash
sudo apt update
sudo apt install openlist
```

## 🔄 自动更新

### 启用自动更新
```bash
# 安装unattended-upgrades
sudo apt install unattended-upgrades

# 配置自动更新
sudo dpkg-reconfigure unattended-upgrades
```

### 手动检查更新
```bash
# 检查可用更新
sudo apt update
apt list --upgradable

# 仅更新OpenList
sudo apt upgrade openlist
```

## 📞 支持

- **主项目问题**: https://github.com/OpenListTeam/OpenList/issues
- **DEB包问题**: https://github.com/YOUR_USERNAME/OpenList-DEB/issues
- **文档**: https://github.com/YOUR_USERNAME/OpenList-DEB/blob/main/README.md

---

**注意**: 请将文档中的`YOUR_USERNAME`替换为实际的GitHub用户名或组织名。