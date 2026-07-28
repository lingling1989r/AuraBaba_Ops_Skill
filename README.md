<!--
  🇨🇳 中文用户请直接往下读
  🇺🇸 English speakers: scroll down for the English section
-->

<p align="center">
  <img src="https://img.shields.io/github/stars/lingling1989r/AuraBaba_Ops_Skill?style=social" alt="GitHub Stars">
  <img src="https://img.shields.io/github/license/lingling1989r/AuraBaba_Ops_Skill" alt="License">
</p>

# 🚀 AuraBaba Ops Skill

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
| 📦 发布 CLI 新版本 | 「发布 CLI v0.4.0」 |
| 🩺 检查服务健康状态 | 「检查服务器上的服务都正常吗」 |
| ⏪ 部署出问题要回滚 | 「回滚到上一个版本」 |
| 🐳 只更新某一个服务 | 「把前端更新到 `def5678`」 |

**你描述意图，Skill 执行标准化流程。**

---

## 🎯 核心能力

| 能力 | 说明 |
|------|------|
| 🐳 多策略构建 | Docker build / Go 交叉编译 / 静态文件 — 自动选最合适的 |
| 🚀 一键部署 | 本地构建 → 推送镜像仓库 → 服务器拉取 → 重启容器 → 验证 |
| 🔒 安全第一 | 绝不在服务器上 build、原子化配置更新、失败自动回滚 |
| 📋 配置驱动 | 一份 `devops.config.md`，所有参数集中管理 |
| 🔄 SCP 兜底 | 镜像仓库挂了也能直传镜像到服务器 |
| 📦 CLI 发布 | 支持 CLI 工具交叉编译、Mirror 直传、GitHub Release 全流程 |
| 🧩 零锁定 | 不限定语言/框架 — Go、Node.js、Python、Rust 都能用 |

---

## 🏃 30 秒上手

### 1. 安装 Skill

在 [AuraBaba 技能市场](https://aurababa.com/auradev/skills?tab=platform) 搜索 **dev-ops**，一键安装。

或者用 CLI 导入：

```bash
aura skill install https://github.com/lingling1989r/AuraBaba_Ops_Skill
```

### 2. 填写配置

将本仓库的 `config.example.md` 复制到你的项目目录，重命名为 `devops.config.md`，填入你的服务器 IP、域名、镜像仓库地址。

### 3. 开始用

直接对你的 AI 队友说：

> 「部署 `abc1234` 到服务器」

它会自动完成：拉代码 → 构建镜像 → 推送到仓库 → SSH 到服务器拉取 → 重启容器 → 验证健康检查。

---

## 📁 文件结构

```
AuraBaba_Ops_Skill/
├── SKILL.md              # Skill 定义文件（工作流指令）
├── config.example.md     # 配置模板（复制到项目中填写）
└── README.md             # 本文件
```

## 🔗 更多资源

| 资源 | 链接 |
|------|------|
| 🏠 官网 | [aurababa.com](https://aurababa.com) |
| 🛒 技能市场 | [aurababa.com/auradev/skills](https://aurababa.com/auradev/skills?tab=platform) |
| 📖 文档 | [aurababa.com/docs](https://aurababa.com/docs) |
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
| 🐳 Update a single service | "Update frontend to `def5678`" |

**You describe intent. The Skill executes the standard operating procedure.**

## 🎯 Core Capabilities

- 🐳 Multi-strategy builds (Docker / Go cross-compile / static)
- 🚀 One-command deploy pipeline: build → push → pull → restart → verify
- 🔒 No-build-on-server policy, atomic config updates, automatic rollback
- 📋 Fully config-driven via `devops.config.md`
- 🔄 SCP fallback when the registry is down
- 📦 Full CLI release pipeline: cross-compile → mirror → GitHub Release
- 🧩 Zero lock-in — Go, Node.js, Python, Rust, whatever you use

## 🏃 Start in 30 Seconds

### 1. Install

Find **dev-ops** in the [AuraBaba Skill Marketplace](https://aurababa.com/auradev/skills?tab=platform), or:

```bash
aura skill install https://github.com/lingling1989r/AuraBaba_Ops_Skill
```

### 2. Configure

Copy `config.example.md` to your project, rename to `devops.config.md`, and fill in your server IP, domain, and registry details.

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
