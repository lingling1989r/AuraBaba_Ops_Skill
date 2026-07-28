# AuraBaba Ops Skills

AuraBaba 平台的 DevOps 运维 Skills 集合，适用于 Docker Compose 自托管项目。

## Skills

### [dev-ops](dev-ops/SKILL.md) — 通用 DevOps 运维

配置驱动的通用运维 skill，适用于**任意** Docker Compose 项目。

- 🐳 多策略构建：Docker build、Go 交叉编译、静态文件
- 🚀 标准流程：本地构建 → 推送镜像仓库 → 服务器拉取 → 部署验证
- 🔒 安全：禁止服务器端 build、原子化配置更新、自动回滚
- 📋 配置驱动：通过 `devops.config.md` 配置所有参数

**适用场景：** Go + Node.js 全栈、多容器部署、任何 Docker Compose 项目

### [aura-manager-ops](aura-manager-ops/SKILL.md) — AuraManager 运维

AuraManager 项目专属运维 skill（基于 dev-ops 模式，使用 AuraManager 特定配置）。

- 🎯 预配置：前端、后端、文档三服务
- 🔧 Go 交叉编译 + Docker 打包
- 📦 Aura CLI 发布：本地构建 + mirror 直传 + GitHub Release
- 🌐 aurababa.com 域名验证

**适用场景：** AuraManager 项目的部署升级、CLI 发布

## 快速开始

### 方式 1：从 GitHub 导入

```bash
# 导入 dev-ops（通用）
multica skill import --url https://github.com/lingling1989r/AuraBaba_Ops_Skill/tree/main/dev-ops --output json

# 导入 aura-manager-ops（专属）
multica skill import --url https://github.com/lingling1989r/AuraBaba_Ops_Skill/tree/main/aura-manager-ops --output json
```

### 方式 2：从工作区技能市场

在 [AuraBaba 平台技能页](https://aurababa.com/auradev/skills?tab=platform) 搜索并安装。

### 配置

1. 复制对应 skill 的 `config.example.md` 到项目目录，重命名为 `config.md`（或其他 skill 指定的名称）
2. 填写实际值（服务器 IP、域名、镜像仓库等）
3. 在服务器上准备好 `deploy.sh` 和 Docker Compose 配置

## 使用

安装后在对话中直接描述部署意图即可触发 skill：

- "部署最新 commit 到服务器"
- "发布 Aura CLI v0.3.50"
- "更新前端镜像到 abc1234"

## 文件结构

```
AuraBaba_Ops_Skill/
├── README.md
├── dev-ops/
│   ├── SKILL.md              # 通用运维 skill
│   └── config.example.md     # 配置模板
└── aura-manager-ops/
    ├── SKILL.md              # AuraManager 专属运维 skill
    └── config.example.md     # 配置模板（脱敏版）
```

## 安全提醒

- ❌ 绝不在服务器上 build 镜像或编译二进制
- ❌ 不要将含真实值的 `config.md` 提交到公开仓库
- ✅ 所有镜像在本地构建，推送至镜像仓库，服务器只做 pull + restart
- ✅ 使用显式 commit hash 作为镜像 tag，禁止 `dev`/`latest`
