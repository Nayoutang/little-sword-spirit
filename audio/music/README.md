# 背景音乐

把曲子按下面的文件名放进这个文件夹（推荐 .ogg，也支持 .mp3 / .wav），Godot 导入后自动生效，代码不用改。
曲子会自动循环；切场景时 1.2 秒交叉淡入淡出，同一首不会重头播。

| 文件名 | 用在哪里 | 缺了用哪首 |
| --- | --- | --- |
| menu | 主菜单、存档选择 | —（必备） |
| intro | 初遇剧情 | menu |
| home | 家中、出门约定、关系里程碑、结算 | —（必备） |
| journey | 历练地图、奇遇、事件、战后奖励 | 保持上一首 |
| poetry | 途中飞花令 | journey |
| battle | 普通 / 精英战斗 | —（必备） |
| boss | Boss 战 | battle |
| finale_battle | 第一章结局战 | boss → battle |
| finale | 结局剧情 | home |

最少只要 menu、home、battle 三首就能跑起来。
场景与曲目的对应关系在 `scripts/autoload/music.gd` 的 `SCENE_TRACKS` 里改。
音量受主菜单设置里的总音量控制。

上架前记得确认每首曲子的授权允许商用 / 在 TapTap 发布，并按要求在游戏或页面里署名。
