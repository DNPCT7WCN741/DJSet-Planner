# DJ Set Planner

一款基于 AI 的 DJ 演出计划生成工具，专为 iOS 设计。

## 功能

- **AI 演出计划生成** — 由 DeepSeek 驱动，根据演出类型、时长、BPM 范围和曲风生成完整的 Track-by-Track 演出计划，包含能量曲线、过渡方式和氛围描述
- **曲风预设选择器** — 内置 15 种曲风（Liquid DnB、Neurofunk、Techno、Deep House、Trance 等），选择后自动填充推荐 BPM 范围和风格标签
- **曲目推荐** — 使用 Apple iTunes Search API（免费、无需账号）为每个 slot 并发搜索推荐曲目，点击直接跳转 Apple Music
- **中英双语** — 支持中文 / English 一键切换，AI 返回内容随语言设置变化
- **演出导出** — 将完整演出计划（含推荐曲目）导出为文本，通过系统分享菜单分享

## 演出类型

| 类型 | 说明 |
|------|------|
| 热场 (Warm-Up) | 从低能量开始逐步爬升 |
| 高潮 (Peak) | 全程维持高能量，动态起伏 |
| 收尾 (Closing) | 从高峰缓步收尾，BPM 递减 |

## 内置曲风预设

| 曲风 | BPM 范围 |
|------|----------|
| Liquid DnB | 170–176 |
| Neurofunk | 172–178 |
| Techno | 130–145 |
| Minimal Techno | 128–138 |
| Deep House | 118–126 |
| Tech House | 124–132 |
| Progressive House | 125–132 |
| Melodic Techno | 130–140 |
| Trance | 136–145 |
| Dubstep | 138–145 |
| Jungle | 160–170 |
| Ambient | 60–100 |
| Afro House | 120–128 |
| Hard Techno | 140–155 |
| Custom（自定义） | 自由填写 |

## 技术栈

- **语言**: Swift 5.9+
- **框架**: SwiftUI + Combine
- **并发**: Swift Structured Concurrency (`async/await`, `TaskGroup`, `actor`)
- **AI**: [DeepSeek API](https://platform.deepseek.com)（OpenAI 兼容格式，模型 `deepseek-chat`）
- **曲目搜索**: [iTunes Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/)（Apple 公开接口，免费无需认证）
- **目标平台**: iOS 17+

## 项目结构

```
DJSetPlanner/
├── DJSetPlanner.swift        # 全部逻辑与 UI（单文件架构）
├── DJSetPlannerApp.swift     # @main 入口
├── ContentView.swift         # 空（占位）
└── Item.swift                # 空（占位）
```

## 运行方法

1. 用 Xcode 打开 `DJSetPlanner.xcodeproj`
2. 选择模拟器或真机（iOS 17+）
3. Build & Run（⌘R）

无需配置任何 API Key——DeepSeek Key 已内置，iTunes Search API 无需认证。

## 注意事项

- DeepSeek API Key 硬编码在源码中，仅用于个人开发测试，不建议公开发布
- iTunes Search API 为 Apple 公开接口，无速率限制文档，请勿高频轮询
- 曲目推荐基于关键词搜索，结果为真实曲目但不保证与 DJ 风格完全匹配
