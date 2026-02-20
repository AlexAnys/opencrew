# Changelog

All notable changes to this repository will be documented in this file.

The format is loosely based on Keep a Changelog.

## [0.1.1] — 2026-02-20

### Changed
- README (both languages): added 🤖 Agent-Ready Deployment badge
- README.en.md "Get Started in 10 Minutes": updated from bash commands to to-agent deployment flow (matching Chinese version from v0.1.0)
- DEPLOY.en.md: added "Execution Prompt for OpenClaw" section — structured 6-step instructions for agent-driven deployment
- DEPLOY.en.md: updated Method A prompt to match Chinese version (cleaner, shorter)
- DEPLOY.en.md: opening rewritten to clearly state the doc is designed for direct agent consumption

## [0.1.0] — 2026-02-19

### Changed
- README「10 分钟上手」：从 3 步 bash 命令改为「建频道 → 发指令给 OpenClaw → 验证」，非技术用户友好
- DEPLOY.md 方式 A：用户 prompt 从 12 行 6 步流程简化为自然语言（token + 频道映射 + 一句话）
- README: 全面重构——以痛点驱动开场、新增 TOC/badges/FAQ/文档导航表、定位为"给决策者的多智能体操作系统"
- ARCHITECTURE.md: 精简与 CONCEPTS.md 重复的内容，聚焦设计取舍和 Why
- SLACK_SETUP.md: 移除本地路径引用，对齐"从 3 个频道开始"的定位
- CUSTOMIZATION.md: 修复 `openclaw restart` → `openclaw gateway restart`
- JOURNEY.md: 精简与新文档重复的"给新用户的建议"和"为什么开源"段落
- DEPLOY.md: 新增定位说明（精简版 vs 完整上手指南）
- SCREENSHOTS.md: 为每张截图添加说明文字
- DECISIONS.md: 转为中文，移至 docs/maintainers/
- maintainers/README.md: 修复中英混排错误，全面转为中文
- 所有保留文档统一添加面包屑导航

### Added
- DEPLOY.md「给 OpenClaw 的执行提示」：结构化 6 步指引 + Slack API 自动获取 Channel ID
- docs/GETTING_STARTED.md: 完整上手指南（4 阶段部署 + 常见报错 + 验证清单）
- docs/CONCEPTS.md: 核心概念一站式页面（9 个关键机制详解）
- docs/AGENT_ONBOARDING.md: Agent 入职指南（给 AI Agent 读的系统理解文档）
- docs/FAQ.md: 常见问题（19 个 Q&A，覆盖基础/架构/使用/部署/知识系统）
- README: "相关资源"段落（OpenClaw 官方文档链接）

### Removed
- docs/SKILLS.md: 内容过薄且无文档引用，信息已整合到 FAQ

### Fixed
- README: "token 消耗更低效" → "更少"（语义修正）
- README: PRs Welcome badge 指向不存在的 CONTRIBUTING.md → 改为锚点链接
- SLACK_SETUP.md: 移除暴露本机路径的引用 (`/opt/homebrew/...`)

## [0.0.1] — 2026-02-15

- Initial open-source release (docs + shared + workspaces + patches).
