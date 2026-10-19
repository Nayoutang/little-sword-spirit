# 2026-10-15 玩家新牌美术

已为编号 20～33 的 14 张牌生成独立插画并接入 `CardArtCatalog.PLAYER_FILES`，移除旧牌图片回退。工具为内置 imagegen，参考既有 `16_chase_wind_v1.png`，保持 Q 版小墨、青金配色与水墨纸边；费用、牌名、效果仍由程序绘制。

卡牌：借势、开路、递剑、承让、收势、并肩、蓄意、不动、听风、同调、孤注、后发、挑丝、护心。

- 运行图：`art/cards/player/20_*.png` 至 `33_*.png`。
- 透明原稿：`art/cards/sources/expansion_20261015/`，用 `.gdignore` 避免额外导入源图。
- 完整提示词、参考与生成 ID：[expansion-20261015.json](expansion-20261015.json)。护心初稿多手臂，最终采用重新生成的双手持剑版本，弃稿未接入。
- 尺寸：512×442 RGBA，等比 Lanczos 缩放、透明留边，不拉伸、不覆盖旧牌。运行图开启 mipmaps。
- 尺寸、alpha 与文件哈希：[expansion-raster-qa.json](expansion-raster-qa.json)。
- 实际牌面：[new-card-faces-20261015.png](../previews/new-card-faces-20261015.png)。Godot 桌面渲染联排已目视检查。

验证：`new_cards_smoke` 与 `card_library_smoke` 通过；额外 `card_library_smoke --check-all-art` 通过，52 张定义均拥有独立存在的图片路径。未改动卡牌数值或存档编号。

重建运行图：Godot `--headless --path . --script res://tools/new_card_art.gd -- --normalize`。有渲染器运行同脚本（省略 `--normalize`）可重建联排预览。
