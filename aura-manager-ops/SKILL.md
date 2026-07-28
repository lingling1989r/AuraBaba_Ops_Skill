---
name: aura-manager-ops
description: AuraManager 运维：本地构建镜像 → 推送 GHCR → 服务器拉取部署、Aura CLI 发布（默认本地构建+mirror直传，GitHub Actions 为备选）、aurababa.com 镜像验证。当需要更新/部署 AuraManager 服务、发布 CLI、重启容器、验证 aurababa.com 访问时使用。
---

# AuraManager 运维 / 升级发布

> **开始前请先读取 `config.md`** — 所有服务器地址、镜像名、端口等具体值均定义在该文件中。
> 本文档引用配置键名（如 `SERVER_HOST`），实际值见 config.md。

AuraManager 自托管部署的升级与发布运维流程。服务部署在远程服务器上，通过 Docker Compose 运行多个容器。

## 🚫 禁止事项（强制）

**永远不要在服务器环境（`{{DOMAIN}}`, `{{SERVER_HOST}}`）上 build 镜像或 CLI 二进制！**

- ❌ 禁止 `docker compose ... --build`
- ❌ 禁止 `docker build`
- ❌ 禁止 `go build` 编译 CLI
- ❌ 禁止任何在服务器上编译/构建的行为
- ❌ 禁止执行旧版 `deploy.sh`（含 `--build`）
- ❌ 禁止引用 `{{COMPOSE_FILE_BUILD}}`（含 `build:` 指令）

**所有镜像和 CLI 必须在本地构建，推送至 GHCR，服务器只做 pull + restart。**

违反此规则会导致：
- 服务器资源耗尽（build 消耗大量 CPU/内存）
- 服务中断（build 期间容器不可用）
- QEMU/架构不兼容问题（服务器 x86_64，本地 ARM64）

CLI 也同样禁止在服务器编译，必须本地交叉编译。

## 环境信息

- 服务器：`{{SERVER_HOST}}`，SSH 连接 `ssh {{SSH_CONNECTION}}`
- 项目代码路径：`{{PROJECT_PATH}}`
- Web 域名：`{{DOMAIN_URL}}`
- 镜像仓库：`{{REGISTRY_IMAGE_PREFIX}}`
- 部署方式：Docker Compose（**仅 `{{COMPOSE_FILE}}`**，禁止引用 `{{COMPOSE_FILE_BUILD}}`）
  - 容器及端口：见 config.md 服务列表
  - 镜像通过 `{{ENV_FILE}}` 环境变量指定，使用显式版本 tag（commit hash），禁止 `dev` / `latest`
- 反向代理：nginx，将 `{{DOMAIN}}` 转发到前端容器端口

## 本地构建环境

本机为 macOS ARM64，生产服务器为 x86_64。使用 Colima + Docker 构建 `linux/amd64` 镜像。

```bash
# 检查/启动 Colima（macOS）
colima status 2>&1 || colima start --vm-type vz --cpu 4 --memory 8

# 确认 Docker context
docker context show    # 应显示 colima

# 验证 amd64 模拟可用
docker run --rm --platform linux/amd64 alpine:3.21 uname -m  # 输出 x86_64
```

> Rosetta 2 未安装时 Colima 用 QEMU 模拟 amd64。Go 编译在 QEMU 下可能 SIGSEGV → 改用**原生交叉编译**（见下文 Backend 构建）。

### 网络与代理

Colima VM / QEMU 容器内网络可能不稳定（registry.npmjs.org 超时、Google Fonts 超时、proxy.golang.org 超时）。遇到网络超时时，按以下顺序尝试：

**Go 模块下载 / 交叉编译：**

```bash
# 代理地址：config.md → LOCAL_PROXY
PROXY="{{LOCAL_PROXY}}"

# 策略 1：先尝试代理 + goproxy.cn
export HTTP_PROXY=$PROXY HTTPS_PROXY=$PROXY
GOPROXY=https://goproxy.cn,direct go mod download

# 策略 2：若代理超时（proxyconnect tcp: dial tcp 127.0.0.1:7897: i/o timeout），取消代理直连
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
GOPROXY=https://goproxy.cn,direct go mod download
```

**Docker build 网络问题（Google Fonts / npm 超时）：**

- QEMU 模拟 amd64 容器时，`docker build --network host` 和 `--dns` 在此 Docker 版本中不被支持
- `docker buildx` 在此 Colima 版本中不支持 `--platform` flag，继续使用 legacy builder
- Docker build 内部网络超时，**首选通过代理解决**（已验证可用）：

  **代理方案（推荐）**：临时在 Dockerfile 的 build 步骤前加 ARG + ENV 传递代理，构建完后 `git checkout` 恢复：

  1. 确认代理可达（Colima 将 `127.0.0.1` 映射为 `192.168.5.2`）：
     ```bash
     curl -s -o /dev/null -w "%{http_code}" --proxy {{LOCAL_PROXY}} https://fonts.googleapis.com
     # 返回 404 表示连通（不是 timeout）
     ```

  2. 临时修改 Dockerfile.web，在 `ENV STANDALONE=true` 和 `RUN pnpm ... build` 之间插入：
     ```dockerfile
     ENV STANDALONE=true

     # BUILD WORKAROUND: pass proxy through to QEMU containers
     ARG HTTP_PROXY
     ARG HTTPS_PROXY
     ARG http_proxy
     ARG https_proxy
     ENV HTTP_PROXY=$HTTP_PROXY
     ENV HTTPS_PROXY=$HTTPS_PROXY
     ENV http_proxy=$http_proxy
     ENV https_proxy=$https_proxy

     RUN pnpm --filter @aura/web build && rm -rf apps/web/.next/cache
     ```
     Dockerfile.docs 同理，在 `ENV STANDALONE=true` 和 `RUN pnpm ... build` 之间插入。

  3. 构建时使用 `{{COLIMA_PROXY}}`（不能用 `127.0.0.1`，容器内 127.0.0.1 是容器自身）：
     ```bash
     docker build --platform linux/amd64 \
       --build-arg HTTP_PROXY={{COLIMA_PROXY}} \
       --build-arg HTTPS_PROXY={{COLIMA_PROXY}} \
       --build-arg http_proxy={{COLIMA_PROXY}} \
       --build-arg https_proxy={{COLIMA_PROXY}} \
       -t {{REGISTRY_IMAGE_PREFIX}}/aura-web:<commit> -f Dockerfile.web .
     ```

  4. 构建完成后恢复 Dockerfile：
     ```bash
     git checkout Dockerfile.web Dockerfile.docs
     ```

  > ⚠️ **仅靠 `--build-arg` 不够**：Dockerfile 没有预定义 HTTP_PROXY ARG 时，build-arg 不会自动变成环境变量。必须临时添加 `ARG` + `ENV` 配对。
  > ⚠️ **代理地址必须用 `192.168.5.2`**：Colima VM 内的容器通过 bridge 网络访问宿主，`127.0.0.1` 指向容器自身。

  **系统字体兜底方案**（代理不可用时）：
  ```typescript
  // 临时替换（构建完成后 git checkout 恢复）
  // import { Geist, Geist_Mono } from "next/font/google";  // 注释掉
  const fontStyle = {
    "--font-geist": "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
    "--font-mono": "ui-monospace, 'SFMono-Regular', 'Menlo', 'Consolas', monospace",
  } as React.CSSProperties;
  // className 中去掉 geist.variable, geistMono.variable，改用 style={fontStyle}
  ```
- 若 `fumadocs-mdx` 在 QEMU 下 esbuild 崩溃（`write EPIPE`）：重试即可，esbuild 在 QEMU 下的崩溃是间歇性的

## 升级发布流程（GHCR 模式）

完整流程：**本地构建镜像 → 推送 GHCR → 服务器拉取 → 重启容器**。全程不在服务器执行任何 build。

### 1. 本地构建镜像（linux/amd64）

```bash
cd AuraManager

# Web — Node.js 构建，QEMU 下正常工作
# 若 Google Fonts 超时，按上文「代理方案」临时修改 Dockerfile + 传入 --build-arg 代理
docker build --platform linux/amd64 \
  -t {{REGISTRY_IMAGE_PREFIX}}/aura-web:<commit> -f {{WEB_DOCKERFILE}} .

# Docs — Node.js 构建，QEMU 下正常工作
# 同理，Google Fonts 超时时走代理方案
docker build --platform linux/amd64 \
  -t {{REGISTRY_IMAGE_PREFIX}}/aura-docs:<commit> -f {{DOCS_DOCKERFILE}} .

# Backend — Go 编译在 QEMU 下可能 SIGSEGV，改用原生交叉编译
# 网络策略：先尝试代理；代理超时则取消代理直连 + goproxy.cn
export GOPROXY=https://goproxy.cn,direct
# 若网络超时，先尝试代理：
#   export HTTP_PROXY={{LOCAL_PROXY}} HTTPS_PROXY={{LOCAL_PROXY}}
# 若代理也超时（proxyconnect timeout），unset 后重试：
#   unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
mkdir -p /tmp/aura-bin
cd server && \
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
  go build -ldflags "-s -w -X main.version=dev -X main.commit=<commit>" \
  -o /tmp/aura-bin/server ./cmd/server && \
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
  go build -ldflags "-s -w -X main.version=dev -X main.commit=<commit>" \
  -o /tmp/aura-bin/aura ./cmd/aura && \
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
  go build -ldflags "-s -w" -o /tmp/aura-bin/migrate ./cmd/migrate && \
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
  go build -ldflags "-s -w" -o /tmp/aura-bin/backfill_task_usage_hourly ./cmd/backfill_task_usage_hourly
cd ..

# 准备 Backend build context（跳过 Go builder stage，直接用预编译二进制）
mkdir -p /tmp/aura-backend-build/docs-content-seed/docs
cp /tmp/aura-bin/{server,aura,migrate,backfill_task_usage_hourly} /tmp/aura-backend-build/
cp -r server/migrations /tmp/aura-backend-build/
cp -r apps/docs/content/docs/* /tmp/aura-backend-build/docs-content-seed/docs/
cp docker/entrypoint.sh /tmp/aura-backend-build/

cat > /tmp/aura-backend-build/Dockerfile.backend << 'DOCKERFILE'
FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY server aura migrate backfill_task_usage_hourly ./
COPY migrations/ ./migrations/
COPY docs-content-seed/ ./docs-content-seed/
COPY entrypoint.sh .
RUN sed -i 's/\r$//' entrypoint.sh && chmod +x entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["./entrypoint.sh"]
DOCKERFILE

docker build --platform linux/amd64 \
  -t {{REGISTRY_IMAGE_PREFIX}}/aura-backend:<commit> \
  -f /tmp/aura-backend-build/Dockerfile.backend /tmp/aura-backend-build/
```

### 2. 架构检查与冒烟测试

```bash
# 检查架构（镜像名见 config.md 服务列表）
for img in aura-backend aura-web aura-docs; do
  docker inspect {{REGISTRY_IMAGE_PREFIX}}/$img:<commit> --format "$img: {{.Architecture}}/{{.Os}}"
done

# Backend 二进制验证
docker run --rm --platform linux/amd64 --entrypoint /app/server \
  {{REGISTRY_IMAGE_PREFIX}}/aura-backend:<commit> --help

# Web 启动验证
docker run -d --rm --platform linux/amd64 --name test-web -p 29999:3000 \
  {{REGISTRY_IMAGE_PREFIX}}/aura-web:<commit>
sleep 10 && curl -s -o /dev/null -w "web: HTTP %{http_code}\n" http://localhost:29999/
docker stop test-web

# Docs 启动验证
docker run -d --rm --platform linux/amd64 --name test-docs -p 29998:4000 \
  {{REGISTRY_IMAGE_PREFIX}}/aura-docs:<commit>
sleep 10 && curl -s -o /dev/null -w "docs: HTTP %{http_code}\n" http://localhost:29998/docs
docker stop test-docs
```

### 3. 推送至 GHCR

```bash
# 登录 GHCR（需 write:packages scope 的 PAT）
echo '<ghp_token>' | docker login {{REGISTRY_HOST}} -u {{REGISTRY_LOGIN_USER}} --password-stdin

# 推送（镜像名见 config.md 服务列表）
docker push {{REGISTRY_IMAGE_PREFIX}}/aura-backend:<commit>
docker push {{REGISTRY_IMAGE_PREFIX}}/aura-web:<commit>
docker push {{REGISTRY_IMAGE_PREFIX}}/aura-docs:<commit>

# 验证远端
docker manifest inspect {{REGISTRY_IMAGE_PREFIX}}/aura-backend:<commit>
docker manifest inspect {{REGISTRY_IMAGE_PREFIX}}/aura-web:<commit>
docker manifest inspect {{REGISTRY_IMAGE_PREFIX}}/aura-docs:<commit>
```

### 4. 服务器拉取并部署

优先使用 `deploy.sh`（已审查，含回滚、原子替换等安全机制）：

```bash
ssh {{SSH_CONNECTION}} '{{PROJECT_PATH}}/deploy.sh <commit>'
```

手动步骤（仅脚本不可用时，**注意顺序：先 pull 再改配置**）：

```bash
# 1. 登录 GHCR 并先拉取全部镜像（失败不改变配置）
ssh {{SSH_CONNECTION}} "
echo '<ghp_token>' | docker login {{REGISTRY_HOST}} -u {{REGISTRY_LOGIN_USER}} --password-stdin && \
docker pull {{REGISTRY_IMAGE_PREFIX}}/aura-backend:<commit> && \
docker pull {{REGISTRY_IMAGE_PREFIX}}/aura-web:<commit> && \
docker pull {{REGISTRY_IMAGE_PREFIX}}/aura-docs:<commit>
"

# 2. 三个镜像全部拉取成功后，原子更新 .env
ssh {{SSH_CONNECTION}} "
cd {{PROJECT_PATH}} && \
cp {{ENV_FILE}} {{ENV_FILE}}.bak && \
sed '/^{{ENV_TAG_KEY}}=/d' {{ENV_FILE}}.bak > {{ENV_FILE}}.tmp && \
echo '{{ENV_TAG_KEY}}=<commit>' >> {{ENV_FILE}}.tmp && \
mv {{ENV_FILE}}.tmp {{ENV_FILE}}
"

# 3. 重启容器（--no-build，绝不 build）
ssh {{SSH_CONNECTION}} "
cd {{PROJECT_PATH}} && \
export {{ENV_TAG_KEY}}='<commit>' && \
docker compose -f {{COMPOSE_FILE}} up -d --no-build --no-deps frontend backend docs
"
```

> ⚠️ 仅使用 `{{COMPOSE_FILE}}`，不得引用 `{{COMPOSE_FILE_BUILD}}`。

**服务器端快捷部署脚本：**

也可以使用服务器上的 `deploy.sh`（pull-only，需传入 commit tag，只接受恰好 1 个参数）：

```bash
ssh {{SSH_CONNECTION}} '{{PROJECT_PATH}}/deploy.sh bb5c12e9'
```

脚本流程：先 `docker pull` 全部镜像（全部成功后才改写 `{{ENV_FILE}}`，失败不残留配置变更）→ 原子更新 `{{ENV_TAG_KEY}}` → `docker compose up -d --no-build --no-deps` 全部服务 → 逐一验证容器状态、镜像 tag 一致性、健康检查（`curl --fail`）。tag 必须通过 `^[0-9a-f]{7,40}$` 正则校验，拒绝 `dev`/`latest`/空值。

### 5. 验证部署

```bash
# 容器状态（确认镜像 tag 正确）
ssh {{SSH_CONNECTION}} 'docker compose -f {{PROJECT_PATH}}/{{COMPOSE_FILE}} ps'

# 健康检查（--fail 确保非 200 时退出非零）— 端口和路径见 config.md 服务列表
ssh {{SSH_CONNECTION}} 'curl -s --fail -o /dev/null -w "Backend:  HTTP %{http_code}\n" http://127.0.0.1:8080/health'
ssh {{SSH_CONNECTION}} 'curl -s --fail -o /dev/null -w "Frontend: HTTP %{http_code}\n" http://127.0.0.1:3000/'
ssh {{SSH_CONNECTION}} 'curl -s --fail -o /dev/null -w "Docs:     HTTP %{http_code}\n" http://127.0.0.1:4000/docs'

# 域名
curl -s --fail -o /dev/null -w "Domain:   HTTP %{http_code}\n" {{DOMAIN_URL}}

# 检查 Backend 日志（确认迁移正常，无 crash loop）
ssh {{SSH_CONNECTION}} 'docker logs aura-backend-1 --tail 20'
```

验证标准：全部容器 Up；健康检查全部返回 200；域名返回 200；无迁移报错、无 crash loop。

### 6. 迁移问题处理

若 Backend 因迁移失败反复重启：

```bash
# 查看迁移错误
ssh {{SSH_CONNECTION}} 'docker logs aura-backend-1 2>&1 | grep -i "migration\|ERROR"'

# 若迁移已是 no-op（如列名已存在），手动标记为已应用
ssh {{SSH_CONNECTION}} "docker exec {{DB_CONTAINER}} psql -U {{DB_USER}} -d {{DB_NAME}} -c \
  \"INSERT INTO schema_migrations (version, applied_at) VALUES ('<migration_name>', NOW()) ON CONFLICT DO NOTHING;\""

# 重启 Backend
ssh {{SSH_CONNECTION}} 'cd {{PROJECT_PATH}} && docker compose -f {{COMPOSE_FILE}} up -d --no-build --no-deps backend'
```

## 兜底：SCP 直传镜像

当 GHCR 不可用时（如 token 权限问题），可直接将本地构建的镜像通过 SCP 传输至服务器：

```bash
# 本地 save（镜像名见 config.md 服务列表）
docker save {{REGISTRY_IMAGE_PREFIX}}/aura-backend:<commit> \
           {{REGISTRY_IMAGE_PREFIX}}/aura-web:<commit> \
           {{REGISTRY_IMAGE_PREFIX}}/aura-docs:<commit> \
           -o /tmp/aura-images-<commit>.tar

# SCP 传输
scp /tmp/aura-images-<commit>.tar {{SSH_CONNECTION}}:/tmp/

# 服务器 load + 部署
ssh {{SSH_CONNECTION}} "
docker load -i /tmp/aura-images-<commit>.tar && \
cd {{PROJECT_PATH}} && \
docker compose -f {{COMPOSE_FILE}} up -d --no-build --no-deps frontend backend docs
"
```

> SCP 模式绕过 GHCR，镜像不经 registry。仅在 GHCR 不可用时使用。

## Aura CLI 发布流程

CLI 源码在 AuraManager 项目里，面向用户安装的 CLI 二进制通过 `{{CLI_MIRROR_URL}}` mirror 分发（fallback 到公开分发仓库 `{{CLI_RELEASE_REPO}}`）。

🚫 **CLI 也禁止在服务器上编译。** 必须本地交叉编译。

**发布策略：默认使用本地构建 + mirror 直传。** GitHub Actions 自动发布不稳定（历史多次连续失败），仅作为备选，不要依赖它。

### 代码与发布入口

- CLI 入口：`{{CLI_ENTRY}}`
- CLI-only GoReleaser 配置：`{{CLI_GORELEASER_CONFIG}}`（产物命名参考）
- CLI 发布 workflow：`{{CLI_RELEASE_WORKFLOW}}`（备选，勿依赖）
- Unix 安装脚本源码：`scripts/install.sh`
- 线上 Unix 安装脚本副本：`apps/web/public/scripts/install.sh`，线上地址 `{{CLI_INSTALL_SCRIPT_URL}}`
- Windows 安装脚本：`scripts/install.ps1` / `apps/web/public/scripts/install.ps1`
- 服务器 CLI mirror 路径：`{{CLI_MIRROR_PATH}}`
- nginx 镜像配置参考：`deploy/nginx/cli-mirror.conf`

### GoReleaser 产物

`{{CLI_GORELEASER_CONFIG}}` 只构建 `{{CLI_BINARY}}` CLI，不发布 Docker、Helm、Desktop 安装包。

构建要点：

- `main`: `{{CLI_ENTRY}}`
- `binary`: `{{CLI_BINARY}}`
- `CGO_ENABLED=0`
- 平台：`darwin` / `linux` / `windows`，架构：`amd64` / `arm64`
- ldflags 注入 `main.version`、`main.commit`、`main.date`
- checksum 文件：`checksums.txt`

会同时发布两套 archive 命名：

- 当前安装脚本与桌面 bootstrap 使用：
  - `aura-cli-<version>-<os>-<arch>.tar.gz`
  - Windows 为 `aura-cli-<version>-windows-<arch>.zip`
- 老版本 CLI 自更新兼容用：
  - `aura_<os>_<arch>.tar.gz`
  - Windows 为 `aura_windows_<arch>.zip`

不要随意删除 legacy `aura_<os>_<arch>` 产物，除非确认所有仍在使用的老 CLI 都不再依赖它。

### 发布流程（默认：本地构建 + mirror 直传）

默认发布路径。不依赖 GitHub Actions。产物同时上传到 mirror 和 `{{CLI_RELEASE_REPO}}` 仓库（`aura update` 命令走 GitHub API，所以 AuraRelease 也必须更新）。

1. 确定版本号：默认按 patch 版本递增（`v0.3.48` → `v0.3.49`），查看 `git tag --sort=-v:refname | head -5` 确认。

2. 推送 tag 到 GitHub（触发 GitHub Actions workflow，但不等待其完成）：
   ```bash
   git tag v0.3.49 <commit-hash>
   git push origin v0.3.49
   ```

3. 运行 Go 测试（网络策略见上文「网络与代理」）：
   ```bash
   cd server && GOPROXY=https://goproxy.cn,direct go test ./...
   ```

4. 本地交叉编译所有 6 个平台的 CLI：
   ```bash
   export VERSION=0.3.49  # 不带 v 前缀
   export COMMIT=<short-hash>
   export DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   export OUT=/tmp/aura-release/v0.3.49
   mkdir -p "$OUT"
   export GOPROXY=https://goproxy.cn,direct

   cd server
   for GOOS in darwin linux windows; do
     for GOARCH in amd64 arm64; do
       EXE="aura"
       if [ "$GOOS" = "windows" ]; then EXE="aura.exe"; fi
       SRC="/tmp/aura-build-$GOOS-$GOARCH"
       mkdir -p "$SRC"

       GOOS=$GOOS GOARCH=$GOARCH CGO_ENABLED=0 \
         go build -ldflags "-s -w -X main.version=$VERSION -X main.commit=$COMMIT -X main.date=$DATE" \
         -o "$SRC/$EXE" ./cmd/aura

       # Versioned archive
       if [ "$GOOS" = "windows" ]; then
         (cd "$SRC" && zip "$OUT/aura-cli-${VERSION}-${GOOS}-${GOARCH}.zip" "$EXE")
       else
         (cd "$SRC" && tar czf "$OUT/aura-cli-${VERSION}-${GOOS}-${GOARCH}.tar.gz" "$EXE")
       fi

       # Legacy archive
       if [ "$GOOS" = "windows" ]; then
         (cd "$SRC" && zip "$OUT/aura_${GOOS}_${GOARCH}.zip" "$EXE")
       else
         (cd "$SRC" && tar czf "$OUT/aura_${GOOS}_${GOARCH}.tar.gz" "$EXE")
       fi

       rm -rf "$SRC"
     done
   done

   # 生成 checksums
   cd "$OUT" && shasum -a 256 * > checksums.txt
   ```

5. 上传到服务器 CLI mirror：
   ```bash
   ssh {{SSH_CONNECTION}} 'mkdir -p {{CLI_MIRROR_PATH}}/v0.3.49'
   scp /tmp/aura-release/v0.3.49/* {{SSH_CONNECTION}}:{{CLI_MIRROR_PATH}}/v0.3.49/
   ssh {{SSH_CONNECTION}} 'echo "v0.3.49" > {{CLI_MIRROR_PATH}}/latest'
   ```

6. 提交到 AuraRelease 仓库并创建 GitHub Release（🚫 必须，不可跳过）：

   **仅把文件 push 到 main 分支是不够的！** `aura update` 走 GitHub Releases API，必须有正式的 GitHub Release + assets。

   ```bash
   # 先尝试 SSH clone，超时则用 HTTPS
   GIT_SSH_COMMAND="ssh -o ConnectTimeout=10" git clone --depth 1 git@github.com:{{CLI_RELEASE_REPO}}.git /tmp/aura-release-repo 2>&1 || \
     git clone --depth 1 https://github.com/{{CLI_RELEASE_REPO}}.git /tmp/aura-release-repo 2>&1

   mkdir -p /tmp/aura-release-repo/v0.3.49
   cp /tmp/aura-release/v0.3.49/* /tmp/aura-release-repo/v0.3.49/
   cd /tmp/aura-release-repo
   echo "v0.3.49" > latest
   git add v0.3.49/ latest
   git commit -m "release: publish aura cli v0.3.49"
   git tag v0.3.49
   git push origin main --tags
   ```

   然后创建 GitHub Release 并上传 assets（需要 `repo` scope 的 PAT）：
   ```bash
   TOKEN="<ghp_token>"
   TAG="v0.3.49"
   ASSETS_DIR="/tmp/aura-release/v0.3.49"

   # 创建 Release
   RELEASE_ID=$(curl -s -X POST \
     -H "Authorization: token $TOKEN" \
     -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/{{CLI_RELEASE_REPO}}/releases" \
     -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"body\":\"Aura CLI $TAG\",\"draft\":false,\"prerelease\":false}" \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

   # 上传所有 assets
   for f in "$ASSETS_DIR"/*; do
     name=$(basename "$f")
     curl -s -X POST \
       -H "Authorization: token $TOKEN" \
       -H "Content-Type: application/octet-stream" \
       --data-binary "@$f" \
       "https://uploads.github.com/repos/{{CLI_RELEASE_REPO}}/releases/$RELEASE_ID/assets?name=$name"
   done
   ```

   > ⚠️ **本机 git 不读取 macOS 系统代理**（`scutil --proxy` 显示 `HTTPProxy: 127.0.0.1:7897` 但 git clone 不走）。curl 能访问 GitHub 不代表 git 能 clone。
   >
   > 若 SSH 和 HTTPS 均超时（本机常见），**通过服务器中转** — 服务器 GitHub 连通正常：
   >
   > ```bash
   > # 1. SCP 产物到服务器
   > ssh {{SSH_CONNECTION}} 'mkdir -p /tmp/aura-release-v0.3.49'
   > scp /tmp/aura-release/v0.3.49/* {{SSH_CONNECTION}}:/tmp/aura-release-v0.3.49/
   >
   > # 2. 在服务器上 clone、提交、打 tag、创建 Release
   > ssh {{SSH_CONNECTION}} '
   > rm -rf /tmp/aura-release-repo && \
   > git clone --depth 1 git@github.com:{{CLI_RELEASE_REPO}}.git /tmp/aura-release-repo && \
   > mkdir -p /tmp/aura-release-repo/v0.3.49 && \
   > cp /tmp/aura-release-v0.3.49/* /tmp/aura-release-repo/v0.3.49/ && \
   > cd /tmp/aura-release-repo && \
   > echo "v0.3.49" > latest && \
   > git add v0.3.49/ latest && \
   > git commit -m "release: publish aura cli v0.3.49" && \
   > git tag v0.3.49 && \
   > git push origin main --tags
   > '
   >
   > # 3. 创建 GitHub Release + 上传 assets
   > ssh {{SSH_CONNECTION}} "
   > TOKEN=\"\$(python3 -c \"import json,base64; d=json.load(open('/root/.docker/config.json')); print(base64.b64decode(d['auths']['ghcr.io']['auth']).decode().split(':')[1])\")\" && \
   > RELEASE_ID=\$(curl -s -X POST -H \"Authorization: token \$TOKEN\" -H 'Accept: application/vnd.github+json' 'https://api.github.com/repos/{{CLI_RELEASE_REPO}}/releases' -d '{\"tag_name\":\"v0.3.49\",\"name\":\"v0.3.49\",\"body\":\"Aura CLI v0.3.49\",\"draft\":false,\"prerelease\":false}' | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"id\"])') && \
   > for f in {{CLI_MIRROR_PATH}}/v0.3.49/*; do name=\$(basename \"\$f\"); curl -s -X POST -H \"Authorization: token \$TOKEN\" -H 'Content-Type: application/octet-stream' --data-binary \"@\$f\" \"https://uploads.github.com/repos/{{CLI_RELEASE_REPO}}/releases/\$RELEASE_ID/assets?name=\$name\" -o /dev/null -w \"\$name %{http_code}\n\"; done
   > "
   > ```
   >
   > AuraRelease 缺失的后果：`aura update` 命令走 GitHub API 查询最新版本，Windows 安装脚本也从 AuraRelease 获取 latest tag。mirror 覆盖安装脚本的默认下载路径，但不覆盖 `aura update` 和 Windows 脚本的 tag 查询。

7. 执行「CLI 发布验证清单」。

### GitHub Actions 发布（备选）

GitHub Actions 自动发布历史不稳定（v0.3.47、v0.3.48、v0.3.49 连续失败），不推荐作为主路径。

若仍想尝试：

1. 推送 tag 触发 `{{CLI_RELEASE_WORKFLOW}}`（`v*.*.*` tag）
2. workflow 执行：校验 tag → `cd server && go test ./...` → GoReleaser 发布到 `{{CLI_RELEASE_REPO}}`
3. 需要仓库 secret `AURA_RELEASE_GITHUB_TOKEN`（对 AuraRelease 有 `contents: write`）

**若 GitHub Actions 失败：直接走上面的本地构建 + mirror 直传流程。不要重跑 workflow。**

### install.sh 下载逻辑

用户执行：

```bash
curl -fsSL {{CLI_INSTALL_SCRIPT_URL}} | bash
```

脚本逻辑：

1. 检测系统与架构，规范化为 GoReleaser 使用的名字：`darwin` / `linux`，`amd64` / `arm64`。
2. 优先从 `{{CLI_LATEST_URL}}` 获取最新 tag。
3. 如果 mirror latest 不可用，则 fallback 到 AuraRelease 的 GitHub latest release。
4. 组装 archive 名称：`aura-cli-${version}-${os}-${arch}.tar.gz`
5. 默认从 mirror 下载：`{{CLI_MIRROR_URL}}/${tag}/${archive}`
6. mirror 下载失败时 fallback 到 GitHub Release：`https://github.com/{{CLI_RELEASE_REPO}}/releases/download/${tag}/${archive}`
7. 解压 `aura`，优先安装到 `/usr/local/bin/aura`；若无写权限则用 `sudo`；没有 `sudo` 时安装到 `$HOME/.local/bin/aura`，并按需写入 shell rc 文件。

当前源码版 `scripts/install.sh` 比线上 `apps/web/public/scripts/install.sh` 多一些运维开关：

- `AURA_VERSION`：固定安装某个 tag，跳过 latest 查询。
- `AURA_CLI_MIRROR`：覆盖 mirror base URL；设为空字符串可跳过 mirror 直接走 GitHub。
- `AURA_GH_PROXY`：给 GitHub API 与 release 下载 URL 加代理前缀；源码版设置后会绕过 mirror，直接使用代理后的 GitHub URL。
- `AURA_BIN_DIR`：覆盖首选安装目录，常用于测试或脚本化安装。

### CLI 发布验证清单

本地构建完成后按这个顺序验：

1. `{{CLI_LATEST_URL}}` 返回目标 tag（如 `v0.3.49`）。
2. 至少抽查一个 mirror archive 能下载（HTTP 200）：
   ```bash
   curl -sI {{CLI_MIRROR_URL}}/v0.3.49/aura-cli-0.3.49-linux-amd64.tar.gz
   ```
3. Mirror checksums 存在且内容正确：
   ```bash
   curl -s {{CLI_MIRROR_URL}}/v0.3.49/checksums.txt | head
   ```
4. 下载 binary 并验证版本。
5. Smoke test installer。

## 注意事项

- 后端根路径 `/` 返回 404 是正常的（API 服务，无根路由），不代表后端异常。
- `{{ENV_FILE}}` 文件含密钥（JWT_SECRET 等），不要外泄或写入评论/issue。
- postgres 容器不要轻易重建（会丢数据），用 `--no-deps` 保护。
- 部署后务必验证域名访问，确认 nginx 转发正常。
- CLI release 和生产部署经常需要配套：生产发版前确认是否也需要发布匹配版本的 CLI。
- `{{COMPOSE_FILE_BUILD}}` 仅用于本地 dev 环境，**禁止在生产引用**。
- 镜像 tag 必须显式指定（commit hash），禁止使用 `dev` 或 `latest`。
- GitHub PAT 等密钥不要在 issue 评论中明文传递，应通过安全渠道共享。
- **CLI 发布默认走本地构建 + mirror 直传。不要依赖 GitHub Actions workflow（历史连续失败）。**
- **AuraRelease 必须推送。** `aura update` 和 Windows 安装脚本依赖 AuraRelease GitHub Releases。本地 git 不读 macOS 系统代理，即使 curl 能访问 GitHub，git clone 也可能超时。此时应通过服务器中转（服务器 `git clone git@github.com:…` 通常正常），不要跳过。
- **git 不走 macOS 系统代理。** 需要 clone/push GitHub 时，优先通过服务器操作。curl 能通不代表 git 能通。
