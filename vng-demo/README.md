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
├── game/presentation/   # 表现层：main / title_screen / story_screen / stage / audio_director
├── game/story/          # 剧本：story.json 清单 + chapter1.vns（编译产物 compiled/）
├── tests/               # 游戏测试：story 路线 + trace golden + boot smoke
├── assets/audio/        # 音频资源目录（切片阶段为空，接口已留）
├── addons/              # ← 框架镜像（tools/demo sync 生成，勿手改）
└── game/core,game/services/  # ← 框架镜像（同上）
```

镜像目录带 `.vng-mirror` 标记；修改框架请回仓库根目录对应路径，然后 `tools/demo sync`。

## 操作

- 左键 / 空格 / 回车：推进对白（打字中先补全当前行）
- 点击选项按钮：选择分支（键盘空格作用于当前焦点按钮）
- ESC：退出

## 手动验收清单（第一条可玩切片）

- [ ] `tools/demo run` 启动，出现标题「雨夜车站」，窗口 1280×720
- [ ] 「开始游戏」→ 背景色块与立绘占位出现，旁白/对白逐字显示
- [ ] 第一次点击补全当前行，再点一次进入下一行
- [ ] 选项出现时以按钮菜单呈现，鼠标与空格（焦点）都可选择
- [ ] 「把伞递过去」→ 凛的立绘位置变为中央（标签 smile/center）→ 平台 → 咖啡馆路线
- [ ] 「什么都不做」→ 平台只显示「独自离开车站」（隐藏分支不可见）
- [ ] 结束后淡出回到标题，可再次开始
- [ ] ESC 可退出；全程无脚本报错
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
- 投放后无需改代码或重新导入，直接 `tools/demo run` 生效；缺失项自动回退占位
- 当前待投放清单（7 项）：`bg/station_rain`、`bg/cafe_night`、`char/rin/normal`、`char/rin/smile`、`bgm/bgm_rain`、`sfx/thunder`、`sfx/bell`
- 捷径：只放 `char/rin/default.png` 也能先跑（所有表情回退到它）

## 已知限制（切片范围外）

- 无存档/读档与设置界面；无音频资源（`assets/audio/` 空，缺资源静默）
- 占位美术为纯色块 + 标签（背景/立绘/表情均为代码生成）
- 单章节运行时（跨章节跳转在第一条切片后评估）
