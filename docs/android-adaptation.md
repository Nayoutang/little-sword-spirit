# Windows / Android 双端适配

横屏修复版 0.1.1：原方向值 6 允许横竖屏自动切换，已修正为 Godot `SCREEN_SENSOR_LANDSCAPE`（4），并在安卓启动时调用同名方向常量。APK 清单实际值为 `userLandscape`（11），打包脚本会检查该值；移动回归也检查横屏设置。安装 `builds/android/LittleSwordSpirit-0.1.1-landscape.apk` 可覆盖旧版，保留原有存档。尚未在真机上复验。

Android 使用横屏（支持左右翻转），以 1920×1080 保持比例缩放；宽屏手机和 16:10 平板留边，保留现有画面内容。Windows 保留原有窗口和 F11 操作。安卓使用 OpenGL Compatibility，限制为 60 FPS。

## 已接入

- 触摸模拟鼠标，复用按钮、卡牌与敌人目标操作；地图支持上下滑动。地图节点使用扩大后的点击区域，松手确认点选，拖动不选节点。
- 手机设置页隐藏桌面全屏开关。第二章主栏、侧栏及剑谱支持滚动，按钮加高。
- 系统返回键先收起键盘、设置或剑谱、卡牌图鉴，再询问是否返回主菜单；主菜单询问是否退出。
- 家中对话、飞花令、初遇名字输入避让软键盘，同时抬起对应发送按钮；键盘收起恢复原位置。家中不会在打开场景时主动弹出键盘。
- 切入后台通过 RunState 保存现有档案与最近检查点；不增加战斗中途快照。第二章切片仍不保存。
- Android 导出预设：ARM64 手机与 x86_64 模拟器、调试 APK、非 edge-to-edge、离线版。桌面版存档不会自动同步至手机。

## 测试与导出

在 Godot 的项目运行参数中增加 `--mobile-preview`，可在电脑预览移动布局，鼠标同时模拟触摸。此参数只供测试使用。

运行离线测试：

```powershell
python tools/run_regression.py --godot "E:/GameDev/Engines/Godot/4.7.2-dot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --only mobile_adaptation_smoke main_menu_smoke map_ui_smoke chaizhao_smoke scene_navigation_smoke
```

检查本机打包条件：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-android.ps1 -CheckOnly
```

需要安装与引擎版本相同的安卓导出模板，以及 Android SDK。编辑器设置的 `Export > Android` 中填入 Java SDK 和 Android SDK 路径。SDK 组件按所用引擎版本要求安装：[Godot 安卓导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)。脚本只检查和导出，不修改全局编辑器设置。

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-android.ps1
```

输出 `builds/android/LittleSwordSpirit-debug.apk`。正式发布需要另配发布签名与版本号。当前离线预设不申请网络权限；日后恢复联网对话需同时修改 LLMConfig 和导出权限。

## 真机验收（尚待执行）

覆盖 16:9、20:9 手机与 16:10 平板；左右横屏、刘海与导航栏、中文输入法、系统返回键、切后台后恢复、强制结束后读取最近检查点、地图拖动及点击节点、两章出牌与弃牌、剑谱长内容和存档页滚动。非 edge-to-edge 由安卓系统预留边缘区域；厂商强制全屏行为仍需真机检查。

桌面模拟不能确认 Android 输入法、实际 GPU 性能、系统安全区或安装兼容性。代码回归通过不等于真机验收完成。

## 本轮验证（2026-10-13）

8/8 回归通过：移动适配、主菜单、地图 UI、第二章、场景导航、家中 UI、战斗显示、存档 UI 恢复。移动回归覆盖 16:9、20:9、16:10 的菜单边界、地图拖动与单次点选、返回确认、输入框与发送按钮避让及复位；1280×720 下使用 Compatibility 实际渲染并检查主菜单、第二章及剑谱。截图在 `.godot/mobile-preview/`。

已修正测试运行器的主菜单隔离存档目录名，并将旧存档 UI 测试对“继续远征”文案的断言改为可续玩状态断言；保留后续实际读取检查点的验证。代码适配验收时尚缺少 Android SDK 和安卓导出模板，后续安装与打包结果见下节；真机验收仍待执行。

## 构建环境安装（2026-10-13）

已安装 Google 官方命令行工具、platform-tools、Android 35 / 36 平台与 Build Tools 35.0.1 / 36.0.0。SDK 位于 `C:/Users/Du/AppData/Local/Android/Sdk`，沿用 `E:/Java/jdk-21`，Godot 编辑器中的两个路径已有正确配置。安卓模板从 Godot 4.7.2 官方发布包提取，SHA512 校验通过；命令行工具通过 Google 官方组件清单中的校验值验证。

实际 APK 检查确认该 Godot 模板目标为 API 36，因此补齐 SDK 36 工具链，不以文档示例中的 API 35 作为最终构建要求。项目已开启安卓导出所需 ETC2/ASTC 导入选项，包名为 `com.littleswordspirit.game`。

已成功生成 `builds/android/LittleSwordSpirit-debug.apk`，校验通过：APK v2/v3 签名、ZIP 完整性、ARM64 / x86_64 架构、最低 API 24（Android 7.0）、目标 API 36；包含第二章与移动适配脚本，未打包 secrets/server/tools/docs/builds 目录。仍未完成真机运行验收。
