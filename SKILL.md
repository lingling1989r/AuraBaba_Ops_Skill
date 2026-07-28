---
name: dev-ops
description: 配置驱动的自托管服务运维。用于构建并发布 Docker 镜像、通过 SSH 执行 pull-only Docker Compose 部署、健康检查、故障回滚，以及可选的 Go CLI 发布。适用于“部署/升级/回滚/重启/检查服务/发布 CLI”等请求。
---

# DevOps 发布与运维

本 skill 的默认发布链路是：**本地构建与验证 → 推送不可变版本镜像 → 服务器先拉取全部镜像 → 原子更新版本 → 无构建重启 → 健康检查 → 失败回滚**。

## 1. 加载配置

开始前在项目根目录查找并完整读取 `devops.config.md`。若不存在，停止发布，提示用户从本 skill 的 `config.example.md` 复制并填写；不要猜测服务器、镜像、端口或凭证。

把配置中的服务表解析为清单，每项至少包含：

- Compose 服务名
- 完整镜像名
- Dockerfile 或构建命令
- 容器内/宿主机健康检查 URL
- 构建策略

然后检查必填项：`SSH_CONNECTION`、`PROJECT_PATH`、`REGISTRY_HOST`、`REGISTRY_IMAGE_PREFIX`、`COMPOSE_FILE`、`ENV_FILE`、`ENV_TAG_KEY`、`TARGET_ARCH` 和至少一个服务。

配置只定义参数，不代表授权。部署生产、覆盖版本、回滚、推送镜像或发布 CLI 前，必须确认用户请求确实包含该动作。

## 2. 强制安全边界

### 服务器只允许 pull + restart

永远不要在目标服务器执行构建：

- 禁止 `docker build`、`docker compose build` 和 `docker compose up --build`
- 禁止 `go build`、`npm/pnpm/yarn build` 或其他编译命令
- 禁止使用带 `build:` 的 Compose 文件
- 禁止在服务器临时修改源码来完成发布

所有构建在本地完成。服务器只执行镜像登录（需要时）、`docker pull`、配置切换、`docker compose up -d --no-build`、健康检查和回滚。

### 版本与凭证

- 镜像 tag 必须是不可变版本，默认使用当前完整 Git commit SHA；拒绝空值、`latest`、`dev`、分支名和可变 tag。
- 开始构建前确认 Git 工作区状态。若有未提交变更，明确说明构建对应的是工作区还是 HEAD；未经用户确认不得把脏工作区冒充为某个 commit 发布。
- 不在命令、日志、Markdown 或 issue 评论中写入 token/密码。优先使用已登录的 registry 凭据或 stdin/credential helper；不得使用 `echo '<token>'` 示例诱导凭证进入 shell history。
- 不使用 `git checkout` 恢复用户文件。若构建需要代理，应使用 Docker `--build-arg`/BuildKit secret 或项目已有机制；不得临时修改 Dockerfile 后再回滚。
- 不删除用户文件，不清理未知镜像/volume，不执行 `docker system prune`。

### 变更顺序

必须先成功拉取本次发布需要的**全部**镜像，再修改远端版本配置。不得边拉取边切换，也不得只更新一半服务后宣称全量发布成功。

## 3. 先生成发布计划

执行前输出一个简短计划，至少列出：

1. 目标环境与服务器（隐藏敏感信息）
2. 发布版本 tag 与来源 commit
3. 目标服务及对应镜像
4. 本地构建策略与目标架构
5. 远端 Compose 文件和健康检查
6. 回滚版本的获取方式

若用户只要求健康检查、重启单个服务或回滚，只执行对应路径，不自动扩大为完整发布。

## 4. 发布前检查

在任何远端状态变更前完成：

```bash
git status --short
git rev-parse --verify HEAD
docker version
docker context show
docker compose version
ssh {{SSH_CONNECTION}} 'command -v docker && docker compose version'
```

继续检查：

- 本地 Docker 可用，且支持 `{{TARGET_ARCH}}`
- 所有 Dockerfile/构建入口存在
- Compose 生产文件存在且不包含 `build:`
- 远端 `{{PROJECT_PATH}}`、`{{ENV_FILE}}` 和 `{{COMPOSE_FILE}}` 存在
- 磁盘空间足够
- 当前部署 tag 可读取，作为回滚候选

任何检查失败都应停止在状态变更之前，并报告具体失败项。

## 5. 本地构建

将 `RELEASE_TAG` 设为配置允许的不可变 tag，默认完整 commit SHA。每个服务严格按配置声明的策略构建。

### Docker 构建（`docker-node` / `docker-generic` / `go-docker`）

```bash
docker build \
  --platform {{TARGET_ARCH}} \
  --label org.opencontainers.image.revision="$RELEASE_TAG" \
  -t {{REGISTRY_IMAGE_PREFIX}}/<image-name>:"$RELEASE_TAG" \
  -f <Dockerfile> .
```

如项目支持 BuildKit，优先使用 cache mount 和 secret mount。代理值只能从当前环境或安全配置读取，不应写入 Dockerfile 或提交到仓库。

### Go 原生交叉编译（`go-cross`）

仅当配置明确列出二进制入口、输出名、运行时基础镜像和额外文件时使用。构建目录必须用 `mktemp -d` 创建并通过 trap 清理，避免复用 `/tmp` 中的旧产物：

```bash
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd {{GO_MODULE_DIR}}
GOOS={{TARGET_GOOS}} GOARCH={{TARGET_GOARCH}} CGO_ENABLED={{CGO_ENABLED}} \
  go build -trimpath -ldflags "{{GO_LDFLAGS}}" \
  -o "$BUILD_DIR/<binary>" <entry>
```

打包镜像前逐项确认额外文件来源存在。不要用未引用当前构建目录的固定 `/tmp/<project>-bin`。

## 6. 本地验证

推送前对每个镜像执行：

```bash
docker image inspect {{REGISTRY_IMAGE_PREFIX}}/<image>:"$RELEASE_TAG" \
  --format '{{.Os}}/{{.Architecture}}'
```

结果必须匹配 `{{TARGET_ARCH}}`。配置了 smoke test 的服务，使用独立随机宿主端口启动，等待配置的超时时间并用 `curl --fail --show-error` 检查；无论成功失败都清理测试容器。

Go 二进制至少执行 `--help` 或配置的只读自检命令。任一验证失败：停止，不推送、不部署。

## 7. 推送镜像

使用本机已有安全登录态登录 registry。逐个推送后以 digest 验证远端清单：

```bash
docker push {{REGISTRY_IMAGE_PREFIX}}/<image>:"$RELEASE_TAG"
docker buildx imagetools inspect {{REGISTRY_IMAGE_PREFIX}}/<image>:"$RELEASE_TAG"
```

记录每个镜像 digest。任何镜像推送或检查失败：停止，不修改远端配置。

## 8. 远端原子部署

优先使用项目中**已审查、pull-only、支持回滚**的部署脚本：

```bash
ssh {{SSH_CONNECTION}} '{{PROJECT_PATH}}/{{DEPLOY_SCRIPT}} <release-tag>'
```

执行前先读取脚本，确认它：

- 严格校验 tag 且拒绝可变 tag
- 不含任何构建命令
- 先拉取全部镜像，再更新环境文件
- 使用临时文件 + `mv` 原子替换环境文件
- `docker compose up` 包含 `--no-build`
- 失败会恢复旧环境文件并重启旧版本
- 检查的是 Compose service/container ID，而不是猜测容器名

若没有合格脚本，按以下事务顺序手动执行。命令中的具体服务与镜像必须由配置清单生成，不能照抄示例：

1. 读取并记录旧 tag、当前容器状态和当前镜像。
2. 在不改配置的前提下拉取全部新镜像。
3. 备份 `{{ENV_FILE}}`，生成只修改 `{{ENV_TAG_KEY}}` 的同目录临时文件。
4. 校验临时文件后原子 `mv`。
5. 加载环境，执行：

```bash
docker compose -f {{COMPOSE_FILE}} up -d --no-build --no-deps <services>
```

6. 等待健康检查，在配置的总超时内轮询，不使用一次固定 `sleep` 作为成功依据。
7. 失败时恢复备份、导出旧 tag、重新 `up -d --no-build --no-deps`，并再次验证旧版本健康状态。

远端 shell 应使用严格模式（`set -euo pipefail`）。备份文件权限不得比原 `.env` 更宽；完成后清理临时文件，成功后按配置保留有限数量备份。

## 9. 验证与结果

至少验证：

- `docker compose ps` 中目标服务正在运行且无 restart loop
- 每个目标服务实际镜像引用或 digest 与本次发布一致
- 每个内部健康检查返回预期状态
- 配置了域名时，外部 URL 使用 `curl --fail --location` 验证
- 最近日志中无启动、迁移或 panic/fatal 错误

最终报告包含：环境、tag/commit、服务、镜像 digest、健康检查结果、是否发生回滚。不要输出凭证或完整敏感配置。

## 10. 独立操作路径

### 健康检查

只读取状态、健康端点和有限日志；不得顺便拉取镜像、修改配置或重启服务。

### 重启服务

确认服务名来自配置，然后执行 `docker compose ... up -d --no-build --no-deps <service>`。重启后验证健康；不改变 tag。

### 回滚

用户指定 tag 时先确认对应全部镜像存在。未指定时使用最近一次已知健康 tag；无法可靠确认则停止询问，不猜测。回滚仍遵循“先拉取全部镜像 → 原子切换 → 无构建重启 → 验证”。

### Registry 不可用时的镜像直传

仅在用户同意且配置允许 `SCP_FALLBACK` 时使用。对目标 tag 的全部镜像执行 `docker save`，计算 SHA-256，传输后在服务器校验再 `docker load`。直传成功后仍按原子部署流程切换。不得把直传当作绕过 registry 权限问题的默认方案。

## 11. CLI 发布（可选）

仅当 `CLI_ENABLED=true` 且用户明确要求发布 CLI 时执行：

1. 校验语义化版本、Git tag 状态与工作区清洁度。
2. 在本地按配置矩阵交叉编译，使用 `-trimpath`，注入版本/commit。
3. 生成归档文件与 `checksums.txt`，逐个校验归档内容可执行。
4. 上传 mirror 或创建 GitHub Release；上传后重新下载或查询并核对 checksum。
5. 验证 latest 元数据和安装脚本实际能解析新版本。

CLI 也禁止在服务器编译。不得覆盖已经存在的同名正式版本；版本冲突时停止并报告。

## 12. 常见故障处理

- **依赖下载超时**：先检查代理/registry/DNS；使用配置里的安全代理传递方式，不改源码兜底。
- **架构不匹配**：停止部署，重新为 `{{TARGET_ARCH}}` 构建；不要依赖服务器现场构建修复。
- **迁移失败**：保留日志并回滚。除非用户明确授权且已确认迁移为幂等 no-op，否则不得手动篡改迁移表。
- **新版本不健康**：执行回滚并同时报告新版本和回滚后的健康状态；不要只恢复 `.env` 而不恢复容器。
- **回滚也失败**：停止进一步变更，保留现场信息，明确标记为阻塞并请求人工介入。
