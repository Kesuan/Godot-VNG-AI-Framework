# 0002 · 剧本数据格式决策（自定义文本 DSL）

- 状态：已接受
- 日期：2026-09-14
- 关联决策：[0001 · V1 测试策略](0001-testing-strategy-v1.md)
- 关联计划：[docs/plans/0001-test-framework-v1.md](../plans/0001-test-framework-v1.md)

## 背景

"剧本数据格式"指 VNG 叙事内容（对白、旁白、选项、跳转、flag/变量、演出指令）的书写与存储形式。它是：

- `StoryRuntime` 的唯一输入
- StoryLinter 的检查对象（跳转/资源/flag/本地化）
- trace golden 与失败定位的基础

该格式必须同时满足：Agent 可高频生成与修改、静态可分析、Git diff 可读、零外部工具链依赖。

## 决策

1. **作者格式：自定义文本 DSL，扩展名 `.vns`**（Ink 风格，但语法更小、更严格）。
   面向可读性与 diff 质量，人类未来也可参与写作。

2. **编译为规范 JSON 模型，作为运行时/lint/trace 的唯一契约。**
   编译产物是机器接口；DSL 只是作者语法。源语法演进不破坏下游。

3. **两层静态校验：**
   - 编译期结构校验（硬错误）：语法、节点 id、跳转目标、选项目标、类型。
   - 图分析 lint（可配置）：节点可达性、flag/变量读写一致性（防 typo）、资源引用、本地化 key。

4. **行号溯源贯穿全链路。**
   编译产物每个 step 携带 `src: {file, line}`；事件、trace、测试失败都能映射回 `.vns` 源文件行号。

5. **编译产物提交入库，`--check` 保证新鲜度。**
   `tools/story build` 生成 `game/story/compiled/*.json`（导出直接用）；
   `tools/story check` 检测"源文件已改但产物未重编"，纳入 fast 测试。

6. **V1 语法范围：逻辑完备、演出最小。**
   对白/旁白/选项/跳转/flag/变量 + 演出指令（bg/show/hide/bgm/sfx）。
   子程序、内联条件块、配音、显式本地化 key、编辑器插件均为扩展点，不影响现有语法。

## 语法 v1

```vns
# game/story/chapter1.vns
# 行注释：整行以 # 开头（无内联注释，避免与文案歧义）

@chapter chapter1

:: prologue
@bg classroom_day fade=0.5
@show yuki happy center
@bgm bgm_daily
yuki: 早上好！
你推开了门。
* 打招呼 {trust >= 2} -> greet_warm
* 打招呼 -> greet
* 无视 -> ignore

:: greet_warm
@set met_yuki = true
yuki: 你终于来了，我等了好久。
-> chapter2.secret

:: greet
@set met_yuki = true
yuki: 太好了。
-> chapter2.secret

:: ignore
yuki: ……
-> END
```

规则要点：

| 元素 | 语法 | 说明 |
| --- | --- | --- |
| 注释 | `# ...` | 仅整行注释 |
| 章节声明 | `@chapter <id>` | 每文件一条，需与文件名一致 |
| 节点 | `:: <node_id>` | id 全局唯一（章内短名，跨章 `chapter.node`） |
| 对白 | `<speaker>: <text>` | speaker 须为 `[a-z_][a-z0-9_]*` |
| 旁白 | `<text>` | 不以 `@ * -` 开头、无 speaker 前缀的行 |
| 选项 | `* <text> [{cond}] -> <target>` | 每个选项必须带跳转目标 |
| 跳转 | `-> <target>` | `node` / `chapter.node` / `END` |
| flag/变量 | `@set <name> = <expr>` / `@set <name> += <int>` | bool 与 int 两类 |
| 演出指令 | `@bg @show @hide @bgm @sfx` | 运行时发出事件，presentation 层消费 |
| 转义 | `\` 行首 | 文案需以特殊字符开头时使用 |

语义约束：

- 节点必须以跳转或选项结尾（显式退出，禁止隐式落到下一节点）——图分析因此无歧义。
- 选项条件 `{...}` 使用受限表达式：`not && || () == != > >= < <=`，操作数为 flag/变量/字面量。
- 资源以逻辑 id 引用，通过 `game/story/story.json` 清单解析；linter 校验存在性。

## 编译管线

```
game/story/*.vns ──lexer/parser──> AST ──结构校验──> 规范模型 ──emit──> game/story/compiled/*.json
                                   │
                                   └── 图分析 lint（死链/可达性/flag 一致性/资源/本地化）
```

- 产物含 `schema` 版本、`source_hash`、每 step 的 `src` 行号。
- 错误格式（Agent 友好）：`chapter1.vns:42:3: error: jump target 'gret' not found (did you mean 'greet'?)`
- CLI：`tools/story build` / `tools/story check` / `tools/story lint`。

## 对测试框架的影响

- Linter 直接工作在编译模型上，无需重复解析 DSL。
- trace golden 记录**语义事件**（speaker+text / choice id / flag 变化），而非位置索引——插入新台词不会无故破坏基线。
- 失败信息可附 DSL 源码位置：`expected flag 'met_yuki' true at chapter1.vns:18`。

## 后果与取舍

- 需要实现 parser 与高质量错误报告（一次性成本，换来长期可读性）。
- 编译步骤引入"产物新鲜度"问题，用 `--check` + fast 测试兜底。
- 文案 inline 存储，本地化 key 由后续提取工具生成（V1 不做）。
- 相比纯 JSON：人类可读、token 更省、diff 更干净；相比 Ink：零外部工具链、语法受控、静态分析完整。

## 被否决方案

| 方案 | 否决原因 |
| --- | --- |
| 自定义 JSON schema（原推荐） | 可读性与 diff 质量差、token 开销大；编译模型已吸收其结构化优势 |
| Ink + GodotInk | 需外部编译工具链，破坏零依赖 Agent 闭环；静态分析困难 |
| Godot Resource (.tres) | diff 噪音大（UID）、Agent 编辑风险高、CLI lint 不便 |
