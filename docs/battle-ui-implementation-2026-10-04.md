# 战斗界面美术落地

已接入第一版运行界面：四类插画牌面、宣纸牌框、墨色敌人意图、统一资源横栏、玉色操作按钮、实物牌背与宣纸气泡。文字、费用、数值和技能条件仍由原有数据与状态生成。卡牌详细描述和技能条件保留在悬停提示内，手牌多时横向滚动。禁用卡牌降低亮度。当前玩家牌共享四类插画，技能采用玉色按钮；尚未达到概念稿逐像素一致。

资产：`art/ui/battle/`。内置 imagegen 生成，原始图集保留，按目视确认的网格切分并裁剪透明边。生成提示词：

```text
Create a production game UI asset atlas for the approved Chinese ink wuxia game interface in image 1. Image 1 is STYLE REFERENCE only. Exact 4 columns by 3 rows grid, equally sized cells, landscape 4:3 output. Every cell independent isolated object centered with generous transparent margins. Genuine transparent background, NO text NO letters NO numbers NO labels anywhere. Restrained antique brass edges jade lacquer ivory parchment ink brush. Row1 four landscape card illustrations WITHOUT frames: chibi dark brown hair amber eyed white teal gold swordswoman gathering jade energy; same girl sword blocking jade shield; same girl sweeping two jade water waves; same girl straight sword thrust. Paint on ivory paper rectangular artworks filling most of each cell with no writing. Row2: blank full tall parchment playing card frame brass corners with empty upper art window and empty lower writing area; tall black lacquer brass ornate facedown card back with sword floral emblem; same cardback vermilion trim for discard; blank opaque black brush ribbon thin brass corners for enemy intention, landscape. Row3: blank landscape jade lacquer brass button; blank wide opaque black lacquer brass HUD ribbon; blank ivory brush-edged paper speech bubble small lower-left tail; circular jade brass medallion with shield emblem. Cohesive premium handpainted game assets, clear boundaries, no excessive flourishes, preserve character identity. EXACT grid for deterministic slicing, no objects cross their cells.
```

验证：Godot 4.7.2 实际渲染单敌人与三敌人、多张手牌场景；数值回归 Balance smoke failures: 0；git diff --check 通过。未进行整局人工游玩，也未验证所有显示比例。
