# V1 功能/逻辑测试框架实施计划

> 决策依据：[docs/decision/0001-testing-strategy-v1.md](../decision/0001-testing-strategy-v1.md)
> 范围：仅功能/逻辑测试（headless）。截帧/视觉测试不在 V1 范围。

## 目标

交付让 Coding Agent 可依赖的测试闭环：

1. 一条命令跑完逻辑测试，输出结构化 JSON + 明确退出码
2. 每个失败可定位：`file:line` / story node id / 期望 vs 实际
3. 同一 seed 重复执行结果一致（flake 双跑自检）
4. 剧本静态校验毫秒级完成（跳转、资源、flag、本地化 key）
5. 确定性基础设施先于玩法开发落地

## 目录结构

```
tools/
└── test                      # 统一 CLI 入口（包装 Godot headless 调用）
addons/vng_test/              # 测试框架本体（导出时排除）
├── core/                     # runner / 发现 / 生命周期 / 断言 / 看门狗
├── reporters/                # console / json / junit
├── dsl/                      # playthrough DSL / trace 录制与比对
├── lint/                     # 图分析 lint（死链/可达性/flag 一致性），消费编译模型
└── cli/                      # run_tests.gd / lint_story.gd 入口
addons/vns/                   # 剧本格式：parser / validator / emitter / 运行时模型
tests/
├── unit/                     # L0 纯逻辑（进程内批跑）
├── story/                    # L1 剧本级 E2E（每文件独立进程）
└── fixtures/                 # 示例剧本 / golden traces
game/
├── core/                     # 纯 GDScript 状态机（零 Node 依赖）
├── presentation/             # 节点/动画/音频（只订阅事件，不在 V1 测试范围）
├── services/                 # RngService / Clock / InputHub / EventBus（接口 + real + fake）
└── story/                    # .vns 源文件 + story.json 清单（角色/资源/入口）
    └── compiled/             # 编译产物（提交入库，导出使用；--check 校验新鲜度）
test-results/                 # 运行产物，gitignore
AGENTS.md                     # Agent 使用契约
```

## 阶段计划

### Phase 0 · 骨架与契约

- 初始化 Godot 4.7 工程与目录约定
- `tools/test` CLI：参数透传、退出码透传
- `test-results/` 产物目录约定 + gitignore
- `AGENTS.md` 初版：命令、约定、禁用 API
- **验收**：无测试时 `tools/test` 明确提示并返回退出码 `3`

### Phase 1 · 自研测试核

- `VngTest` 基类：`before_all / before_each / after_each / after_all`
- 自动发现 `tests/**/test_*.gd` 的 `test_*` 方法；注释 tag（`## @tag fast`）
- 断言库：`assert_eq / ne / true / false / in / near / null / signal`，失败信息含调用点
- 超时看门狗（默认 10s/用例，可配置）
- 进程模型：unit 进程内批跑；story 每文件独立进程 + `--jobs N` 并行；父进程聚合
- reporter：console（每用例一行）/ JSON / JUnit XML
- CLI：`--fast --tags --filter --seed --timeout --jobs --json --list --rerun`
- 护栏：退出码契约（含 `3` = 未发现测试）；关键 suite 最低用例数
- meta 自测：故意失败的用例必须报红；挂起用例必须被看门狗杀掉
- **验收**：meta 自测全绿；失败样例 JSON 可直接定位到 `file:line` 与期望/实际

### Phase 2 · 确定性设施 + core 架构

- `game/core/`：StoryRuntime 骨架（节点推进、条件求值、flag 存储）、SaveModel
- `game/services/`：RngService、Clock、InputHub、EventBus（接口 + real + fake）
- 测试模式启动参数：`--test-mode --seed=N --save-root=user://test/<run_id>`（不污染真实存档）
- `DebugSnapshot`：全量状态 JSON（当前节点、行号、flags、可见角色、播放中的音频/tween）
- 源码扫描：禁止裸 `randi()/randf()/Time.*`；接入 gdformat / gdlint
- `--flake-check`：同 suite 连跑两次比对结果与事件轨迹
- **验收**：同一 seed 两次 playthrough 事件轨迹完全一致；核心逻辑 L0 用例全绿

### Phase 3 · 剧本 DSL 编译器 + Linter + trace golden

- 格式已定案：自定义文本 DSL（`.vns`），编译为规范 JSON 模型 —— 见 [decision 0002](../decision/0002-story-dsl.md)
- 编译器 `addons/vns/`：lexer/parser → 结构校验 → 发射编译产物（含 `src` 行号溯源）
- CLI `tools/story build | check | lint`；错误格式 `file:line:col: error: ...`（含 did-you-mean 建议）
- `--check` 校验产物新鲜度（防止改了源文件忘记编译），纳入 `tools/test --fast`
- 图分析 lint：跳转目标、节点可达性、资源引用、flag/变量读写一致性、本地化 key；报告带 `file:line`
- playthrough DSL：`start_scene / expect_line / expect_speaker / advance / choose / expect_flag / expect_scene / expect_choices`
- trace golden：录制、比对、文本化 diff；记录语义事件而非位置索引；`--update-traces` 需显式 flag 批准并留审计日志
- `tests/fixtures/`：多分支示例剧本（含隐藏 flag 路径）
- **验收**：非法剧本给出精确行列错误；linter 抓出断链与 flag typo；DSL 跑通分支；轨迹变更可 diff；`--check` 能发现 stale 产物

## 测试结果契约

```
test-results/
├── results.json      # Agent 主接口
├── junit.xml         # 工具链 / CI
└── artifacts/        # 失败时：trace、snapshot、日志尾部
```

`results.json`（schema v1，示意）：

```json
{
  "schema": 1,
  "run": { "seed": 1234, "godot": "4.7.1", "duration_ms": 812 },
  "summary": { "total": 42, "passed": 40, "failed": 1, "skipped": 1 },
  "suites": [
    {
      "name": "unit/rng",
      "file": "res://tests/unit/test_rng.gd",
      "tests": [
        {
          "name": "same_seed_same_sequence",
          "status": "failed",
          "duration_ms": 3,
          "tags": ["fast"],
          "message": "expected 42 but got 43",
          "expected": "42",
          "actual": "43",
          "location": "res://tests/unit/test_rng.gd:12",
          "artifacts": ["artifacts/unit_rng_same_seed.trace.json"]
        }
      ]
    }
  ]
}
```

退出码：

| 码 | 含义 |
| --- | --- |
| 0 | 全部通过 |
| 1 | 存在测试失败 |
| 2 | 框架/内部错误（解析失败、超时失控等） |
| 3 | 未发现任何测试（防"假绿"） |

## Agent 工作流

```
tools/test --fast                  # <5s：unit 层，每次改动后
tools/test                         # 全量逻辑测试
tools/test --lint                  # 剧本静态校验
tools/test --filter story/chapter1 # 定向
tools/test --rerun                 # 仅重跑上次失败
```

约定（写入 AGENTS.md）：

- 每个功能必须同时提交测试；功能未带测试视为未完成
- 禁止直接调用非确定性 API（随机、真实时间）
- trace / 快照更新必须显式批准，禁止为"变绿"而更新
- 测试命名与 story node id 对应，便于失败定位

## 风险与对策

| 风险 | 对策 |
| --- | --- |
| 非确定性导致 flake | 确定性设施前置 + `--flake-check` 双跑检测 |
| 进程隔离开销拖慢迭代 | unit 批跑；`--fast` 限定秒级；并行 jobs 控制 |
| Agent 为过测试而作弊 | 退出码 3 校验、最低用例数、trace 更新审计 |
| 剧本格式变更 | 编译模型为唯一运行时契约（schema 版本化）；源 DSL 演进不影响 runtime / linter 接口 |
| core / presentation 边界被侵蚀 | L0 用例强制 core 无 Node 依赖（headless 直测） |

## 不在 V1 范围

- 截帧 / 像素 golden / 表现语义快照
- Agent 运行时桥（WebSocket 驱动真实实例）
- 多平台与 CI 矩阵、覆盖率统计、性能预算
- 视觉/多模态反馈与 VLM 辅助校验
