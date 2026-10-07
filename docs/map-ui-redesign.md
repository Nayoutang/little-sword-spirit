# 山行图卷

2026-10-05：沿用主界面的纸张、楷体、青金配色，地图的背景、美术图标、路线、按钮、文字各自独立。

## 素材

- art/backgrounds/route_map_v2.png：内置 ImageGen 生成，提示为象牙白旅行纸卷、低饱和水墨水彩山水、中央留白、两侧松树与楼阁，不包含文字、节点或路线。
- art/ui/map/node_atlas_v1.png：内置 ImageGen 生成，4列×2行透明图集。顺序为小屋、剑、双剑、宝箱、卷轴、灯笼、首领面具，末格留空；统一纸质底、墨线、青玉与旧金。由引擎按格绘制，不改原图。
- 图例纸张与归家按钮复用已有独立绘制素材；所有文字仍为原生控件，共用 ui/shared/comic_font.tres。

## 实现

scenes/map.tscn 保留背景和 MapContent；ui/map/map_ui.tscn 管理标题、图例、返回按钮。scripts/map/map.gd 保留20层路线生成、种子和节点恢复；扩大层距至150，横向留边300，路线改细并突出当前能走的分支。出可视区的节点及连线隐藏并关闭点击。scripts/map/route_node.gd 使用独立图集，选中标记与悬停反馈由引擎处理。

tools/map_ui_smoke.gd 检查路线数量、可选节点、滚动边界与重进地图恢复；传 --map-screenshot 保存实际渲染截图 art/concepts/map_ui_implemented.png。本轮测试使用隔离目录，不写玩家存档。
