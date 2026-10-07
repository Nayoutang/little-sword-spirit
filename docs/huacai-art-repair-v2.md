# 华彩人物素材修正

使用内置 image_gen，以原始 sword_spirit_ink_event.png 为人物与古风水墨画风参考，重新生成透明人物层。替换 brilliance_cut_in.gd 的素材引用，保留原有分层入场、墨带和剑光动画。

修正重点：完整长剑与连续的剑柄—护手—剑身关系；自然握持；能辨认的肩、腰和另一只手；缩减遮挡身体的大面积衣袖与墨团。

生成提示词摘要：Adult-proportioned Chinese swordswoman, traditional grayscale ink brush painting, ivory hanfu, black bun with white blossoms, teal tassel, readable three-quarter torso and waist, anatomically correct sword grip, one long continuous straight jian blade fully visible, controlled flowing sleeves and hair, transparent background, no text or backdrop.

素材：art/effects/brilliance_ink_figure_v2.png。原 v1 保留供对照，运行时使用 v2。

后续用户确认采用原华彩封面原图（exec-16e148e9）：保留反手握剑、梅花与环绕水墨。运行时最终改用 art/effects/brilliance_ink_approved.png，v2 与反手重绘预览仅保留对照。使用原始透明 PNG，不使用带棋盘格与“画布”按钮的截图。分层动画保持，实际引擎截图已核对，CARD_LIBRARY_SMOKE failures=0。
