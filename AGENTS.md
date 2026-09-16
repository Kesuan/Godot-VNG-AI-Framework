# AGENTS.md — Godot VNG AI Framework

AI Agent 驱动的视觉小说（VNG）开发框架。当前仓库是**框架开发工程**（Godot 4.7）；游戏本体在第一条可玩切片开始时接入。

## 常用命令

| 命令 | 用途 |
| --- | --- |
| `tools/test` | 运行全部逻辑测试（unit 批跑 + meta 契约测试） |
| `tools/test --fast` | 仅 `tests/unit`，秒级反馈，Agent 每次改动后先跑 |
| `tools/test --filter <glob>` | 过滤（文件路径或 `file::test`，支持 `*` `?`；可重复） |
| `tools/test --tags <a,b>` | 按 `# @tag` 过滤 |
| `tools/test --rerun` | 仅重跑上次失败用例 |
| `tools/test --flake-check` | 全部跑两遍比对状态（检测 flake），结果写入 `flake-results.json` |
| `tools/test --update-traces` | 录制/更新 trace golden（显式批准，写审计日志；见下） |
| `tools/test --list` | 列出发现的测试文件 |
| `tools/test --json` | 仅输出聚合 JSON 到 stdout |
| `tools/test --isolate-all` | 每个测试文件独立进程（排查状态泄漏） |
| `tools/test --min-tests <n>` | 用例数低于 n 视为失败（防删测试） |
| `tools/test --reimport` | 重新导入项目（新增 `class_name` 后通常自动处理） |
| `tools/lint` | 格式（gdformat）+ 静态（gdlint）+ 非确定性 API 扫描 |
| `tools/story build` | 编译 `.vns` → `game/story/compiled/*.json`（含结构校验与 lint） |
| `tools/story check` | 校验编译产物新鲜度（fast 测试已覆盖） |
| `tools/story lint` | 剧本静态检查（跳转/flag/资源/角色/可达性） |
| `tools/demo run` | 同步框架到 vng-demo 并启动游戏（体验用） |
| `tools/demo test [参数]` | vng-demo 测试（参数与 `tools/test` 相同，含 `--update-traces`） |
| `tools/demo story <build\|check\|lint>` | vng-demo 剧本工具 |
| `tools/demo lint` | vng-demo 非确定性 API 扫描 |
| `tools/demo sync` | 仅同步框架镜像 → vng-demo |

环境变量：`GODOT_BIN`（Godot 路径，默认自动探测）、`VNG_TEST_WATCHDOG_SEC`（runner 兜底硬超时）。
`tools/lint` 的 gdformat/gdlint 需 `pip3 install --user gdtoolkit`，未安装时自动跳过并提示；非确定性扫描始终执行。

## 退出码契约

| 码 | 含义 |
| --- | --- |
| 0 | 全部通过（含 skip） |
| 1 | 存在测试失败 / 超时 / suite 错误 / flake 差异 |
| 2 | 框架/内部错误（参数错误、报告写入失败、min-tests 未达标） |
| 3 | 未发现任何测试（防"假绿"，**不要**当作通过） |

## 编写测试

- 文件：`tests/<layer>/test_*.gd`，声明 `extends VngTest`；每个 `func test_*` 为一个用例。
- 生命周期：`before_all / before_each / after_each / after_all`（可选）。测试可为 async（`await`）。
- 断言：`assert_eq / assert_ne / assert_true / assert_false / assert_null / assert_not_null / assert_in / assert_near / assert_signal / fail`，失败自动记录调用点与期望/实际值。
- tag：文件级 `# @tag fast` 写在 `extends` 之前；方法级直接写在 `func` 上方。
- 跳过：`# @skip 原因` 写在 `func` 上方（或 `extends` 前跳过整个文件）。
- 种子：`VngRun.seed`（由 `--seed` 注入，默认 0，保证可复现）。
- 文件系统：只写 `res://tests/`（fixtures 在 `tests/*/fixtures/`，发现时自动跳过）与 `user://`（临时存档）；不得写入 `game/` 下的仓库文件。

## 确定性设施与 core 架构（P2）

- `game/services/`：`VngServices` 统一持有 `rng / clock / input / events`。
  - 生产：`VngServices.new(seed)`；测试：`VngServices.for_tests(seed)`（FakeClock，`advance(sec)` 显式推进）。
  - 随机：`services.rng`（`set_seed / next_int / next_float / next_int_range / next_float_range / pick / shuffle`）。
  - 时间：`services.clock`（`now / tick`）；输入：`services.input`（`VngCommand` 工厂 + `runtime.pump()`）。
  - 事件：`services.events.emit_event / subscribe / history`（事件历史是 P3 trace golden 的基础）。
- **禁止**裸 `randi/randf/randi_range/randf_range/randomize` 与 `Time.*`、`OS.get_ticks_*`；`tools/lint` 会扫描 `game/` 并给出替代建议。
- **GDScript 陷阱**：类方法名不要与全局函数重名（`randi`、`seed` 等）——类内部裸调用会解析为全局函数而非方法。RNG 服务因此使用 `next_*` 命名。
- `game/core/` 零 Node 依赖（全部 RefCounted），headless 直接单测：
  - `VngStoryRuntime`：`start / advance / choose / skip_to / pump / snapshot`；未知跳转与非法操作记录 `errors`，条件引用未定义变量记入 `warnings` 并视为 false。
  - `VngStoryState`：flags(bool) / vars(int)。
  - `VngCondition`：条件表达式（`not/!/&&/||/()/比较`），失败返回 `{ok,error}`。
  - `VngSave`：`capture / apply`（含 rng state 与 clock），`VngSaveStore` 管理槽位（root 可配置）。
- 启动参数（游戏接入时使用）：`--test-mode --seed=N --save-root=user://...` → `VngBootConfig.from_cmdline()`。

## 剧本 DSL 与 trace golden（P3）

- 源文件 `game/story/*.vns`，扩展名与语法见 [decision 0002](docs/decision/0002-story-dsl.md)；改完必须运行 `tools/story build` 重新生成 `game/story/compiled/*.json`（编译产物入库；`tests/unit/test_story_fresh.gd` 会在 fast 测试里检查新鲜度）。
- 语法速览：

```vns
@chapter chapter1

:: prologue
@bg classroom_day
@show yuki happy center
yuki: 早上好！
你推开了门。
* 捡起钥匙 -> pick_key
* 直接离开 {has_key == false} -> hallway

:: pick_key
@set has_key = true
-> hallway
```

- 结构校验与 lint 一次性完成：`tools/story lint`；错误格式 `file:line:col: error: 消息（是否想写 'xxx'？）`，覆盖跳转断链、flag/变量 typo、资源/角色登记、节点可达性。
- 剧本级测试（`tests/story/`）用 playthrough DSL：

```gdscript
var play := VngPlaythrough.new(chapter, self)
play.start_scene("prologue")
play.expect_speaker("yuki").expect_line("早上好！")
play.advance().advance()
play.expect_choices(["捡起钥匙", "直接离开"])
play.choose_text("捡起钥匙")
play.expect_flag("has_key").expect_scene("pick_key")
play.expect_no_errors()
play.expect_trace("chapter1_secret")
```

- trace golden 存于 `tests/story/traces/*.trace.json`，记录**语义事件**（对白/选项/flag 变化/演出指令），不含行号与时间戳；插入新台词不会无故破坏基线。
- golden 更新必须显式执行 `tools/test --update-traces`（禁止默认重录），审计写入 `test-results/trace-updates.log`；比对失败会在测试信息中给出文本 diff。

## 游戏工程（vng-demo）

- 游戏专属代码只在：`vng-demo/game/presentation/`、`vng-demo/game/story/`、`vng-demo/tests/`。
- 框架镜像（**禁止手改**，由 `tools/demo sync` 生成并 gitignore）：`vng-demo/addons/{vng_test,vns}`、`vng-demo/game/{core,services}`；镜像目录带 `.vng-mirror` 标记。
- 改动框架后必须两侧验证：仓库根 `tools/test` 与 `tools/demo test` 都绿。
- 表现层约定：只订阅 `services.events` 与推送 `VngCommand`，不直接改 core 状态；剧情屏通过 `story_screen.setup(services, chapter, node, display_names)` 注入（boot smoke 测试依赖该入口）。
- **表现层测试必须走真实输入路径**：用 `addons/vng_test/dsl/input_sim.gd` 的 `click(tree)` / `press_action(tree, "ui_accept")`，不要直接调用场景内部方法；headless 下窗口尺寸会被重置，helper 已处理（见 [decision 0004](docs/decision/0004-presentation-testing.md)）。
- **场景类测试必须覆盖重入**（完成 → 销毁 → 重进）：事件订阅在 `_exit_tree` 解除；总线对失效 Callable 自动剪除，可用 `listener_count(type, true)` 断言原始槽位。
- 修复类改动做"回退验证"：临时还原修复确认用例变红，防止测试失效。
- 游戏剧本改动后运行 `tools/demo story build`；`vng-demo/tests/unit` 会校验产物新鲜度。
- 手动验收清单见 `vng-demo/README.md`；表现层回归依赖人工体验（V1 政策）。

## 进程模型与报告

- 默认：所有非 `story/` 文件在**一个批量子进程**内顺序执行；`tests/story/` 每文件独立子进程；`--jobs N` 并行；父进程聚合。
- 超时：单用例软超时（默认 10s，超时立即报告并终止该子进程）；子进程硬超时（默认 300s，父进程杀进程并标记 not run）。
- 防假绿：子进程引擎日志中的 `SCRIPT ERROR` 会使对应 suite 变为 error（运行时错误不会静默通过）。
- 报告：`test-results/results.json`（Agent 主接口）、`test-results/junit.xml`、`test-results/artifacts/`。运行产物不入库。

## 目录约定

```
tools/test              # 统一 CLI 入口（仓库根工程）
tools/lint              # 格式/静态/非确定性扫描
tools/story             # 剧本 CLI（仓库根工程）
tools/demo              # 游戏侧统一入口：sync / test / story / lint / run
addons/vng_test/        # 测试框架：core（runner/断言/发现/看门狗）/ reporters / dsl / lint / cli
addons/vns/             # 剧本格式：parser / validator / emitter / 运行时模型 + 编译产物加载器
tests/unit/             # L0 纯逻辑（fast）
tests/meta/             # runner 自身契约测试（fixtures/ 为子进程夹具，自动跳过发现）
tests/story/            # L1 剧本级 E2E（每文件独立进程）
tests/story/traces/     # trace golden（语义事件，提交入库）
tests/fixtures/         # 共享夹具（如 sample_chapter.gd），自动跳过发现
game/core/              # 纯 GDScript 状态机（零 Node 依赖）
game/services/          # RngService / Clock / InputHub / EventBus（接口 + real + fake）
game/story/             # 框架示例剧本（框架自测用）
game/presentation/      # 框架侧表现层占位（游戏表现层在 vng-demo）
test-results/           # 运行产物，不入库
vng-demo/               # 游戏工程（见「游戏工程」小节）
├── game/presentation/  # 标题/剧情屏/舞台/对白/选项/音频
├── game/story/         # 游戏剧本 + compiled/
├── tests/              # 游戏测试（story/smoke/unit）
└── addons/, game/{core,services}/   # 框架镜像（gitignore）
```

## 开发约定

- 每个功能必须同时提交测试；功能未带测试视为未完成。
- 严格 core / presentation 分离：`game/core/` 零 Node 依赖，可在 headless 直接单测。
- 禁止直接使用非确定性 API（见上）；统一走 services。
- 剧本编译产物、trace golden 的更新必须显式批准，禁止"为变绿而更新"。
- 不要删除或改写既有测试来让套件变绿；CI/审查会以 `--min-tests` 兜底。
- GDScript 注意：`var x := <Variant 表达式>` 触发 `inference_on_variant`（Godot 默认按错误处理），请显式声明类型。
- 视觉/表现测试不在 V1 范围；表现层回归依赖人工体验反馈。
- 测试运行产物写入 `test-results/`，不提交入库。

## 关键文档

- 决策：[docs/decision/0001-testing-strategy-v1.md](docs/decision/0001-testing-strategy-v1.md)、[docs/decision/0002-story-dsl.md](docs/decision/0002-story-dsl.md)、[docs/decision/0003-game-project-structure.md](docs/decision/0003-game-project-structure.md)、[docs/decision/0004-presentation-testing.md](docs/decision/0004-presentation-testing.md)
- 计划：[docs/plans/0001-test-framework-v1.md](docs/plans/0001-test-framework-v1.md)

## 当前阶段

第一条可玩切片已完成并完成首轮体验修复：`vng-demo/` 游戏工程（标题 → 演出 → 选项分支 → END 回标题）、框架单向镜像与 `tools/demo` CLI、占位演出、静音音频接口、游戏剧本《雨夜车站》、story/trace/smoke/输入路径测试。
下一步候选：存档 UI、真实美术/音频接入、多章节运行时、`vng-demo` 导出配置、场景语义断言库。
