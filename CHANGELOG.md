# Changelog

All notable changes to this repository will be documented in this file.

The format is loosely based on Keep a Changelog.

## [0.2.2] — 2026-03-05

OpenCrew 从 Slack 专属扩展为三平台支持，并为飞书和 Discord 提供了独立 Bot 身份方案。

### Added — 多平台支持
- **飞书接入指南** `docs/FEISHU_SETUP.md` (zh + en): 从零创建飞书自建应用、配置权限和事件订阅、群组绑定，含 Lark 国际版指引
- **Discord 接入指南** `docs/DISCORD_SETUP.md` (zh + en): 创建 Discord Application + Bot、Gateway Intent 配置、频道绑定，含 Thread 使用说明
- **平台配置参考** `docs/CONFIG_SNIPPET_FEISHU.md` / `CONFIG_SNIPPET_DISCORD.md` (zh + en): 可直接合并到 `openclaw.json` 的配置片段

### Added — 独立 Bot 身份（飞书 & Discord 进阶）
- **飞书多应用模式**: 为每个 Agent 创建独立飞书应用，利用 OpenClaw 原生 `accounts` 多账户配置实现独立身份、独立 API 配额和权限隔离
- **Discord Bot 身份方案**: 三种方案对比（单 Bot / Webhook Relay / 多 Bot），含各自适用场景和限制说明
- **README 平台选择表**: 新增"Agent 独立身份"列，一目了然三个平台的 Bot 模式差异

### Changed
- **README** (zh + en): tagline 改为"支持 Slack·飞书·Discord"，10 分钟上手新增平台选择表和三平台部署提示词
- **DEPLOY.md** (zh + en): Step 3-5 扩展为三平台（Channel/Group ID 获取、平台配置写入、bindings 适配）
- **AGENT_ONBOARDING.md** (zh + en): 频道对照表扩展为三平台，"Slack 频道=工位"改为"频道/群组=工位"

### Design Principle
- 三个平台共享同一套 Agent 协议（shared/）和工作区结构（workspaces/），仅渠道层配置不同
- 独立 Bot 模式作为"进阶"章节增量补充，不改变默认的单 Bot 部署流程
- 配置参考文件（CONFIG_SNIPPET）保持单 Bot 模式，避免高风险的 copy-paste 误操作

## [0.2.0] — 2026-02-27

### Added
- **docs/A2A_SETUP_GUIDE.md** (zh + en): To-Agent guide for setting up and validating A2A closed-loop — includes config checklist, workspace patch templates, Round0 handshake, and validation steps
- **README** (both languages): new "跑通 A2A 闭环 / Enable A2A Closed-Loop" section with copy-paste prompt for agent-driven A2A setup

### Changed
- **shared/A2A_PROTOCOL.md**: incorporated 3 battle-tested patterns from real CTO↔Builder and CTO↔Ops runs:
  - §2.5 Multi-round WAIT discipline + Round0 audit handshake
  - Step 2 timeout handling + sessionKey caution
  - §3 Dual-channel trace + closed-loop DoD (4-step hard rule)
- **workspaces/cto/AGENTS.md**: expanded A2A dispatch section — added thread trace, #cto checkpoint sync, timeout handling, and 4-step DoD
- **workspaces/builder/AGENTS.md**: added A2A collaboration section — multi-round WAIT discipline, thread trace, REPLY_SKIP protocol

### Design Principle
- All workspace changes are **append-only / incremental** — no rewrites of existing sections
- A2A setup guide designed for **agent consumption** (Ops reads and executes) with minimal human intervention

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
