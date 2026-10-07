# 占位 UI 替换

存档、约定、奖励、结算、关系里程碑、旧奇遇 UI 与飞花令统一采用现有绘制纸页、青金按钮和漫画字体。共享 InkUISkin 不再生成平面圆角按钮；动态奖励按钮和输入控件使用同一皮肤。牌堆关闭为居中小按钮「收起牌卷」，完整战局对话使用独立 dialogue_popup.tscn，不再创建系统 AcceptDialog。

保留有功能意义的遮罩、血条、敌人目标边框与特效；这些不属于占位菜单底板。已完成的主界面、卡面、漫画气泡与地图美术保留。UI 场景仍控制几何布局，素材无烘焙文字。

检查：ui_structure_smoke、battle_presentation_smoke、ui_art_audit。渲染截图在 art/concepts/ui_audit_*.png。
