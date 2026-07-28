<!--
  🇨🇳 中文用户请直接往下读
  🇺🇸 English speakers: scroll down for the English section
-->

<p align="center">
  <img src="https://img.shields.io/github/stars/lingling1989r/AuraBaba_Ops_Skill?style=social" alt="GitHub Stars">
  <img src="https://img.shields.io/github/license/lingling1989r/AuraBaba_Ops_Skill" alt="License">
</p>

# 🚀 AuraBaba Ops Skills

> **用嘴部署，用 AI 运维。**  
> 把 Docker 构建、镜像推送、服务器部署这些重复劳动，交给你的 AI 队友。

---

## 🤔 你是不是也…

- 😫 每次部署都要敲一串 `docker build`、`docker push`、`ssh`、`docker compose up`？
- 😰 半夜改完 Bug，手动部署时手滑打错命令搞挂服务？
- 😵 换台电脑就忘了服务器 IP、SSH 端口、镜像仓库地址？
- 😤 CI/CD 配半天还是失败，GitHub Actions 跑了 30 分钟报个 timeout？

**我们也是。所以我们把最佳实践写成了 AI Skill，一次配置，终身受用。**

---

## ✨ 它能干什么

| 你想做的事 | 你只需要说 |
|------------|------------|
| 🔄 部署新版本到服务器 | 「部署 `abc1234` 到生产环境」 |
| 📦 发布 CLI 新版本 | 「发布 Aura CLI v0.4.0」 |
| 🩺 检查服务健康状态 | 「检查服务器上的服务都正常吗」 |
| ⏪ 部署出问题要回滚 | 「回滚到上一个版本」 |
| 🐳 只更新前端镜像 | 「把前端更新到 `def5678`」 |

**你描述意图，Skill 执行标准化流程。**

---

## 🎯 两个 Skill，覆盖所有场景

### 🌐 `dev-ops` — 通用运维 Skill

> 适合**任何**用 Docker Compose 部署的项目。

| 能力 | 说明 |
|------|------|
| 🐳 多策略构建 | Docker build / Go 交叉编译 / 静态文件 — 自动选最合适的 |
| 🚀 一键部署 | 本地构建 → 推送镜像仓库 → 服务器拉取 → 重启容器 → 验证 |
| 🔒 安全第一 | 绝不在服务器上 build、原子化配置更新、失败自动回滚 |
| 📋 配置驱动 | 一份 `devops.config.md`，所有参数集中管理 |
| 🔄 SCP 兜底 | 镜像仓库挂了也能直传镜像到服务器 |
| 🧩 零锁定 | 不限定语言/框架 — Go、Node.js、Python、Rust 都能用 |

### 🏠 `aura-manager-ops` — AuraManager 专属运维 Skill

> 为 [AuraBaba](https://aurababa.com) 平台量身定制。

| 能力 | 说明 |
|------|------|
| 🎯 开箱即用 | 前端/后端/文档三服务预配置，拿来就能用 |
| 🔧 Go 交叉编译 | macOS ARM64 本地编译 → Linux x86_64 镜像，避免 QEMU 性能问题 |
| 📦 CLI 全流程发布 | 自动交叉编译 6 个平台 → Mirror 直传 → GitHub Release |
| 🌐 域名验证 | 部署后自动检测 aurababa.com 可访问性 |

---

## 🏃 30 秒上手

### 1. 安装 Skill

在 [AuraBaba 技能市场](https://aurababa.com/auradev/skills?tab=platform) 搜索 **dev-ops** 或 **aura-manager-ops**，一键安装。

或者用 CLI 导入：

```bash
# 通用 dev-ops
aura skill install https://github.com/lingling1989r/AuraBaba_Ops_Skill/tree/main/dev-ops

# AuraManager 专属
aura skill install https://github.com/lingling1989r/AuraBaba_Ops_Skill/tree/main/aura-manager-ops
```

### 2. 填写配置

复制 `config.example.md` → 重命名为 `config.md` → 填入你的服务器 IP、域名、镜像仓库地址。

### 3. 开始用

直接对你的 AI 队友说：

> 「部署 `abc1234` 到服务器」

它会自动完成：拉代码 → 构建镜像 → 推送到仓库 → SSH 到服务器拉取 → 重启容器 → 验证健康检查。

---

## 🔗 更多资源

| 资源 | 链接 |
|------|------|
| 🏠 官网 | [aurababa.com](https://aurababa.com) |
| 🛒 技能市场 | [aurababa.com/auradev/skills](https://aurababa.com/auradev/skills?tab=platform) |
| 📖 Aura CLI 文档 | [aurababa.com/docs](https://aurababa.com/docs) |
| 💬 问题反馈 | [GitHub Issues](https://github.com/lingling1989r/AuraBaba_Ops_Skill/issues) |

---

## ⭐ 支持我们

**如果这个 Skill 帮你省了时间、少了事故、早点下班——**

<p align="center">
  <a href="https://github.com/lingling1989r/AuraBaba_Ops_Skill">
    <img src="https://img.shields.io/badge/⭐%20Star%20this%20repo-ffdd00?style=for-the-badge" alt="Star this repo">
  </a>
</p>

**点个 Star ⭐**，让更多被手动部署折磨的开发者看到它。

每次部署省 10 分钟，一年就是 40 小时。这 40 小时，去陪家人、去打游戏、去晒太阳，不香吗？

---

<p align="center">
  <sub>Made with ❤️ by the <a href="https://aurababa.com">AuraBaba</a> team</sub>
</p>

---

# 🇺🇸 English

> **Deploy with words. Operate with AI.**  
> Offload the repetitive grind — Docker builds, image pushes, server deployments — to your AI copilot.

## 🤔 Sound Familiar?

- 😫 Every deploy is a memorized chain of `docker build && docker push && ssh && docker compose up`?
- 😰 One typo in a late-night hotfix command takes down production?
- 😵 Switched computers and can't remember the server IP or registry URL?
- 😤 CI/CD pipelines keep failing with cryptic timeouts after 30-minute runs?

**Same. So we baked our best practices into an AI Skill. Configure once, benefit forever.**

## ✨ What It Does

| You Want To | You Just Say |
|-------------|--------------|
| 🔄 Deploy a new version | "Deploy `abc1234` to production" |
| 📦 Ship a CLI release | "Release CLI v0.4.0" |
| 🩺 Health-check services | "Are all services healthy on the server?" |
| ⏪ Rollback a bad deploy | "Rollback to the previous version" |
| 🐳 Update frontend only | "Update frontend image to `def5678`" |

**You describe intent. The Skill executes the standard operating procedure.**

## 🎯 Two Skills, Every Scenario Covered

### 🌐 `dev-ops` — Universal Ops Skill

For **any** Docker Compose project. Zero lock-in — Go, Node.js, Python, Rust, whatever.

- 🐳 Multi-strategy builds (Docker / Go cross-compile / static)
- 🚀 One-command deploy pipeline
- 🔒 No-build-on-server policy, atomic config updates, automatic rollback
- 📋 Fully config-driven via `devops.config.md`
- 🔄 SCP fallback when the registry is down

### 🏠 `aura-manager-ops` — AuraManager Specialized Skill

Purpose-built for the [AuraBaba](https://aurababa.com) platform.

- 🎯 Pre-configured frontend + backend + docs services
- 🔧 Go cross-compile: macOS ARM64 → Linux x86_64, no QEMU overhead
- 📦 Full CLI release pipeline: cross-compile 6 platforms → mirror → GitHub Release
- 🌐 Automatic aurababa.com domain verification

## 🏃 Start in 30 Seconds

### 1. Install the Skill

Find **dev-ops** or **aura-manager-ops** in the [AuraBaba Skill Marketplace](https://aurababa.com/auradev/skills?tab=platform), or:

```bash
# Generic dev-ops
aura skill install https://github.com/lingling1989r/AuraBaba_Ops_Skill/tree/main/dev-ops

# AuraManager specific
aura skill install https://github.com/lingling1989r/AuraBaba_Ops_Skill/tree/main/aura-manager-ops
```

### 2. Fill in the Config

Copy `config.example.md` → rename to `config.md` → add your server IP, domain, and registry details.

### 3. Talk to Your AI

> "Deploy `abc1234` to the server."

It handles everything: pull code → build images → push to registry → SSH pull → restart containers → health checks.

## ⭐ Support Us

**If this Skill saved you time, prevented an incident, or got you home earlier —**

<p align="center">
  <a href="https://github.com/lingling1989r/AuraBaba_Ops_Skill">
    <img src="https://img.shields.io/badge/⭐%20Star%20this%20repo-ffdd00?style=for-the-badge" alt="Star this repo">
  </a>
</p>

**Drop a Star ⭐** so more developers drowning in manual ops can find it.

10 minutes saved per deploy × 250 workdays = 40+ hours a year. That's a full workweek back in your life.

---

<p align="center">
  <sub>Made with ❤️ by the <a href="https://aurababa.com">AuraBaba</a> team</sub>
</p>
