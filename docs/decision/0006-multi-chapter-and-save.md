# 0006 · 多章节运行时与存档

- 状态：已接受
- 日期：2026-10-09
- 关联决策：[0001](0001-testing-strategy-v1.md)、[0002](0002-story-dsl.md)、[0003](0003-game-project-structure.md)、[0005](0005-asset-pipeline.md)

## 背景

切片阶段 `VngStoryRuntime` 绑定单章执行；`story.json` 虽然已登记有序 `chapters`，跨章跳转却在运行时被拒绝。同时 `game/core` 已有 `VngSave` / `VngSaveStore`（capture/apply 含 RNG 与时钟），但游戏表现层零接线：没有继续、没有存档槽。

目标：支持多章节叙事与存档/读档闭环，为内容扩张做准备；保持单章执行器简单可测。

## 决策

### 1. 章末语义

| 语法 | 语义 |
| --- | --- |
| `-> END` | 结束**当前章节**：存在下一章时自动进入其入口；已是最后一章则全书结束 |
| `-> STORY_END` | 提前结束**全书**（坏结局 / 跨章终结），后续章节不再执行 |
| `-> chapter.node` | 显式跨章跳转（parser / linter 原有支持，session 负责切换） |

单章剧本行为与旧版一致（最后一章 `END` = 全书结束），现有剧本零改动。

### 2. 每章入口（story.json）

- `entry`：全书入口（新游戏起点），保持必填；
- `entries`：章节 → 入口节点映射。多章节剧本必须为每个章节登记（linter 强制）；单章可省略、沿用 `entry`；
- 入口节点不存在 → lint 报错（带 did-you-mean）；`entries` 键未在 `chapters` 登记 → lint 报错。

### 3. 会话（VngStorySession）

- 位置 `game/core/story_session.gd`（RefCounted，零 Node 依赖）；
- 职责：持有 manifest + 全部章节 + 当前 runtime；跨章延续 flags / vars / stage；章末推进与显式跨章跳转；
- runtime 保持纯单章执行器；跨章跳转通过 `cross_chapter_handler` 回调交还 session；
- 语义事件：`chapter_finished` / `chapter_started` / `story_finished`（进入 trace 归约）。

### 4. 存档格式 v2

- 字段：`version=2`、`story_hash`、`chapter`、`node`、`step`、`waiting`、`ended`、`flags`、`vars`、`stage`、`line`、`rng_state`、`play_time`、`save_seq`；
- `save_seq`：写入时由表现层赋值（现存最大序号 + 1，纯确定性）；「继续」按最大序号读取，缺失（旧档）时回退按 `play_time` 排序；
- `story_hash`：manifest（entry/entries/章节顺序）+ 各章 `source_hash` 摘要。剧本改动后读旧档被拒绝并给出明确提示；
- 读档：按档内 `chapter` 装载对应章节（**不**经过入口节点），恢复步骤/等待/舞台；表现层随后重绘；
- 槽位：`VngServices.save_root` 下 `auto`（自动）+ `slot1`~`slot3`（手动），槽位名沿用 `VngSaveStore` 白名单；
- 标题「继续」= 读取 `play_time` 最大的有效存档；进入新章节时写自动档；
- `story.json` 可选 `titles`（章节 id → 显示名）供槽位/章节卡展示，缺省回退章节 id。

### 5. UI 范围（vng-demo）

- 标题屏：继续 / 新游戏 / 读取存档 / 退出；无存档时「继续」「读取存档」隐藏；
- 游戏内 Esc 菜单：继续 / 存档 / 读档 / 回标题；标题屏「读取存档」可直接选择任意槽位（复用槽位弹层）；
- 槽位信息：章节标题 · 节点 · 游戏时长 · 台词预览；**不做**缩略图（视觉测试超出 V1 范围）。

## 后果

- 线性多章剧本零新增语法：每章以 `-> END` 结尾即可自动串联；
- 存档与剧本内容强绑定（`story_hash`）：开发期改剧本后旧档明确失效，避免静默错位；
- trace golden：会话级新增 chapter/story 事件；单章（runtime 级）golden 不受影响；
- 可达性 lint 将 `entries` 入口视为可达种子（`END` 隐式推进无法静态追踪的近似）。

## 被否决方案

| 方案 | 否决原因 |
| --- | --- |
| runtime 直接持有全部章节 | 破坏单章执行器的简单性，错误定位与测试复杂度上升 |
| `END` 保持全书结束 + 新增 `NEXT` 表示章末 | 现有剧本需改写；多章语境下 `END` 更自然 |
| 不写版本/哈希进存档 | 剧本改动后读旧档会静默错位，难以定位 |
| 存档缩略图 | 涉及渲染与视觉断言，超出 V1 范围 |
