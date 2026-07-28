#!/usr/bin/env bash
# AuraManager 服务器端部署脚本（PULL-ONLY，禁止 build）
# 用法: ./deploy.sh <commit-tag>
#   <commit-tag>: 必填，镜像版本 tag（commit hash），禁止 dev/latest
#
# ⚠️ 此脚本仅做 docker pull + docker compose up -d --no-build。
#    镜像必须在本地预先构建并推送至 GHCR，服务器禁止 build。
#    compose 只引用 docker-compose.selfhost.yml，不引用 .build.yml。
#    单一 AURA_IMAGE_TAG 下原子化全量部署，确保前后端版本一致。
set -euo pipefail

# --- [0] 参数校验（在任何状态变更之前） ---
if [ "$#" -ne 1 ]; then
  echo "用法: $0 <commit-tag>"
  echo "  <commit-tag>: 必填，镜像版本 tag（commit hash），不接受 dev/latest"
  echo "  部署所有服务（frontend + backend + docs），确保版本一致"
  exit 1
fi

COMMIT_TAG="$1"

if ! echo "$COMMIT_TAG" | grep -qE '^[0-9a-f]{7,40}$'; then
  echo "错误: tag 格式不正确，应为 7-40 位十六进制 commit hash（如 242a9f89 或 bb5c12e9）"
  echo "  输入的 tag: $COMMIT_TAG"
  echo "  不接受 dev、latest 或空值"
  exit 1
fi

cd "$(dirname "$0")"
COMPOSE="docker compose -f docker-compose.selfhost.yml"
ENV_FILE=".env"
ENV_BAK=".env.bak.$$"
ENV_TMP=".env.tmp.$$"
ROLLBACK=false
OLD_TAG=""

cleanup() {
  if [ "$ROLLBACK" = true ] && [ -f "$ENV_BAK" ]; then
    echo ""
    echo "==> 回滚 .env 到旧配置..."
    mv "$ENV_BAK" "$ENV_FILE"
    if [ -n "$OLD_TAG" ] && [ "$OLD_TAG" != "unknown" ]; then
      echo "==> 回滚容器到旧镜像 $OLD_TAG ..."
      export AURA_IMAGE_TAG="$OLD_TAG"
      set -a; source "$ENV_FILE"; set +a
      export AURA_IMAGE_TAG="$OLD_TAG"
      $COMPOSE up -d --no-build --no-deps frontend backend docs 2>/dev/null || \
        echo "⚠️ 容器回滚失败，请手动检查"
    fi
    echo "❌ 部署已回滚到 $OLD_TAG"
  fi
  rm -f "$ENV_BAK" "$ENV_TMP"
}
trap cleanup EXIT

# 记录当前 tag 用于回滚
OLD_TAG=$(grep '^AURA_IMAGE_TAG=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo "unknown")
echo "  当前 AURA_IMAGE_TAG=$OLD_TAG"

# --- [1/5] git pull ---
echo "==> [1/5] git pull 更新代码..."
git checkout main
git pull --ff-only

# --- [2/5] docker pull（必须全部成功后才改配置） ---
echo "==> [2/5] 拉取镜像 ghcr.io/lingling1989r/*:${COMMIT_TAG} ..."
docker pull "ghcr.io/lingling1989r/aura-backend:${COMMIT_TAG}"
docker pull "ghcr.io/lingling1989r/aura-web:${COMMIT_TAG}"
docker pull "ghcr.io/lingling1989r/aura-docs:${COMMIT_TAG}"
echo "  全部镜像拉取成功"

# --- [3/5] 原子更新 .env ---
echo "==> [3/5] 原子更新 AURA_IMAGE_TAG=$COMMIT_TAG ..."
cp "$ENV_FILE" "$ENV_BAK"
ROLLBACK=true  # 备份完成后立即启用回滚，此后任何失败都会恢复旧配置

# 原子替换：生成新配置到临时文件，校验后 mv
sed '/^AURA_IMAGE_TAG=/d' "$ENV_BAK" > "$ENV_TMP"
echo "AURA_IMAGE_TAG=$COMMIT_TAG" >> "$ENV_TMP"
mv "$ENV_TMP" "$ENV_FILE"

export AURA_IMAGE_TAG="$COMMIT_TAG"
set -a; source "$ENV_FILE"; set +a
export AURA_IMAGE_TAG="$COMMIT_TAG"

echo "  AURA_IMAGE_TAG=$AURA_IMAGE_TAG"

# --- [4/5] 重启容器 ---
echo "==> [4/5] 重启全部容器..."
$COMPOSE up -d --no-build --no-deps frontend backend docs

# --- [5/5] 验证 ---
echo "==> [5/5] 验证服务..."
sleep 5

PASS=true

for svc in frontend backend docs postgres; do
  if docker ps --filter "name=aura-${svc}-" --format '{{.Names}}' | grep -q .; then
    echo "  ✅ aura-${svc}: Up"
  else
    echo "  ❌ aura-${svc}: NOT RUNNING"
    PASS=false
  fi
done

for svc in frontend backend docs; do
  IMG_NAME="aura-web"
  [ "$svc" = "backend" ] && IMG_NAME="aura-backend"
  [ "$svc" = "docs" ] && IMG_NAME="aura-docs"
  EXPECTED="ghcr.io/lingling1989r/${IMG_NAME}:${COMMIT_TAG}"
  ACTUAL=$(docker inspect "aura-${svc}-1" --format '{{.Config.Image}}' 2>/dev/null || echo "NOT_FOUND")
  if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✅ aura-${svc} image: $ACTUAL"
  else
    echo "  ❌ aura-${svc} image mismatch: expected $EXPECTED, got $ACTUAL"
    PASS=false
  fi
done

echo -n "  Backend  (/health):        "
curl -s --fail -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8080/health || PASS=false

echo -n "  Frontend (127.0.0.1:3000): "
curl -s --fail -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:3000 || PASS=false

echo -n "  Docs     (127.0.0.1:4000): "
curl -s --fail -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:4000/docs || PASS=false

echo -n "  域名  (https://aurababa.com): "
curl -s --fail -L -o /dev/null -w "HTTP %{http_code}\n" https://aurababa.com || PASS=false

echo ""
if [ "$PASS" = true ]; then
  ROLLBACK=false
  echo "✓ 部署完成 ($COMMIT_TAG)"
else
  echo "❌ 部署验证失败，开始回滚..."
  exit 1
fi
