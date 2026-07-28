# DevOps 部署配置

> 将此文件复制为 `devops.config.md` 并按你的项目修改。
> SKILL.md 引用此文件中的配置值。所有 `{{KEY}}` 占位符需替换为实际值。

---

## 服务器

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `SERVER_HOST` | `<your-server-ip>` | 服务器 IP |
| `SSH_USER` | `root` | SSH 用户名 |
| `SSH_CONNECTION` | `root@<your-server-ip>` | SSH 连接串 |
| `PROJECT_PATH` | `/root/workspace/<project>` | 服务器上项目代码路径 |

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

每个服务一行，用 `|` 分隔字段：
```
名称 | 镜像名 | 容器名 | 端口 | 健康检查URL | 构建策略
```

| 服务 | 镜像名 | 容器名 | 端口 | 健康检查 | 构建策略 |
|------|--------|--------|------|----------|----------|
| `frontend` | `<project>-web` | `<project>-frontend-1` | `3000` | `http://127.0.0.1:3000/` | `docker-node` |
| `backend` | `<project>-backend` | `<project>-backend-1` | `8080` | `http://127.0.0.1:8080/health` | `go-cross` |
| `docs` | `<project>-docs` | `<project>-docs-1` | `4000` | `http://127.0.0.1:4000/docs` | `docker-node` |

**服务名（第一列）** 用于 `docker compose up --no-deps` 命令中指定要重启的容器。

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
| `GO_BINARIES` | `server:./cmd/server,migrate:./cmd/migrate` | 二进制名:入口路径，逗号分隔 |
| `GO_ENTRY_DIR` | `server/cmd/server` | 主服务入口 |
| `GO_LDFLAGS_DEFAULT` | `-s -w` | 默认 ldflags |
| `GO_LDFLAGS_VERSIONED` | `-s -w -X main.version=dev -X main.commit=<commit>` | 带版本号的 ldflags（哪些二进制用此 flags） |

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
| `COMPOSE_FILE_BUILD` | `docker-compose.selfhost.build.yml` | 🚫 开发用 build 文件，禁止在生产引用 |

## 环境变量

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `ENV_FILE` | `.env` | 环境变量文件 |
| `ENV_TAG_KEY` | `IMAGE_TAG` | 镜像 tag 的环境变量名 |

.env 中镜像相关的环境变量格式（按服务）：
```
<IMAGE_NAME>_IMAGE=<registry>/<image>
IMAGE_TAG=<commit-hash>
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
| `TARGET_ARCH` | `linux/amd64` | 目标平台 |
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

## CLI 发布（可选）

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `CLI_ENABLED` | `true` 或 `false` | 是否发布 CLI |
| `CLI_ENTRY` | `cmd/<cli-name>` | CLI 入口目录 |
| `CLI_BINARY` | `<cli-name>` | CLI 二进制名 |
| `CLI_MIRROR_PATH` | `/var/www/cli/` | 服务器 CLI mirror 路径 |
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
