# 场景与 UI 组织约定

- `scenes/`：页面入口、背景和场景对象，挂载流程脚本并实例化 UI。
- `ui/<页面>/`：独立 UI 场景，保存节点层级、位置、尺寸、容器间距和固定装饰。
- `scripts/`：数据、流程、交互与动画。UI 绘制和呈现脚本放在 `scripts/ui/`。

## 在编辑器中微调

战斗页面打开 `ui/battle/battle_ui.tscn`。调整 `EnemyArea/EnemyRow`、`HandViewport`、`InfoArea/PlayerStatus`、`CompanionPanel`、`ActionArea` 等节点。敌人内部血条、立绘、名字与状态标记打开 `ui/battle/enemy_display.tscn` 调整。

初遇打开 `ui/intro/intro_ui.tscn`，家园对话打开 `ui/home/chat_ui.tscn`，飞花令打开 `ui/home/feihualing_layer.tscn`。其余页面按同名子目录查找。入口场景保留原有路径，原节点访问路径也保持一致。

在入口场景中可使用实例节点的“打开场景”进入对应 UI 编辑；需要对实例单独覆盖时，启用“可编辑子节点”。容器中的子节点位置由容器管理，应调整容器位置、间距和子节点最小尺寸。

## 编写新界面

固定控件直接建在 `.tscn` 中，脚本通过节点引用更新文字、纹理、可见性并连接信号。不要在 `_ready()` 重写固定位置和尺寸。重复组件实例化 UI 场景；敌人组件已使用此方式。

卡面与状态栏内部的自定义绘制、临时飘字、战斗特效和随机路线仍由脚本生成；它们所在的固定 UI 容器可以在编辑器中调整。容器排版、对话随内容伸缩和动画期间的位置变化属于运行时行为。角色动作结束后返回场景设定的位置。

## 验证

`tools/ui_structure_smoke.gd` 检查所有入口场景加载、静态节点引用、手牌和初遇布局不被启动脚本覆盖、敌人组件与弹窗绑定、纹理皮肤，以及角色动画回到调整后的位置。

运行测试时传入 `--cooperation-sim` 隔离持久化；现有 `tools/cooperation_sim.gd` 还要求 `APPDATA` 指向项目内的 `.godot/cooperation-user`。
