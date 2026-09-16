# 0003 · 游戏工程结构与框架消费方式

- 状态：已接受
- 日期：2026-09-14
- 关联决策：[0001](0001-testing-strategy-v1.md)、[0002](0002-story-dsl.md)
- 关联计划：[docs/plans/0001-test-framework-v1.md](../plans/0001-test-framework-v1.md)

## 背景

框架仓库需要验证"外部游戏工程消费框架"这一真实产品场景（而非框架与游戏同工程）；同时 Agent 工作流要求集成方式可重复、低漂移、双测试入口清晰。

## 决策

1. **游戏工程位于仓库内 `vng-demo/` 并纳入版本控制**；仓库根工程继续作为框架开发工程，承载框架自测（`tests/`）。
2. **框架 → 游戏为单向镜像**：`tools/demo sync` 把 `addons/vng_test`、`addons/vns`、`game/core`、`game/services` 复制进 vng-demo（`rsync --delete`），镜像目录写入 `.vng-mirror` 标记并在版本控制中忽略；禁止在镜像目录中编辑。
3. **`vng-demo/.gdignore` 隔离根工程扫描**。实测结论：根工程不注册 vng-demo 的脚本类、`tools/test` 不受影响；vng-demo 自身 `--import`/运行正常。
4. **`tools/demo` 是游戏侧统一入口**：`sync | test | story | lint | run`，每次调用先同步，杜绝镜像漂移。
5. **游戏侧测试与 trace golden 存放于 `vng-demo/tests/`**；框架测试仍在仓库 `tests/`。两侧验证均为一等公民：改框架后需同时通过 `tools/test` 与 `tools/demo test`。

## 后果

- 游戏可独立导出/发布，不需要框架仓库的测试与文档；框架可继续演进。
- 镜像产生少量重复（生成物），由同步的 `--delete` 保证一致，无人工干预。
- 若未来游戏独立成仓：迁移 `vng-demo/` 并保留等价的同步脚本即可。

## 被否决方案

| 方案 | 否决原因 |
| --- | --- |
| 直接把游戏加进根工程 | 无法验证"外部工程消费框架"；游戏导出配置会混入框架工程 |
| git submodule / 独立仓库 | 本地开发需先提交框架才能被游戏看到，拖慢 Agent 闭环 |
| 软链接镜像 | Godot 扫描/导入对软链接行为不确定，跨平台风险 |
