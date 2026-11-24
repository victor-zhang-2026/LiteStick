# LiteStick

LiteStick — Stick it here for later.
随手一贴，随时取用。

LiteStick 是一款 macOS 原生轻量级便利贴工具。桌面常驻一枚暖黄色悬浮球，鼠标移入即展开便利贴，随手粘贴或输入文字，之后随时回看、一键复制。永远只有一张便利贴：无需创建、无需命名、打开即用。

## 核心功能

- **悬浮球**：常驻桌面，跨应用可见，可自由拖动，自动记忆位置。
- **Hover 展开**：鼠标移入悬浮球自动展开便利贴；移开自动收起（不影响正在编辑的状态）。
- **纯文本编辑**：支持中文输入法、多行、全选、撤销/重做，所有粘贴按纯文本处理，长文本内部滚动。
- **复制 / Copy**：一键将全部正文复制到剪贴板，保留换行与空格。
- **固定 / Pin**：固定后浮窗常驻桌面，方便一边工作一边查看。
- **清空 / Clear**：一键清空全部文字，无需确认；清空后可通过撤销恢复。
- **本地持久化**：正文、悬浮球位置、语言、主题自动保存，重启不丢失。
- **中英双语**：右键悬浮球切换语言，即时生效。
- **浅色 / 深色 / 跟随系统**：右键悬浮球切换外观。

## 使用方式

1. 启动 LiteStick，桌面出现暖黄色便利贴悬浮球。
2. 鼠标移入悬浮球，便利贴浮窗展开。
3. 点击正文区域开始输入或粘贴文字。
4. 点击工具栏按钮：复制（Copy）、固定（Pin）、清空（Clear）、收起（×）。
5. 鼠标移开浮窗时，预览会自动收起。编辑中点击浮窗外也会收起。开启 Pin 后保持展开。
6. 右键点击悬浮球可切换语言、外观、查看关于及退出。

## 系统要求

- macOS 14.0 或更高版本
- GitHub Release 安装包适用于 Apple Silicon Mac

## 安装与卸载

安装：从 [GitHub Releases](https://github.com/victor-zhang-2026/LiteStick/releases/latest) 下载并解压 ZIP。将 `LiteStick.app` 拖入「应用程序」文件夹，双击打开。

卸载：退出 LiteStick 后，将 `LiteStick.app` 移入废纸篓即可。

## 本地数据存储

所有数据保存在本机 `UserDefaults`（bundle id `io.github.victor-zhang-2026.litestick`）中，包括便利贴正文、悬浮球位置、语言与主题偏好。不上传任何内容，不进行云端同步，不读取系统剪贴板历史。将应用移入废纸篓后，macOS 仍可能保留偏好设置与便签正文。

## 构建方式

```bash
./scripts/build-app.sh            # 构建、组装并签名 LiteStick.app
python3 scripts/generate-icon.py  # 重新生成 App Icon（需要 Pillow）
```

构建产物位于 `build/LiteStick.app`。本项目为 Swift Package，无需 Xcode，Command Line Tools 即可构建。

---

LiteStick 永远只保留一张便利贴。

Hover → Edit → Copy → Clear

Less is more.
