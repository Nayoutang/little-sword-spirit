# 第二章敌人美术

2026-10-15，内置 imagegen 生成。以既有 `art/enemies/ink_puppet.png` 锁定水墨边缘、旧布与木质结构，后续五个角色以首张提线木偶为家族参考。全部已保存透明原稿与规范化运行图，第一章素材保留。

| 角色 | 文件前缀 | 生成原稿 ID |
| --- | --- | --- |
| 提线木偶 | thread_puppet | 61e7f78a-66b6-489b-a660-71c72ef6b5a9 |
| 木偶刀手 | puppet_blade | 3a26e6bd-3338-4aeb-9650-41c6b3c17383 |
| 线师 | thread_master | 4a4ecdc8-4918-4693-a562-0f6f3257ccf6 |
| 替身箱偶 | stand_in_box | 0120f9bf-7571-4e46-82e8-eabaffb1300b |
| 牵线的刀客 | thread_blade_boss | eb62e801-bea8-4f10-b025-360e61290be2 |
| 戏班的看台人 | troupe_watcher | 33a1c375-ac25-45a0-a690-666557f67c72 |

原稿 `<前缀>_source_v1.png`，运行图 `<前缀>_sprite_v1.png`。由 `tools/normalize_chapter_two_art.gd` 保留 alpha 等比缩放至 768×896，内容最大 672×800，脚底基线 y=848，不拉伸。运行图开启 mipmaps、alpha 边缘修复，以线性 mipmap 过滤显示。六张原稿均验证包含透明 alpha。

战斗背景 `art/backgrounds/ch2_theatre_battle_v1.png`，原稿 `exec-153fa361-85c3-4088-bfaf-b5b4ac7a8d8f`，仅第二章战斗使用。

紫线由 `scripts/ui/thread_art.gd` 绘制，读取当前持线者与小墨节点位置，不修改战斗规则。斩断时紫线两端回弹、金色局部墨点；自挣从小墨一端断开并显示青色反馈。特效位于 UI 文字后面，不抢输入。

完整提示词见 [generation_prompts.json](generation_prompts.json)。桌面 Godot 截图覆盖普通敌人两组、双线、两位首领与断线；章节和图鉴回归通过。尚未在实体手机验证性能。
