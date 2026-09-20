# 0005 · 资源管线约定（真实素材接入机制）

- 状态：已接受
- 日期：2026-09-14
- 关联决策：[0001](0001-testing-strategy-v1.md)、[0002](0002-story-dsl.md)、[0003](0003-game-project-structure.md)

## 背景

切片阶段所有表现均为代码绘制的占位（色块/标签）与静音音频。需要一套"**零素材可用、投放即生效**"的资源接入机制：

- 用户/Agent 随时投放素材，无需改剧本或代码；
- 缺失资源有确定性的回退（占位），且该行为可被测试覆盖；
- Agent 能快速回答"还缺哪些素材、应该放在哪里"。

## 决策

### 1. 目录与命名约定

| 类别 | 路径 | 说明 |
| --- | --- | --- |
| 背景 | `assets/bg/<id>.{png,webp,jpg}` | 铺满屏幕（KEEP_ASPECT_COVERED） |
| 立绘 | `assets/char/<char_id>/<expr>.{png,webp,jpg}` | 透明底、底部对齐（KEEP_ASPECT_CENTERED） |
| 立绘缺省 | `assets/char/<char_id>/default.<ext>` | 表情未提供时的同级回退 |
| BGM | `assets/audio/bgm/<id>.{ogg,wav}` | |
| 音效 | `assets/audio/sfx/<id>.{ogg,wav}` | |

扩展名优先级：图片 `png → webp → jpg`；音频 `ogg → wav`。

### 2. 回退链

**真实文件 → 同级缺省（仅立绘 default）→ 代码占位**。零素材时行为与切片阶段完全一致（色块 + 标签、静音），剧本与测试无需感知素材是否存在。

### 3. 加载语义（开发友好）

1. 先走 `ResourceLoader`（覆盖已导入资源与导出构建）；
2. 资源未导入但文件存在时回退散文件加载：`Image.load_from_file` + `ImageTexture`；`AudioStreamWAV/AudioStreamOggVorbis.load_from_file`（**调用前必须 `FileAccess.file_exists`**，否则引擎报错）；
3. `AssetLibrary` 缓存命中结果与缺失列表（`missing_report()`）。

### 4. 规则复用

候选路径与回退规则集中在 `addons/vns/vns_asset_paths.gd`，报告工具与运行时共用，防止两处漂移。

### 5. 资源就位报告

- `tools/story assets [--asset-root <dir>] [--strict] [--json]`（框架级，任意游戏可用）
- `tools/demo assets`（游戏侧转发，默认 `res://assets`）
- 默认信息性（exit 0）并列出候选路径与"未使用"清单；`--strict` 时任一缺失即 exit 1（供后续 CI/发布前检查）

## 后果

- 用户投放素材后无需打开编辑器或重新导入，`tools/demo run` 直接生效；导出构建走导入资源。
- 视觉升级完全由素材驱动，代码零改动；立绘只需一张 `default.png` 即可先跑通。
- 损坏/格式错误的文件按"缺失"处理（回退占位并计入报告）。

## 被否决方案

| 方案 | 否决原因 |
| --- | --- |
| 只用 `ResourceLoader`（强制导入） | 投放后需打开编辑器导入，违背"投放即生效" |
| 在 `story.json` 中登记文件路径 | 冗余、易漂移；逻辑 id + 约定目录已足够 |
| 缺失资源直接报错终止 | 零素材阶段不可用，与占位回退策略冲突 |
