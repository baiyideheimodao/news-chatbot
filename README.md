# Flutter Desktop Chat Demo

这是一个 Flutter 桌面示例，包含：

- 透明圆形悬浮窗（120x120）
- 鼠标拖拽移动
- 最上层窗口
- 聊天界面示例
- 新闻推送前端展示

## 运行步骤

1. 在终端进入本项目目录：

   ```powershell
   cd d:\Backup\Documents\chatbot\flutter_desktop_chat
   ```

2. 如果尚未生成桌面支持目录，请先运行：

   ```powershell
   flutter create .
   ```

3. 获取依赖：

   ```powershell
   flutter pub get
   ```

4. 运行 Windows 桌面：

   ```powershell
   flutter run -d windows
   ```

## 备注

- 当前项目使用 `window_manager` 实现悬浮窗和窗口控制。
- 要实现“真正的两个独立窗口”，可以考虑接入 `desktop_multi_window` 或类似插件，
  并用窗口 ID / 本地消息机制做通信。
