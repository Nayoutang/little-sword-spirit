# 战斗界面目标效果图

这是完整界面的美术概念稿，不是已实现的 Godot 截图。现有运行界面尚未替换。

目标图：`art/concepts/battle-ui-target-v1.png`。

## 视觉方向

- 保留水墨山门、月色石台、小墨与影剑客的身份。
- 敌方意图采用墨色底、米白数字和朱红攻击图标，避免浅金文字与月亮混淆。
- 上半屏保留战场空间；小墨对白使用短句气泡，意向效果以独立徽记呈现。
- 玩家资源合并成横栏，分别使用生命条、精力珠、护盾印和连击印。
- 手牌使用宣纸牌面、插画和玉色费用标记；牌堆呈现叠牌外形。
- 操作区使用玉色结束回合按钮与技能印章，减少重复方框。

## 实现约束与检查

已目视检查完整生成图：攻击 6 与月亮之间有墨色底隔离，四张卡牌插画及费用可辨，角色身份与水墨环境一致，无调试条与桌面宠物。图中数值是独立视觉样例。

后续实现必须使用运行状态填充数值。中文文本、卡牌描述、按钮与交互由 Godot 原生控件绘制，不把整张概念图直接当成界面。牌面插画、边框、按钮与徽记分别制作资产。尚需验证多敌人、更多手牌、长名称、悬停提示和不同窗口尺寸的适配；本图不代表这些状态已通过运行测试。小墨意向执行时机仍遵循现有游戏规则。

## 生成记录

工具：内置 imagegen。参考：用户提供的当前战斗截图。保留原始生成文件与元数据，项目内另存完整副本。

最终提示词：

```text
Use case: ui-mockup.
Create ONE polished final target screenshot for this existing Chinese wuxia deckbuilding game, landscape 16:9, high resolution. Input image 1 is reference for the existing ink mountain/moon stone arena, Xiaomo character identity and enemy identity; redesign the interface completely with professional shipping-game polish. Preserve the dark brown hair chibi swordswoman with white/teal/gold robe, flowers, teal ribbons and sword on left, and ragged straw-hat swordsman enemy on right. Preserve moody monochrome ink landscape and spacious arena. Do not include OS titlebars, debug stats, desktop pet or any external overlays.

Composition: top 60 percent is clean battle space with Xiaomo lower left facing enemy right, character feet grounded on same stone platform. A compact understated ink-paper speech bubble near Xiaomo contains only “这一手，我来。” and small teal supportive seal “引势 · 下次攻击 +2”. No giant black dialogue rectangle. Enemy above head has a DISTINCT opaque near-black ink ribbon intention plaque with ivory-white bold “攻击 6”, a small vermilion crossed sword symbol and subtle brass edge. It MUST remain readable against the moon. Beneath that a slim beautifully framed vermilion health bar “34 / 34”, enemy name “影剑客”, two small well separated jade/vermillion status seal badges “护盾 8” and “易伤 2”. Never yellow text directly on bright sky.

Lower 40 percent: cohesive crafted UI combining dark lacquer, old ivory paper, jade medallions, fine restrained brass, ink brush edges. No generic blue squares or repetitive rounded boxes. A single compact player HUD ribbon just above cards aligned left to middle: small portrait medallion and “生命 90 / 90” with slim vermilion bar; three jade energy beads and “精力 3 / 3”; shield seal “护盾 0”; combo seal “连击 0”. Clear hierarchy, clean white/ivory numerals, small labels.
Four large fully illustrated readable cards across bottom center, shallow natural fan, not blank text slabs. Card faces ivory muted parchment with beautiful ink watercolor artwork occupying upper half, fine stylized asymmetrical brass corner frame, circular jade cost gem top left “1”, concise dark text lower half. Titles and effects exactly:
“凝神” / “抽 1 张牌” / “清空连击”; artwork quiet swordswoman gathering jade light.
“横架” / “护盾 5” / “清空连击”; artwork sword block jade canopy.
“叠浪” / “伤害 6” / “连击 +2”; artwork two jade wave sword arcs.
“平刺” / “伤害 6” / “连击 +1”; artwork straight sword thrust.
Each card has distinct silhouette artwork but coherent same family. All titles large readable and no paragraph microtext.
Far bottom left physical facedown illustrated card stack with small “牌堆 11” label; far bottom right small discarded card stack labelled “弃牌堆 0”. Beside hand on lower right a substantial elegant jade lacquer button “结束回合” and discreet ivory hint “执行小墨意向”. Near it two compact circular decorative sword-skill seals “流光” and “华彩”, subdued unavailable state. Keep controls separated from card click areas. All elements entirely inside safe margins, no crop. Small subtle top left progress label “山门试炼 · 第 1 层” and top right “第 1 回合”.

Aim for refined usable Chinese ink fantasy card battler art direction, tasteful negative space, restrained ornament not gold overload, grounded sprite lighting, delicate fog and sparks, excellent contrast for gameplay values. This is a coherent actual game screen design, not a poster, annotated design board or multiple mockups. Chinese text rendered accurately, use readable clean UI typography for values and headings.
```
