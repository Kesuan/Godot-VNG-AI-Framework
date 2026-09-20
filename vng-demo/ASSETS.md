# 素材需求清单（美术 + 音频）

> 用途：自绘 / 外包 / AI 生成的投放依据。
> 目录、命名与回退规则见 [docs/decision/0005](../docs/decision/0005-asset-pipeline.md)；当前进度自检：`tools/demo assets`。

## 进度

- [ ] `bg/station_rain`（背景 · 雨夜站台）
- [ ] `bg/cafe_night`（背景 · 夜晚咖啡馆）
- [ ] `char/rin/normal`（立绘 · 平静）
- [ ] `char/rin/smile`（立绘 · 微笑）
- [ ] `bgm/bgm_rain`（BGM · 雨夜主题）
- [ ] `sfx/thunder`（音效 · 闷雷）
- [ ] `sfx/bell`（音效 · 站台提示铃）

只放 `char/rin/default.png`（可直接复制 normal）即可让立绘全部先跑起来；任意素材缺失都会自动回退占位，可分批投放。

## 一、风格基调（务必统一）

- **题材**：现代都市 · 雨夜 · 温柔静谧
- **画风**：日系动画风（赛璐璐上色）、干净线稿、柔和体积光、轻微电影感
- **色调**：车站＝冷蓝紫夜色；咖啡馆＝暖黄灯光。两张背景必须像"同一个世界的夜晚"
- **光源方向**：统一为上方偏左的柔和冷光（雨夜），立绘受光需与背景一致

AI 生成参考前缀（**整批保持一致**：同一模型、同一风格前缀，仅替换主体描述）：

```text
背景前缀：anime visual novel background, cel-shaded, clean lineart, cinematic soft light,
rainy night, muted blue-purple palette, no text, no characters, 16:9
立绘前缀：anime visual novel character sprite, full body, standing, transparent background,
cel-shaded, clean lineart, soft rim light, 3:4 canvas, centered, feet near bottom edge
```

## 二、视觉素材

### P0 · 必须（当前章节）

| # | ID | 类型 | 用途（剧本节点） | 规格 |
| --- | --- | --- | --- | --- |
| 1 | `bg/station_rain` | 背景 | `prologue` 开场 | 1920×1080（≥1280×720），JPG/PNG/WebP |
| 2 | `bg/cafe_night` | 背景 | `cafe_invite` | 同上 |
| 3 | `char/rin/normal` | 立绘 | `prologue`（left） | PNG 透明底，建议 900×1200（3:4） |
| 4 | `char/rin/smile` | 立绘 | `share_umbrella` / `cafe_invite`（center） | 与 normal **同画布同服装同姿态**，仅表情不同 |

**内容描述**

1. **`bg/station_rain`**：雨夜露天站台。顶棚与支柱、湿滑地面反光、延伸的铁轨、一张长椅（剧情里少女就站在长椅旁）；雨幕细密，远处有零星城市灯光。氛围：孤寂、安静。
   - 提示词补充：`empty train platform at night, heavy rain, glass canopy and pillars, wet reflective ground, railway tracks, bench, distant city lights, lonely quiet mood`
   - 注意：底部约 200px 会被对白框遮挡，不要把关键内容放那里；画面中不要出现人物与文字。
2. **`bg/cafe_night`**：夜晚咖啡馆内景（站前小店）。暖黄吊灯、吧台与卡座、玻璃窗上的雨珠与窗外夜色街灯。氛围：温暖、松弛。
   - 提示词补充：`cozy small cafe interior at night, warm pendant lights, wooden counter and booth seats, rain droplets on windows, warm inviting mood`
3. **`char/rin/normal`**：凛，被雨淋湿的少女。深色短发（发梢滴水）、简洁外套或制服、平静略带疲惫的神情，站姿自然。
   - 提示词补充：`young woman, wet dark short hair, casual jacket, calm tired expression, rain-soaked clothes`
   - 注意：同一角色的**所有表情必须使用同一画布尺寸**（否则切换表情会跳动）；人物水平居中、脚底贴近画布下边（留 10–20px 内边距）。
4. **`char/rin/smile`**：同角色同姿态，仅表情变化——浅浅微笑、略脸红。
   - 提示词补充：`same character, same pose and outfit, gentle smile, slightly blushing`

### P1 · 建议

| ID | 说明 |
| --- | --- |
| `char/rin/default` | 表情兜底（没有对应表情文件时使用）；可直接复制 `normal.png` |

### P2 · 后续（不阻塞当前切片）

| ID | 说明 |
| --- | --- |
| `char/rin/{sad,surprised,angry}` | 后续章节表情扩展（沿用同一画布） |
| `bg/title` | 标题页背景（当前为纯色 + 文字） |
| UI 皮肤 | 对话框底框 / 选项按钮（当前为 Godot 默认主题） |
| `icon.svg` | 窗口与应用图标（当前为 Godot 默认） |

## 三、音频素材（附）

| ID | 用途 | 时长 | 说明 |
| --- | --- | --- | --- |
| `bgm/bgm_rain` | `prologue` / `cafe_invite` | 45–90s，**无缝循环** | 雨声 + 钢琴/弦乐氛围，安静不抢台词 |
| `sfx/thunder` | `prologue` 开场 | 1–3s | 闷雷，不刺耳 |
| `sfx/bell` | `platform` 广播前 | 1–3s | 站台提示铃（两声短铃） |

格式：OGG 优先（WAV 亦可）。

## 四、投放与验收

1. 按 ID 命名（全小写、与上表完全一致）放入：
   ```
   vng-demo/assets/bg/<id>.png
   vng-demo/assets/char/rin/<expr>.png
   vng-demo/assets/audio/bgm/<id>.ogg
   vng-demo/assets/audio/sfx/<id>.ogg
   ```
2. `tools/demo assets` → 期望 `7/7 就位`；`tools/demo assets --strict` 退出码 0
3. `tools/demo run` 体验检查：
   - 开场：车站背景 + 凛 normal 立绘 + 雨声氛围 + 雷声
   - 递伞后：凛切到 smile（位置居中，不跳动）
   - 平台：提示铃；进入咖啡馆：暖色背景切换
4. `tools/demo test` 应保持全绿（素材存在与否都不影响测试）

## 五、版权

仅使用自有或可商用授权的素材；AI 生成请确认所用模型/服务的商用条款。
