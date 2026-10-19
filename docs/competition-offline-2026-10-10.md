# 比赛离线版

比赛要求禁止一切联网。本次将项目默认运行及 Windows 导出切换为完全离线：LLMConfig.is_available() 恒为 false，代理地址与模型配置为空，无命令行启用入口。已有网络代码在禁用分支之后，不会执行；服务端、secrets、诊断工具、实验数据与原始导入数据不进入导出包。

## 飞花令

内置唐诗三百首、千家诗筛选去重后的 2178 联，补入八条剑意原句。运行时建立完整诗联、半联和令字索引，繁体字按 OpenCC 字表逐字转简，忽略标点与空格。随机令字只使用至少有八联可用诗句的候选字；自选生僻令字无可用句时不计胜负，允许更换。

小墨优先避开剑意诗句，留给玩家作答。完整收录诗联才算玩家独立作答成功；半联沿用一次补全宽限，不解锁剑意。重复、缺令字与两次认输仍按原规则结算。未收录诗句提示换句，不判伪造、不推进回合。输入“提示”只展示一联，不消耗出句。每局最多解锁一条剑意，永久解锁不重复授予。解锁与对局记录继续调用 RunState 原接口。

限制：这是有限诗库，不是任意古诗验证器；逐字繁简转换不包含完整上下文转换，异文以收录文本为准。来源和许可证在 data/poetry/SOURCES.txt。

## 闲聊与战斗

家中自由输入隐藏，日常不外放闲聊选项。每次远征归来通过 RunState.consume_homecoming() 的一次性标记随机选一组二选一话题，回答后立即收起；四个羁绊阶段有各自回应。重新进入家中、重复回调或退出飞花令不会再次提供话题。归来问候从 last_run_journal 的真实胜败、漫画奇遇名称与约定结果生成，不编造经历。

near_death_clear、bond_skill_comeback、repeated_failure_clear 各有独立开场和两个选项：归来时有心事则优先谈心事，正面回应通过 SpecialEventManager 完成，暂缓保留到下次归来；完成后不连着触发下一件心事，下次归来按原优先级处理。事件完成状态保持原存档格式。日常闲聊不额外刷羁绊。

战斗直接沿用既有本地战术选择，授权牌池和结算数值不变；对白依招式类别与关系阶段生成。漫画奇遇与出门约定沿用已有本地台词。

## 验证与交付

- competition_offline_smoke：全部随机令字开场、八条剑意、单局一次限制、繁简与标点核对、重复与缺字、半联、未知诗句、提示、认输、自选生僻字、家中和途中入口、三个心事与事件序列化。
- 既有 feihualing_smoke、feihualing_partial_smoke、feihualing_wrong_keyword_smoke、feihualing_opening_smoke 通过。
- sword_skills_save_smoke、expedition_save_smoke、finale_flow_smoke 使用项目内隔离 APPDATA 通过。远征测试中故意构造坏存档的警告属于测试预期。
- companion_effects_smoke：684 个既有技能对照通过。
- adventure_pool_smoke：100 个地图种子，每条路线保持一次漫画、两次对诗，正常返回地图并保留生命和路线。
- 实际渲染检查家中话题、心事与飞花令界面。
- Windows release 导出完成，导出包内执行同一离线冒烟测试通过；可执行文件无界面启动通过。
- competition_package_audit：611 个包内文件，确认诗库与许可证齐全，无 server、secrets、tools、原始诗库和代理域名。

构建统一保存在 E:/GameDev/Builds/捡到一只小剑灵：competition-offline/LittleSwordSpirit-Offline.exe 为可运行目录，LittleSwordSpirit-Offline.zip 为上传包。Windows 导出路径已指向此目录，项目内不再保留重复 builds 文件夹。以上属于自动流程和界面检查，未替代真人从新存档完整打到结局的试玩，也未执行系统级抓包。
