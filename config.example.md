# DevOps 部署配置

> 将此文件复制为 `devops.config.md` 并按你的项目修改。
> SKILL.md 引用此文件中的配置值。复制后请删除无关示例并填写所有必填项。
> 不要在此文件保存密码、token、SSH 私钥或其他凭证；凭证使用本机 credential helper、环境注入或密钥管理服务。

---

## 服务器

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `SERVER_HOST` | `<your-server-ip>` | 服务器 IP |
| `SSH_USER` | `root` | SSH 用户名 |
| `SSH_CONNECTION` | `root@<your-server-ip>` | SSH 连接串 |
| `PROJECT_PATH` | `/srv/<project>` | 服务器上的部署目录 |

## 域名（可选）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `DOMAIN` | `<your-domain.com>` | 域名 |
| `DOMAIN_URL` | `https://<your-domain.com>` | 完整 URL |

## 镜像仓库

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `REGISTRY_HOST` | `ghcr.io` | 镜像仓库地址（ghcr.io / docker.io / ecr...） |
| `REGISTRY_OWNER` | `<your-github-user>` | 仓库所有者 |
| `REGISTRY_IMAGE_PREFIX` | `ghcr.io/<your-github-user>` | 镜像完整前缀 |
| `REGISTRY_LOGIN_USER` | `<your-github-user>` | 登录用户名 |

## 服务列表

每个服务一行，用 `|` 分隔字段。完整镜像名由 `REGISTRY_IMAGE_PREFIX/镜像名:RELEASE_TAG` 组成：
```
Compose服务名 | 镜像名 | Dockerfile/构建入口 | 健康检查URL | 构建策略 | 冒烟超时秒
```

| Compose 服务 | 镜像名 | Dockerfile/入口 | 健康检查 | 构建策略 | 超时(秒) |
|--------------|--------|-----------------|------------|----------|----------|
| `frontend` | `<project>-web` | `Dockerfile.web` | `http://127.0.0.1:3000/` | `docker-node` | `60` |
| `backend` | `<project>-backend` | `server:server=./cmd/server,migrate=./cmd/migrate` | `http://127.0.0.1:8080/health` | `go-cross` | `60` |
| `docs` | `<project>-docs` | `Dockerfile.docs` | `http://127.0.0.1:4000/docs` | `docker-node` | `60` |

**Compose 服务名（第一列）** 用于 `docker compose up --no-build --no-deps`。不要依赖 Compose 自动生成的容器名。

### 构建策略说明

| 策略 | 说明 | 必需配置 |
|------|------|----------|
| `docker-node` | 标准 Docker build（Node.js 项目） | `DOCKERFILE` — Dockerfile 路径 |
| `docker-generic` | 标准 Docker build（通用） | `DOCKERFILE` — Dockerfile 路径 |
| `go-cross` | Go 原生交叉编译 + Docker 打包 | `GO_MODULE_DIR`, `GO_BINARIES`, `GO_ENTRY_DIR` |
| `go-docker` | Go 在 Docker 内编译（多阶段构建） | `DOCKERFILE` — Dockerfile 路径 |
| `static` | 静态文件服务（无需构建） | — |

### Go 交叉编译配置（使用 `go-cross` 策略时）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `GO_MODULE_DIR` | `server` | Go module 目录 |
| `GO_BINARIES` | `server=./cmd/server,migrate=./cmd/migrate` | 二进制名=入口路径，逗号分隔 |
| `TARGET_GOOS` | `linux` | 目标操作系统 |
| `TARGET_GOARCH` | `amd64` | 目标 CPU 架构 |
| `CGO_ENABLED` | `0` | 是否启用 CGO；启用时需配置交叉工具链 |
| `GO_LDFLAGS` | `-s -w -X main.version=<version> -X main.commit=<commit>` | 统一 ldflags；发布时替换版本和 commit |

### Web/Docs Docker build 配置（使用 `docker-node` 策略时）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `PACKAGE_MANAGER` | `pnpm` | 包管理器（npm/yarn/pnpm） |
| `WEB_DOCKERFILE` | `Dockerfile.web` | Web 前端 Dockerfile |
| `DOCS_DOCKERFILE` | `Dockerfile.docs` | 文档站 Dockerfile |

### Backend Docker 打包参数（`go-cross` 策略）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `BACKEND_BASE_IMAGE` | `alpine:3.21` | 运行时基础镜像 |
| `BACKEND_PORT` | `8080` | 暴露端口 |
| `BACKEND_ENTRYPOINT` | `docker/entrypoint.sh` | 入口脚本路径 |
| `BACKEND_EXTRA_FILES` | `migrations,apps/docs/content/docs` | 额外复制到镜像的目录 |
| `BACKEND_EXTRA_TARGETS` | `migrations/,docs-content-seed/` | 镜像内目标路径 |

## Compose

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `COMPOSE_FILE` | `docker-compose.selfhost.yml` | 生产 compose 文件 |
| `DEPLOY_SCRIPT` | `deploy.sh` | 可选；需经审查的 pull-only 远端部署脚本 |
| `DEPLOY_TIMEOUT_SECONDS` | `180` | 所有健康检查的总超时 |
| `BACKUP_RETENTION` | `3` | 成功部署后保留的环境文件备份数 |

## 环境变量

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `ENV_FILE` | `.env` | 环境变量文件 |
| `ENV_TAG_KEY` | `IMAGE_TAG` | 镜像 tag 的环境变量名 |

.env 中镜像相关的环境变量格式（按服务）：
```
<IMAGE_NAME>_IMAGE=<registry>/<image>
IMAGE_TAG=<full-commit-sha>
```

## 数据库（可选）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `DB_CONTAINER` | `<project>-postgres-1` | 数据库容器名 |
| `DB_USER` | `<db-user>` | 数据库用户 |
| `DB_NAME` | `<db-name>` | 数据库名 |
| `DB_MIGRATIONS_TABLE` | `schema_migrations` | 迁移表名 |

## 本地构建环境

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `LOCAL_ARCH` | `ARM64` | 本地架构（macOS 通常 ARM64） |
| `TARGET_ARCH` | `linux/amd64` | Docker 目标平台，需与 GOOS/GOARCH 一致 |
| `DOCKER_RUNTIME` | `colima` | Docker 运行时（colima / docker-desktop / orbstack） |

Colima 启动参数：
```bash
colima start --vm-type vz --cpu 4 --memory 8
```

## 网络与代理

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `LOCAL_PROXY_HOST` | `127.0.0.1` | 本机代理 IP |
| `LOCAL_PROXY_PORT` | `7897` | 本机代理端口 |
| `LOCAL_PROXY` | `http://127.0.0.1:7897` | 完整代理地址 |
| `COLIMA_PROXY_HOST` | `192.168.5.2` | Colima VM 中宿主 IP |
| `COLIMA_PROXY` | `http://192.168.5.2:7897` | Colima 代理地址 |
| `GO_MODULE_PROXY` | `https://goproxy.cn,direct` | Go module 代理 |

代理为可选项。不要把带账号密码的代理 URL 写进此文件；敏感代理凭证应从环境或密钥管理服务注入。

## 发布与回滚策略

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `TAG_POLICY` | `full-git-sha` | 仅接受 40 位 Git commit SHA；如需 semver 请明确修改策略 |
| `SCP_FALLBACK` | `false` | Registry 故障时是否允许经用户确认后直传镜像 |
| `EXTERNAL_HEALTH_URL` | `https://<your-domain.com>/` | 可选；部署后的外部验证 URL |
| `EXPECTED_HTTP_STATUS` | `200` | 健康检查预期状态码 |

## CLI 发布（可选）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `CLI_ENABLED` | `true` 或 `false` | 是否发布 CLI |
| `CLI_ENTRY` | `cmd/<cli-name>` | CLI 入口目录 |
| `CLI_BINARY` | `<cli-name>` | CLI 二进制名 |
| `CLI_VERSION_LDFLAG` | `main.version` | 版本注入变量 |
| `CLI_COMMIT_LDFLAG` | `main.commit` | commit 注入变量 |
| `CLI_MIRROR_PATH` | `/var/www/cli/` | 服务器 CLI mirror 路径；服务器只接收产物，不编译 |
| `CLI_MIRROR_URL` | `https://<domain>/cli/` | CLI mirror URL |
| `CLI_LATEST_URL` | `https://<domain>/cli/latest` | Latest 版本查询 URL |
| `CLI_RELEASE_REPO` | `<owner>/<release-repo>` | GitHub Release 仓库 |
| `CLI_INSTALL_SCRIPT_URL` | `https://<domain>/scripts/install.sh` | 安装脚本 URL |
| `CLI_GORELEASER_CONFIG` | `.goreleaser.cli.yml` | GoReleaser 配置 |
| `CLI_RELEASE_WORKFLOW` | `.github/workflows/cli-release.yml` | CI workflow（备选） |

### CLI 编译平台
- `darwin` / `linux` / `windows` × `amd64` / `arm64`

### CLI Archive 命名
- 当前：`<cli-binary>-<version>-<os>-<arch>.tar.gz`（Windows: `.zip`）
- Legacy（可选）：`<cli-binary>_<os>_<arch>.tar.gz`（Windows: `.zip`）

## GitHub 仓库

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `GITHUB_REPO` | `<owner>/<repo>` | 主代码仓库 |
