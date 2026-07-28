# AuraManager 运维配置

> ⚠️ 将此文件复制为 `config.md` 并填写实际值。不要将含真实值的 config.md 提交到公开仓库。
> SKILL.md 引用此文件中的配置值。修改部署目标时只需改此文件。

## 服务器

| 配置项 | 值 |
|--------|-----|
| `SERVER_HOST` | `<your-server-ip>` |
| `SSH_USER` | `root` |
| `SSH_CONNECTION` | `root@<your-server-ip>` |
| `PROJECT_PATH` | `/root/workspace/AuraManager` |

## 域名

| 配置项 | 值 |
|--------|-----|
| `DOMAIN` | `<your-domain.com>` |
| `DOMAIN_URL` | `https://<your-domain.com>` |

## 镜像仓库 (GHCR)

| 配置项 | 值 |
|--------|-----|
| `REGISTRY_HOST` | `ghcr.io` |
| `REGISTRY_OWNER` | `<your-github-user>` |
| `REGISTRY_IMAGE_PREFIX` | `ghcr.io/<your-github-user>` |
| `REGISTRY_LOGIN_USER` | `<your-github-user>` |

## 镜像与服务

### 服务列表

| 服务 | 镜像名 | 容器名 | 端口 | 健康检查 |
|------|--------|--------|------|----------|
| `frontend` | `aura-web` | `aura-frontend-1` | `3000` | `http://127.0.0.1:3000/` |
| `backend` | `aura-backend` | `aura-backend-1` | `8080` | `http://127.0.0.1:8080/health` |
| `docs` | `aura-docs` | `aura-docs-1` | `4000` | `http://127.0.0.1:4000/docs` |

### 数据库

| 配置项 | 值 |
|--------|-----|
| `DB_CONTAINER` | `aura-postgres-1` |
| `DB_USER` | `<db-user>` |
| `DB_NAME` | `<db-name>` |
| `DB_MIGRATIONS_TABLE` | `schema_migrations` |

### 环境变量

| 配置项 | 值 |
|--------|-----|
| `ENV_FILE` | `.env` |
| `ENV_TAG_KEY` | `AURA_IMAGE_TAG` |
| `ENV_BACKEND_IMAGE_KEY` | `AURA_BACKEND_IMAGE` |
| `ENV_WEB_IMAGE_KEY` | `AURA_WEB_IMAGE` |
| `ENV_DOCS_IMAGE_KEY` | `AURA_DOCS_IMAGE` |

格式：
```
AURA_BACKEND_IMAGE=ghcr.io/<user>/aura-backend
AURA_WEB_IMAGE=ghcr.io/<user>/aura-web
AURA_DOCS_IMAGE=ghcr.io/<user>/aura-docs
AURA_IMAGE_TAG=<commit-hash>
```

### Compose 文件

| 配置项 | 值 |
|--------|-----|
| `COMPOSE_FILE` | `docker-compose.selfhost.yml` |
| `COMPOSE_FILE_BUILD` | `docker-compose.selfhost.build.yml`（🚫 禁止在生产引用） |

### 反向代理

nginx 将域名转发到前端容器端口。

## 本地构建环境

| 配置项 | 值 |
|--------|-----|
| `LOCAL_ARCH` | `ARM64` (macOS) |
| `TARGET_ARCH` | `linux/amd64` (x86_64) |
| `DOCKER_RUNTIME` | Colima |
| `COLIMA_VM_TYPE` | `vz` |
| `COLIMA_CPU` | `4` |
| `COLIMA_MEMORY` | `8` |
| `BASE_IMAGE` | `alpine:3.21` |

## 网络与代理

| 配置项 | 值 |
|--------|-----|
| `LOCAL_PROXY_HOST` | `127.0.0.1` |
| `LOCAL_PROXY_PORT` | `<your-proxy-port>` |
| `LOCAL_PROXY` | `http://127.0.0.1:<port>` |
| `COLIMA_PROXY_HOST` | `192.168.5.2` |
| `COLIMA_PROXY` | `http://192.168.5.2:<port>` |
| `GO_MODULE_PROXY` | `https://goproxy.cn,direct` |

## Go 交叉编译

| 配置项 | 值 |
|--------|-----|
| `GO_MODULE_DIR` | `server` |
| `GO_BINARIES` | `server`（入口 `./cmd/server`），`aura`（入口 `./cmd/aura`），`migrate`（入口 `./cmd/migrate`），`backfill_task_usage_hourly`（入口 `./cmd/backfill_task_usage_hourly`） |
| `GO_LDFLAGS_SERVER` | `-s -w -X main.version=dev -X main.commit=<commit>` |
| `GO_LDFLAGS_MIGRATE` | `-s -w` |
| `GO_TARGET_OS` | `linux` |
| `GO_TARGET_ARCH` | `amd64` |
| `GO_CGO_ENABLED` | `0` |

### Backend Dockerfile 信息

- 基础镜像：`alpine:3.21`
- 二进制文件：`server`, `aura`, `migrate`, `backfill_task_usage_hourly`
- 数据目录：`migrations/`, `docs-content-seed/`
- 入口脚本：`docker/entrypoint.sh`
- 暴露端口：`8080`

### Web / Docs 构建

| 配置项 | 值 |
|--------|-----|
| `WEB_DOCKERFILE` | `Dockerfile.web` |
| `DOCS_DOCKERFILE` | `Dockerfile.docs` |
| `WEB_BUILD_CMD` | `pnpm --filter @aura/web build && rm -rf apps/web/.next/cache` |
| `DOCS_BUILD_CMD` | `pnpm --filter @aura/docs build` |
| `PACKAGE_MANAGER` | `pnpm` |

## CLI 发布

| 配置项 | 值 |
|--------|-----|
| `CLI_ENTRY` | `server/cmd/aura` |
| `CLI_BINARY` | `aura` |
| `CLI_MIRROR_PATH` | `/var/www/cli/` |
| `CLI_MIRROR_URL` | `https://<domain>/cli/` |
| `CLI_LATEST_URL` | `https://<domain>/cli/latest` |
| `CLI_RELEASE_REPO` | `<owner>/AuraRelease` |
| `CLI_INSTALL_SCRIPT_URL` | `https://<domain>/scripts/install.sh` |
| `CLI_GORELEASER_CONFIG` | `.goreleaser.cli.yml` |
| `CLI_RELEASE_WORKFLOW` | `.github/workflows/cli-release.yml`（备选，勿依赖） |

### CLI 编译平台

| OS | Arch |
|----|------|
| `darwin` | `amd64`, `arm64` |
| `linux` | `amd64`, `arm64` |
| `windows` | `amd64`, `arm64` |

### CLI Archive 命名

- 当前：`aura-cli-<version>-<os>-<arch>.tar.gz`（Windows: `.zip`）
- Legacy：`aura_<os>_<arch>.tar.gz`（Windows: `.zip`）

### CLI 安装脚本文件

| 文件 | 路径 |
|------|------|
| Unix 源码 | `scripts/install.sh` |
| Unix 线上 | `apps/web/public/scripts/install.sh` |
| Windows 源码 | `scripts/install.ps1` |
| Windows 线上 | `apps/web/public/scripts/install.ps1` |

## GitHub 相关

| 配置项 | 值 |
|--------|-----|
| `GITHUB_REPO_OWNER` | `<your-github-user>` |
| `GITHUB_REPO` | `<owner>/AuraManager` |

## 部署脚本

服务器端部署脚本：`deploy.sh`（位于 `scripts/deploy.sh`，接受恰好 1 个参数 `<commit-tag>`）。
流程：git pull → docker pull 全部镜像 → 原子更新 .env → compose up --no-build → 验证。
