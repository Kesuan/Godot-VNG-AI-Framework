# Godot VNG AI Framework

**面向 AI Agent 的视觉小说（VNG）开发框架。** Agent 写代码与剧本、自主运行测试并修复；人类只做一件事——体验游戏，给出真实反馈。

[English](README_EN.md) · [Agent 工作规范](AGENTS.md) · [设计决策](docs/decision/) · [示例游戏](vng-demo/README.md)

![雨夜车站 · 对白场景](docs/assets/demo-story.png)

## 为什么

Agent 的迭代闭环质量 = **反馈信号的质量 × 速度**。不可复现的测试、无法定位的失败，会迫使 Agent"改测试迁就代码"，闭环反而恶化。本框架以"可被 Agent 信任的测试信号"为第一设计目标：

- **确定性优先**：统一 RNG / 逻辑时钟 / 输入命令化，同一 seed 逐字节可复现
- **失败可定位**：`file:line`、期望/实际值、story node id、语义事件轨迹
- **防假绿**：没有测试 = 退出码 3；运行时错误扫描；`--flake-check` 双跑比对

## 亮点

- **自研测试核**（零第三方依赖）：进程隔离、软/硬双看门狗、JSON/JUnit 报告、退出码契约
- **剧本 DSL（`.vns`）**：编译为规范 JSON；静态 lint 覆盖断链、flag typo、资源/角色登记、节点可达性，错误带行号与 did-you-mean
- **playthrough DSL + trace golden**：语义事件轨迹（不含行号与时间戳），更新必须显式批准并写审计日志
- **确定性 core**：Rng / Clock / InputHub / EventBus 服务注入；core 零 Node 依赖，headless 直接单测
- **表现层测试走真实输入路径**：鼠标/键盘仿真经过真实 GUI 拾取与输入路由；场景重入有回归测试
- **资源管线**：零素材可用、投放即生效（免导入）；`tools/demo assets` 列出待投放清单

## 快速开始

要求：**Godot 4.7+**（当前支持 macOS）；可用 `GODOT_BIN` 指定可执行文件。

```bash
tools/test --fast          # 框架单元测试（秒级）
tools/test                 # 全量：框架 138 项（unit / meta 契约 / story E2E）
tools/demo run             # 体验示例游戏《雨夜车站》
tools/demo test            # 游戏侧 15 项（story / smoke / 资源管线）
tools/lint                 # 格式 + 静态 + 非确定性 API 扫描
```

## 仓库结构

```
addons/vng_test/   # 测试框架：runner / 断言 / 发现 / 看门狗 / 报告 / DSL / 输入仿真
addons/vns/        # 剧本格式：解析 / 校验 / lint / 编译 / 资源路径与就位报告
game/              # 框架运行时：core（零 Node 依赖）+ services（确定性设施）
tests/             # 框架自测：unit / meta 契约 / story E2E + trace golden
tools/             # 统一 CLI：test / lint / story / demo
vng-demo/          # 示例游戏工程（框架单向镜像 + 真实美术/音频）
docs/              # 决策记录（ADR）与实施计划
```

框架与游戏工程的关系、镜像机制见 [decision 0003](docs/decision/0003-game-project-structure.md)。

## 设计文档

| 文档 | 内容 |
| --- | --- |
| [0001 测试策略](docs/decision/0001-testing-strategy-v1.md) | V1 范围、测试分层与取舍 |
| [0002 剧本 DSL](docs/decision/0002-story-dsl.md) | `.vns` 语法、编译模型与 lint |
| [0003 工程结构](docs/decision/0003-game-project-structure.md) | 框架/游戏镜像与 `tools/demo` |
| [0004 表现层测试](docs/decision/0004-presentation-testing.md) | 输入仿真、重入测试、引擎错误归因 |
| [0005 资源管线](docs/decision/0005-asset-pipeline.md) | 目录约定、回退链与就位报告 |
| [AGENTS.md](AGENTS.md) | Agent 工作规范与命令契约 |
| [示例游戏](vng-demo/README.md) · [素材需求](vng-demo/ASSETS.md) | 运行/验收清单与素材清单 |

## 当前状态

- 第一条可玩切片《雨夜车站》已可玩：标题 → 演出 → 选项分支 → END → 回标题（[标题画面](docs/assets/demo-title.png)）；背景与立绘已投放，音频待投放
- 测试：框架 138 项、游戏 15 项，全绿
- 下一步候选：存档/读档与多章节运行时、音频投放、导出配置、场景语义断言库

## 许可

[MIT](LICENSE)
