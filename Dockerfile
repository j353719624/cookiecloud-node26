# CookieCloud —— Node 26 重建
#
# 说明：上游 easychen/cookiecloud:latest 停留在 2023-01-20（node:16-alpine，Node 16 已 EOL），
# 无新镜像可升，故自行重建。应用代码 app.js 与上游完全一致，未做任何修改。
#
# 版本选择：Node 26 是 Current 分支（非 LTS）；Node 24 是当前 LTS。
# 本包按需统一到 26.10.0（与 OpenClaw 使用的版本一致）。
#
# 相对原镜像的改动：
#   1. node:16-alpine → node:26-alpine
#   2. 依赖按 package.json 重新安装（原镜像是 2023 年的 npm 树）
#   3. 数据目录可挂载（原镜像数据写在容器内，重建即丢）
#   4. 新增 HEALTHCHECK

FROM node:26-alpine

WORKDIR /data/api

COPY app/package.json app/package-lock.json* ./

RUN npm config set registry https://registry.npmmirror.com \
 && npm install --omit=dev --no-audit --no-fund \
 && npm cache clean --force

COPY app/app.js ./

RUN mkdir -p /data/api/data
VOLUME ["/data/api/data"]

ENV NODE_ENV=production
EXPOSE 8088

HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8088/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "/data/api/app.js"]
