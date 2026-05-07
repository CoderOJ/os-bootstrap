# OS Bootstrap

一个 Debian Linux 系统引导工具，自动化完成从零开始创建完整配置的 Debian 系统。支持磁盘分区、文件系统创建、系统安装和引导加载器配置。

## 快速开始

⚠️ **警告：以下操作会删除目标磁盘上的所有数据！**

### 完整安装（推荐）

自动安装依赖、分区、格式化、引导系统：

```bash
# 完成所有安装步骤（会提示确认分区操作）
make target/all DISK=/dev/sdX

# 使用 QEMU 测试启动
make test/boot DISK=/dev/sdX
```

### 使用其他 Debian 版本

```bash
make target/all DISK=/dev/sdX DEBIAN_VERSION=bookworm
```

## 功能特性

- **GPT 分区**：EFI 系统分区 (1GB) + Btrfs 根分区
- **Btrfs 文件系统**：优化的子卷布局（`/home`, `/var`, `/opt` 等）
- **systemd-boot**：现代 UEFI 引导加载器，使用 `kernel-install` 自动维护内核启动项
- **cloud-init**：自动化初始系统配置
- **辅助脚本**：NVIDIA 驱动、mDNS、LDAP 客户端配置

## 系统配置

- **APT 镜像源**：使用清华大学镜像（`apt/sources.list.template`）
- **cloud-init**：NoCloud 数据源配置（`cloud-init/nocloud/`）
- **systemd-boot**：引导加载器配置（`systemd-boot/loader/`），内核条目由目标系统的 `kernel-install` 生成

## 辅助脚本

安装后可用的配置脚本（位于 `/home/cscg/scripts/`）：

- `debian-nvidia-driver.sh` - 安装 NVIDIA 驱动
- `enable-mdns.sh` - 启用 mDNS 支持
- `ldap-sssd-client.sh` - 配置 LDAP 认证

## 高级用法

### 分步执行

如需手动控制每个步骤：

```bash
# 1. 分区磁盘
make target/partition-disk DISK=/dev/sdX

# 2. 格式化分区
make target/format DISK=/dev/sdX

# 3. 创建 Btrfs 子卷
make target/subvolume DISK=/dev/sdX

# 4. 引导系统并安装引导加载器、生成初始内核启动项
make target/bootstrap DISK=/dev/sdX
make target/systemd-boot DISK=/dev/sdX
```

### 其他测试命令

```bash
# 进入 chroot 环境
make test/chroot DISK=/dev/sdX

# 运行 Btrfs 清理
make test/scrub DISK=/dev/sdX
```

### 工具命令

```bash
# 挂载/卸载分区
make util/mount DISK=/dev/sdX
make util/unmount

# 清理构建产物
make clean
```

## 项目结构

```
.
├── Makefile                      # 构建系统
├── apt/                          # APT 配置
├── cloud-init/                   # cloud-init 配置
├── scripts/                      # 安装后配置脚本
└── systemd-boot/                 # 引导加载器配置和安装辅助脚本
```

## 故障排查

**分区表问题**：运行 `partprobe /dev/sdX` 或重启系统

**挂载问题**：重新分区前确保卸载所有文件系统
```bash
make util/unmount-kernelfs
make util/unmount
```

**QEMU 启动问题**：确保已安装 OVMF 固件 (`apt install ovmf`)
