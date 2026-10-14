# vng-demo · 第一条可玩切片

基于 Godot VNG AI Framework 的示例游戏工程（雨夜车站）。

## 运行

```
tools/demo run          # 同步框架 + 启动游戏（也可在 Godot 编辑器中直接 F5）
tools/demo test         # 同步框架 + 运行游戏测试（unit + story + smoke）
tools/demo story build  # 修改 .vns 后重新编译
```

## 结构

```
vng-demo/
├── game/presentation/   # 表现层：main / title_screen / story_screen / ending_screen / menu_overlay / settings_panel / backlog_panel / stage / audio_director
├── game/story/          # 剧本：story.json 清单 + chapter1~3.vns（编译产物 compiled/）
├── tests/               # 游戏测试：story 路线 + 结局页 + trace golden + 存档/菜单 + 体验层 + boot smoke
├── assets/audio/        # 音频资源目录（切片阶段为空，接口已留）
├── addons/              # ← 框架镜像（tools/demo sync 生成，勿手改）
└── game/core,game/services/  # ← 框架镜像（同上）
```

镜像目录带 `.vng-mirror` 标记；修改框架请回仓库根目录对应路径，然后 `tools/demo sync`。

## 操作

- 左键 / 空格 / 回车：推进对白（打字中先补全当前行）
- 点击选项按钮：选择分支（键盘空格作用于当前焦点按钮）
- ESC：打开/关闭菜单（返回 / 保存 / 读取 / 设置 / 回到标题）
- `Ctrl`（按住）：跳过**已读**；遇未读行 / 选项 / 面板即停（底栏「跳过」同效）
- `A`：自动播放开关（底栏「自动」高亮；选项前停）
- `B`：回顾（本次会话跨章记录，含选项选择；上限 400 条）
- 标题屏「继续游戏」：读取**最近写入**的存档（无存档时隐藏）
- 标题屏「读取存档」：直接选择具体槽位（自动 / 存档 1–3）
- 标题屏 / ESC 菜单「设置」：BGM / 音效音量、文字速度（慢/标准/快/瞬间）、自动间隔；即时生效并持久化
- 结局：达成 3 个结局之一后进入结局页面（结局名 / 副标题），点「回到标题」返回

## 手动验收清单（第一条可玩切片）

- [ ] `tools/demo run` 启动，出现标题「雨夜车站」，窗口 1280×720
- [ ] 「开始游戏」→ 背景与立绘出现，旁白/对白逐字显示
- [ ] 第一次点击补全当前行，再点一次进入下一行
- [ ] 选项出现时以按钮菜单呈现，鼠标与空格（焦点）都可选择
- [ ] 「把伞递过去」→ 咖啡馆路线 → 第二章《清晨》 → 第三章《余雨》「去赴约」→ 结局 · 伞下的约定 → 结局页面 → 回到标题
- [ ] 「什么都不做」→ 「独自离开车站」→ 第三章「去车站看看」→ 结局 · 各自的路；或「待在家里」→ 结局 · 一个人的雨
- [ ] 结局页面显示 结局名 + 副标题；「回到标题」后「继续游戏」可回到最近存档
- [ ] 游戏中 ESC 打开菜单；「保存游戏」写入存档 1，槽位显示 章节·时长·台词预览
- [ ] 「回到标题」→「继续游戏」读回最近写入的档；「读取存档」可直接选任意槽位
- [ ] 「读取游戏」可载入自动档（进入章节时自动写入）
- [ ] 第二轮游玩：按住 `Ctrl` 可快进已读对白，遇新对白停下；底栏「跳过」同效
- [ ] 底栏「自动」开启后自动推进，到选项停；再点关闭
- [ ] `B` 或底栏「回顾」：能看到本轮对白/旁白/选项与章节标题，可滚动，ESC 关闭
- [ ] 设置面板：文字速度改为「瞬间」后立即整行显示；音量滑到 0 后音频静音（音频投放后验证）
- [ ] 通关任一结局后回到标题，可再次开始；全程无脚本报错
- [ ] `tools/demo test` 全绿；`tools/demo story check` 通过

## 资源投放（真实美术/音频）

约定见 [docs/decision/0005](../docs/decision/0005-asset-pipeline.md)。目录：

```
vng-demo/assets/
├── bg/<id>.png|webp|jpg             # 背景（铺满）
├── char/<角色>/<表情>.png|webp|jpg   # 立绘（透明底；缺省回退 default.<ext>）
└── audio/{bgm,sfx}/<id>.ogg|wav     # 音频
```

- 查看还缺什么：`tools/demo assets`（`--strict` 缺失即非零退出；`--json` 结构化输出）
- 完整需求清单（尺寸/风格/提示词/验收）：[ASSETS.md](ASSETS.md)
- 投放后无需改代码或重新导入，直接 `tools/demo run` 生效；缺失项自动回退占位
- 已就位（4/7）：`bg/station_rain`、`bg/cafe_night`、`char/rin/normal`、`char/rin/smile`（另有 `char/rin/default` 表情兜底）
- 剩余待投放（3，均为音频）：`bgm/bgm_rain`、`sfx/thunder`、`sfx/bell`

## 已知限制（切片范围外）

- 占位美术为纯色块 + 标签（真实背景/立绘已投放；音频缺失时静默）
- 存档固定为 自动 + 3 手动槽；设置仅含 音量 / 文字速度 / 自动间隔（无窗口/按键重映射）
- 回顾不持久化（重启清空）、无「跳到下一选项」专用模式
- 无语音（TTS 配音管线为下一步候选）
