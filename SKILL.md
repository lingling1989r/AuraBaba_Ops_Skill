---
name: dev-ops
description: 通用 DevOps 运维：本地构建镜像 → 推送镜像仓库 → 服务器拉取部署。配置驱动，支持任意 Docker Compose 项目。当需要构建部署、更新服务、重启容器、验证域名访问时使用。
---

# 通用 DevOps 运维 / 升级发布

> **开始前请先读取项目中的 `devops.config.md`** — 所有服务器地址、镜像名、端口、构建策略等均定义在该文件中。
> 本文档中 `{{KEY}}` 表示引用 config 中的配置值。
> 如果你的项目还没有 `devops.config.md`，参考本 skill 目录下的 `config.example.md` 创建。

通用自托管部署的升级与发布运维流程。适配任意 Docker Compose 项目，支持多种构建策略（Docker 构建、Go 交叉编译、静态文件等）。

## 🚫 禁止事项（强制）

**永远不要在服务器环境上 build 镜像或 CLI 二进制！**

- ❌ 禁止 `docker compose ... --build`
- ❌ 禁止 `docker build`
- ❌ 禁止 `go build` 编译 CLI
- ❌ 禁止任何在服务器上编译/构建的行为
- ❌ 禁止引用 `{{COMPOSE_FILE_BUILD}}`（含 `build:` 指令）

**所有镜像和 CLI 必须在本地构建，推送至镜像仓库，服务器只做 pull + restart。**

违反此规则会导致：
- 服务器资源耗尽（build 消耗大量 CPU/内存）
- 服务中断（build 期间容器不可用）
- QEMU/架构不兼容问题（服务器 x86_64，本地 ARM64）

## 环境信息

- 服务器：`{{SERVER_HOST}}`，SSH 连接 `ssh {{SSH_CONNECTION}}`
- 项目代码路径：`{{PROJECT_PATH}}`
- Web 域名：`{{DOMAIN_URL}}`（如有配置）
- 镜像仓库：`{{REGISTRY_IMAGE_PREFIX}}`
- 部署方式：Docker Compose（**仅 `{{COMPOSE_FILE}}`**，禁止引用 `{{COMPOSE_FILE_BUILD}}`）
  - 服务列表：见 `devops.config.md` 中的服务列表
  - 镜像通过 `{{ENV_FILE}}` 环境变量指定，使用显式版本 tag（commit hash），禁止 `dev` / `latest`

## 本地构建环境

本机为 macOS ARM64，生产服务器为 x86_64。使用 `{{DOCKER_RUNTIME}}` + Docker 构建 `{{TARGET_ARCH}}` 镜像。

```bash
# 检查/启动 Colima（macOS）
colima status 2>&1 || colima start --vm-type vz --cpu 4 --memory 8

# 确认 Docker context
docker context show    # 应显示 colima

# 验证 amd64 模拟可用
docker run --rm --platform linux/amd64 alpine:3.21 uname -m  # 输出 x86_64
```

> Rosetta 2 未安装时 Colima 用 QEMU 模拟 amd64。Go 编译在 QEMU 下可能 SIGSEGV → 改用**原生交叉编译**（`go-cross` 构建策略）。

### 网络与代理

Colima VM / QEMU 容器内网络可能不稳定（registry.npmjs.org 超时、Google Fonts 超时、proxy.golang.org 超时）。

**Go 模块下载：**

```bash
PROXY="{{LOCAL_PROXY}}"

# 策略 1：先尝试代理 + goproxy.cn
export HTTP_PROXY=$PROXY HTTPS_PROXY=$PROXY
GOPROXY=https://goproxy.cn,direct go mod download

# 策略 2：若代理超时，取消代理直连
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
GOPROXY=https://goproxy.cn,direct go mod download
```

**Docker build 网络问题（Google Fonts / npm 超时）：**

QEMU 模拟 amd64 容器时，`docker build --network host` 不被支持。Docker build 内部网络超时，**首选通过代理解决：**

1. 确认代理可达（Colima 将 `127.0.0.1` 映射为 `{{COLIMA_PROXY_HOST}}`）：
   ```bash
   curl -s -o /dev/null -w "%{http_code}" --proxy {{LOCAL_PROXY}} https://fonts.googleapis.com
   # 返回 404 表示连通
   ```

2. 临时修改 Dockerfile，在 build 步骤前加 ARG + ENV 传递代理：
   ```dockerfile
   ARG HTTP_PROXY
   ARG HTTPS_PROXY
   ARG http_proxy
   ARG https_proxy
   ENV HTTP_PROXY=$HTTP_PROXY
   ENV HTTPS_PROXY=$HTTPS_PROXY
   ENV http_proxy=$http_proxy
   ENV https_proxy=$https_proxy
   ```

3. 构建时使用 `{{COLIMA_PROXY}}`（不能用 `127.0.0.1`，容器内 127.0.0.1 指向容器自身）：
   ```bash
   docker build --platform {{TARGET_ARCH}} \
     --build-arg HTTP_PROXY={{COLIMA_PROXY}} \
     --build-arg HTTPS_PROXY={{COLIMA_PROXY}} \
     --build-arg http_proxy={{COLIMA_PROXY}} \
     --build-arg https_proxy={{COLIMA_PROXY}} \
     -t {{REGISTRY_IMAGE_PREFIX}}/<image>:<commit> -f <Dockerfile> .
   ```

4. 构建完成后恢复 Dockerfile：
   ```bash
   git checkout <Dockerfile>
   ```

> ⚠️ **仅靠 `--build-arg` 不够**：Dockerfile 没有预定义 ARG 时，build-arg 不会自动变成环境变量。必须临时添加 `ARG` + `ENV` 配对。
> ⚠️ **代理地址必须用 `192.168.5.2`**：Colima VM 内的容器通过 bridge 网络访问宿主。

## 升级发布流程

完整流程：**本地构建镜像 → 推送镜像仓库 → 服务器拉取 → 重启容器**。全程不在服务器执行任何 build。

### 1. 本地构建镜像

根据 `devops.config.md` 中每个服务的构建策略执行：

#### 策略：`docker-node` / `docker-generic` — Docker 构建

```bash
cd <project-root>

# 若 Google Fonts / npm 超时，按上文「代理方案」临时修改 Dockerfile
docker build --platform {{TARGET_ARCH}} \
  -t {{REGISTRY_IMAGE_PREFIX}}/<image-name>:<commit> \
  -f <Dockerfile> .
```

#### 策略：`go-cross` — Go 原生交叉编译 + Docker 打包

```bash
cd <project-root>

# 网络策略：先尝试代理；代理超时则取消代理直连 + goproxy.cn
export GOPROXY={{GO_MODULE_PROXY}}
# 代理：export HTTP_PROXY={{LOCAL_PROXY}} HTTPS_PROXY={{LOCAL_PROXY}}

mkdir -p /tmp/<project>-bin
cd {{GO_MODULE_DIR}}

# 逐个编译 Go 二进制（根据配置中的 GO_BINARIES）
# 格式: binary:entry（逗号分隔），如 server:./cmd/server,migrate:./cmd/migrate
for bin_info in $(echo "{{GO_BINARIES}}" | tr ',' '\n'); do
  bin_name=$(echo "$bin_info" | cut -d: -f1)
  bin_entry=$(echo "$bin_info" | cut -d: -f2)
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
    go build -ldflags "{{GO_LDFLAGS_DEFAULT}}" \
    -o /tmp/<project>-bin/"$bin_name" "$bin_entry"
done

# 特殊版本号 flags 的二进制（如有配置）
# GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
#   go build -ldflags "{{GO_LDFLAGS_VERSIONED}}" \
#   -o /tmp/<project>-bin/<binary> <entry>
cd ..

# 准备 Backend build context（跳过 Go builder stage）
mkdir -p /tmp/<project>-backend-build
cp /tmp/<project>-bin/* /tmp/<project>-backend-build/
# 复制额外文件（migrations, docs seed 等）
cp -r <extra-files> /tmp/<project>-backend-build/
cp {{BACKEND_ENTRYPOINT}} /tmp/<project>-backend-build/

cat > /tmp/<project>-backend-build/Dockerfile.backend << 'DOCKERFILE'
FROM {{BACKEND_BASE_IMAGE}}
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY . .
RUN sed -i 's/\r$//' entrypoint.sh && chmod +x entrypoint.sh
EXPOSE {{BACKEND_PORT}}
ENTRYPOINT ["./entrypoint.sh"]
DOCKERFILE

docker build --platform {{TARGET_ARCH}} \
  -t {{REGISTRY_IMAGE_PREFIX}}/<backend-image>:<commit> \
  -f /tmp/<project>-backend-build/Dockerfile.backend /tmp/<project>-backend-build/
```

### 2. 架构检查与冒烟测试

```bash
# 检查每个服务镜像架构
for img in <image-name-1> <image-name-2> <image-name-3>; do
  docker inspect {{REGISTRY_IMAGE_PREFIX}}/$img:<commit> --format "$img: {{.Architecture}}/{{.Os}}"
done

# Backend 二进制验证（go-cross 策略）
docker run --rm --platform {{TARGET_ARCH}} --entrypoint /app/<binary> \
  {{REGISTRY_IMAGE_PREFIX}}/<backend-image>:<commit> --help

# 每个 HTTP 服务的启动验证
# docker run -d --rm --platform {{TARGET_ARCH}} --name test-<svc> -p <test-port>:<svc-port> \
#   {{REGISTRY_IMAGE_PREFIX}}/<image>:<commit>
# sleep 10 && curl -s -o /dev/null -w "<svc>: HTTP %{http_code}\n" http://localhost:<test-port>/<health-path>
# docker stop test-<svc>
```

### 3. 推送至镜像仓库

```bash
# 登录（GHCR 需要 write:packages scope 的 PAT）
echo '<token>' | docker login {{REGISTRY_HOST}} -u {{REGISTRY_LOGIN_USER}} --password-stdin

# 推送每个服务镜像（根据服务列表）
docker push {{REGISTRY_IMAGE_PREFIX}}/<image-1>:<commit>
docker push {{REGISTRY_IMAGE_PREFIX}}/<image-2>:<commit>
docker push {{REGISTRY_IMAGE_PREFIX}}/<image-3>:<commit>

# 验证远端
for img in <image-1> <image-2> <image-3>; do
  docker manifest inspect {{REGISTRY_IMAGE_PREFIX}}/$img:<commit>
done
```

### 4. 服务器拉取并部署

**优先使用服务器上的 `deploy.sh`**（含回滚、原子替换等安全机制）：

```bash
ssh {{SSH_CONNECTION}} '{{PROJECT_PATH}}/deploy.sh <commit>'
```

**手动步骤**（仅脚本不可用时，注意顺序：先 pull 再改配置）：

```bash
# 1. 登录仓库并先拉取全部镜像（失败不改变配置）
ssh {{SSH_CONNECTION}} "
echo '<token>' | docker login {{REGISTRY_HOST}} -u {{REGISTRY_LOGIN_USER}} --password-stdin && \
docker pull {{REGISTRY_IMAGE_PREFIX}}/<image-1>:<commit> && \
docker pull {{REGISTRY_IMAGE_PREFIX}}/<image-2>:<commit> && \
docker pull {{REGISTRY_IMAGE_PREFIX}}/<image-3>:<commit>
"

# 2. 镜像全部拉取成功后，原子更新 .env
ssh {{SSH_CONNECTION}} "
cd {{PROJECT_PATH}} && \
cp {{ENV_FILE}} {{ENV_FILE}}.bak && \
sed '/^{{ENV_TAG_KEY}}=/d' {{ENV_FILE}}.bak > {{ENV_FILE}}.tmp && \
echo '{{ENV_TAG_KEY}}=<commit>' >> {{ENV_FILE}}.tmp && \
mv {{ENV_FILE}}.tmp {{ENV_FILE}}
"

# 3. 重启容器（--no-build，绝不 build）
# <service-names> = config 中服务列表的服务名列（空格分隔）
ssh {{SSH_CONNECTION}} "
cd {{PROJECT_PATH}} && \
export {{ENV_TAG_KEY}}='<commit>' && \
docker compose -f {{COMPOSE_FILE}} up -d --no-build --no-deps <service-names>
"
```

> ⚠️ 仅使用 `{{COMPOSE_FILE}}`，不得引用 `{{COMPOSE_FILE_BUILD}}`。

### 5. 验证部署

```bash
# 容器状态（确认镜像 tag 正确）
ssh {{SSH_CONNECTION}} 'docker compose -f {{PROJECT_PATH}}/{{COMPOSE_FILE}} ps'

# 健康检查 — 对每个服务执行 config 中配置的健康检查 URL
ssh {{SSH_CONNECTION}} 'curl -s --fail -o /dev/null -w "<svc>: HTTP %{http_code}\n" <health-check-url>'

# 域名（如有配置）
curl -s --fail -o /dev/null -w "Domain: HTTP %{http_code}\n" {{DOMAIN_URL}}

# 检查后端日志（确认迁移正常，无 crash loop）
ssh {{SSH_CONNECTION}} 'docker logs <backend-container> --tail 20'
```

验证标准：全部容器 Up；健康检查全部返回 200；域名返回 200；无迁移报错、无 crash loop。

### 6. 迁移问题处理（如有数据库）

若 Backend 因数据库迁移失败反复重启：

```bash
# 查看迁移错误
ssh {{SSH_CONNECTION}} 'docker logs <backend-container> 2>&1 | grep -i "migration\|ERROR"'

# 若迁移已是 no-op（如列名已存在），手动标记为已应用
ssh {{SSH_CONNECTION}} "docker exec {{DB_CONTAINER}} psql -U {{DB_USER}} -d {{DB_NAME}} -c \
  \"INSERT INTO {{DB_MIGRATIONS_TABLE}} (version, applied_at) VALUES ('<migration_name>', NOW()) ON CONFLICT DO NOTHING;\""

# 重启 Backend
ssh {{SSH_CONNECTION}} 'cd {{PROJECT_PATH}} && docker compose -f {{COMPOSE_FILE}} up -d --no-build --no-deps backend'
```

## 兜底：SCP 直传镜像

当镜像仓库不可用时，可直接将本地构建的镜像通过 SCP 传输至服务器：

```bash
# 本地 save 全部镜像
docker save {{REGISTRY_IMAGE_PREFIX}}/<image-1>:<commit> \
           {{REGISTRY_IMAGE_PREFIX}}/<image-2>:<commit> \
           {{REGISTRY_IMAGE_PREFIX}}/<image-3>:<commit> \
           -o /tmp/<project>-images-<commit>.tar

# SCP 传输
scp /tmp/<project>-images-<commit>.tar {{SSH_CONNECTION}}:/tmp/

# 服务器 load + 部署
ssh {{SSH_CONNECTION}} "
docker load -i /tmp/<project>-images-<commit>.tar && \
cd {{PROJECT_PATH}} && \
docker compose -f {{COMPOSE_FILE}} up -d --no-build --no-deps <service-names>
"
```

> SCP 模式绕过镜像仓库。仅在仓库不可用时使用。

## CLI 发布流程（如 `CLI_ENABLED=true`）

### 代码与发布入口

- CLI 入口：`{{CLI_ENTRY}}`
- CLI 二进制：`{{CLI_BINARY}}`
- GoReleaser 配置：`{{CLI_GORELEASER_CONFIG}}`
- 安装脚本 URL：`{{CLI_INSTALL_SCRIPT_URL}}`
- 服务器 CLI mirror 路径：`{{CLI_MIRROR_PATH}}`

🚫 **CLI 也禁止在服务器上编译。** 必须本地交叉编译。

### 发布流程（本地构建 + mirror 直传）

1. 确定版本号：默认按 patch 版本递增，查看 `git tag --sort=-v:refname | head -5`。

2. 推送 tag 到 GitHub（触发 CI，但不等待其完成）：
   ```bash
   git tag v<version> <commit-hash>
   git push origin v<version>
   ```

3. 运行测试：
   ```bash
   cd {{GO_MODULE_DIR}} && GOPROXY={{GO_MODULE_PROXY}} go test ./...
   ```

4. 本地交叉编译所有平台（darwin/linux/windows × amd64/arm64）：
   ```bash
   export VERSION=<version>        # 不带 v 前缀
   export COMMIT=<short-hash>
   export DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   export OUT=/tmp/<project>-release/v<version>
   mkdir -p "$OUT"
   export GOPROXY={{GO_MODULE_PROXY}}

   cd {{GO_MODULE_DIR}}
   for GOOS in darwin linux windows; do
     for GOARCH in amd64 arm64; do
       EXE="{{CLI_BINARY}}"
       if [ "$GOOS" = "windows" ]; then EXE="{{CLI_BINARY}}.exe"; fi
       SRC="/tmp/cli-build-$GOOS-$GOARCH"
       mkdir -p "$SRC"

       GOOS=$GOOS GOARCH=$GOARCH CGO_ENABLED=0 \
         go build -ldflags "-s -w -X main.version=$VERSION -X main.commit=$COMMIT -X main.date=$DATE" \
         -o "$SRC/$EXE" {{CLI_ENTRY}}

       if [ "$GOOS" = "windows" ]; then
         (cd "$SRC" && zip "$OUT/{{CLI_BINARY}}-${VERSION}-${GOOS}-${GOARCH}.zip" "$EXE")
       else
         (cd "$SRC" && tar czf "$OUT/{{CLI_BINARY}}-${VERSION}-${GOOS}-${GOARCH}.tar.gz" "$EXE")
       fi

       rm -rf "$SRC"
     done
   done

   # 生成 checksums
   cd "$OUT" && shasum -a 256 * > checksums.txt
   ```

5. 上传到服务器 CLI mirror：
   ```bash
   ssh {{SSH_CONNECTION}} 'mkdir -p {{CLI_MIRROR_PATH}}/v<version>'
   scp $OUT/* {{SSH_CONNECTION}}:{{CLI_MIRROR_PATH}}/v<version>/
   ssh {{SSH_CONNECTION}} 'echo "v<version>" > {{CLI_MIRROR_PATH}}/latest'
   ```

6. 提交到 Release 仓库并创建 GitHub Release：

   ```bash
   # Clone release repo（本机不通时走服务器中转）
   git clone --depth 1 https://github.com/{{CLI_RELEASE_REPO}}.git /tmp/cli-release-repo
   mkdir -p /tmp/cli-release-repo/v<version>
   cp $OUT/* /tmp/cli-release-repo/v<version>/
   cd /tmp/cli-release-repo
   echo "v<version>" > latest
   git add v<version>/ latest
   git commit -m "release: publish {{CLI_BINARY}} v<version>"
   git tag v<version>
   git push origin main --tags
   ```

   然后创建 GitHub Release 并上传 assets：
   ```bash
   TOKEN="<ghp_token>"
   TAG="v<version>"
   RELEASE_ID=$(curl -s -X POST \
     -H "Authorization: token $TOKEN" \
     -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/{{CLI_RELEASE_REPO}}/releases" \
     -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"body\":\"{{CLI_BINARY}} $TAG\",\"draft\":false,\"prerelease\":false}" \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

   for f in "$OUT"/*; do
     name=$(basename "$f")
     curl -s -X POST \
       -H "Authorization: token $TOKEN" \
       -H "Content-Type: application/octet-stream" \
       --data-binary "@$f" \
       "https://uploads.github.com/repos/{{CLI_RELEASE_REPO}}/releases/$RELEASE_ID/assets?name=$name" \
       -o /dev/null -w "$name %{http_code}\n"
   done
   ```

   > ⚠️ **本机 git 不读取 macOS 系统代理**。若 git clone/push GitHub 超时，通过服务器中转。
   > 服务器上 `git clone git@github.com:…` 通常正常。

### CLI 发布验证清单

1. `{{CLI_LATEST_URL}}` 返回目标 tag。
2. 至少抽查一个 mirror archive 能下载（HTTP 200）。
3. Mirror checksums 存在且内容正确。
4. 下载 binary 并验证版本。
5. Smoke test installer。

## 部署脚本模板

服务器端部署脚本结构（`deploy.sh`）：

```bash
#!/usr/bin/env bash
set -euo pipefail

# 参数校验
if [ "$#" -ne 1 ]; then
  echo "用法: $0 <commit-tag>"
  exit 1
fi
COMMIT_TAG="$1"
# 校验 tag 格式：^[0-9a-f]{7,40}$
if ! echo "$COMMIT_TAG" | grep -qE '^[0-9a-f]{7,40}$'; then
  echo "错误: tag 格式不正确"
  exit 1
fi

cd "$(dirname "$0")"
COMPOSE="docker compose -f {{COMPOSE_FILE}}"
ENV_FILE="{{ENV_FILE}}"
ENV_BAK=".env.bak.$$"
ENV_TMP=".env.tmp.$$"
ROLLBACK=false
OLD_TAG=""

cleanup() {
  if [ "$ROLLBACK" = true ] && [ -f "$ENV_BAK" ]; then
    echo "==> 回滚 .env 到旧配置..."
    mv "$ENV_BAK" "$ENV_FILE"
    if [ -n "$OLD_TAG" ] && [ "$OLD_TAG" != "unknown" ]; then
      echo "==> 回滚容器到旧镜像 $OLD_TAG ..."
      export {{ENV_TAG_KEY}}="$OLD_TAG"
      set -a; source "$ENV_FILE"; set +a
      export {{ENV_TAG_KEY}}="$OLD_TAG"
      $COMPOSE up -d --no-build --no-deps <service-names> 2>/dev/null || \
        echo "⚠️ 容器回滚失败，请手动检查"
    fi
    echo "❌ 部署已回滚到 $OLD_TAG"
  fi
  rm -f "$ENV_BAK" "$ENV_TMP"
}
trap cleanup EXIT

OLD_TAG=$(grep '^{{ENV_TAG_KEY}}=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo "unknown")
echo "  当前 {{ENV_TAG_KEY}}=$OLD_TAG"

# 1. git pull
echo "==> [1/5] git pull 更新代码..."
git checkout main && git pull --ff-only

# 2. docker pull 全部镜像
echo "==> [2/5] 拉取镜像..."
for img in <image-1> <image-2> <image-3>; do
  docker pull "{{REGISTRY_IMAGE_PREFIX}}/$img:${COMMIT_TAG}"
done
echo "  全部镜像拉取成功"

# 3. 原子更新 .env
echo "==> [3/5] 原子更新 {{ENV_TAG_KEY}}=$COMMIT_TAG ..."
cp "$ENV_FILE" "$ENV_BAK"
ROLLBACK=true
sed '/^{{ENV_TAG_KEY}}=/d' "$ENV_BAK" > "$ENV_TMP"
echo "{{ENV_TAG_KEY}}=$COMMIT_TAG" >> "$ENV_TMP"
mv "$ENV_TMP" "$ENV_FILE"
export {{ENV_TAG_KEY}}="$COMMIT_TAG"
set -a; source "$ENV_FILE"; set +a
export {{ENV_TAG_KEY}}="$COMMIT_TAG"

# 4. 重启容器
echo "==> [4/5] 重启全部容器..."
$COMPOSE up -d --no-build --no-deps <service-names>

# 5. 验证
echo "==> [5/5] 验证服务..."
sleep 5

PASS=true
# 检查容器状态
for svc in <container-name-1> <container-name-2> ...; do
  if docker ps --filter "name=${svc}" --format '{{.Names}}' | grep -q .; then
    echo "  ✅ $svc: Up"
  else
    echo "  ❌ $svc: NOT RUNNING"
    PASS=false
  fi
done

# 检查镜像 tag
# ...

# 健康检查
# curl ...

if [ "$PASS" = true ]; then
  ROLLBACK=false
  echo "✓ 部署完成 ($COMMIT_TAG)"
else
  echo "❌ 部署验证失败，开始回滚..."
  exit 1
fi
```

## 为新项目接入

1. 从本 skill 的 `config.example.md` 复制一份到项目目录，重命名为 `devops.config.md`
2. 填写所有 `{{...}}` 占位符为你项目的实际值
3. 在服务器上创建 `deploy.sh`（参考上方模板，填入具体值）
4. 确保服务器上有 `{{COMPOSE_FILE}}` 和 `{{ENV_FILE}}`
5. 执行一次完整的「升级发布流程」验证配置正确

## 注意事项

- `{{ENV_FILE}}` 文件含密钥（JWT_SECRET 等），不要外泄或写入评论/issue。
- postgres 容器不要轻易重建（会丢数据），用 `--no-deps` 保护。
- 部署后务必验证域名访问。
- `{{COMPOSE_FILE_BUILD}}` 仅用于本地 dev 环境，**禁止在生产引用**。
- 镜像 tag 必须显式指定（commit hash），禁止使用 `dev` 或 `latest`。
- Token/密钥不要在 issue 评论中明文传递，应通过安全渠道共享。
- **git 不走 macOS 系统代理。** 需要 clone/push GitHub 时，优先通过服务器操作。
