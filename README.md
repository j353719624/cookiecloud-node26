# cookiecloud-node26

用 **Node 26** 重建的 [CookieCloud](https://github.com/easychen/CookieCloud) Docker 镜像。

## 为什么有这个仓库

上游 `easychen/cookiecloud:latest` **停留在 2023-01-20**,之后没有再发过新镜像(见下表)。
它的基础镜像是 `node:16-alpine`,而 **Node 16 已于 2023-09 EOL**,不再接收安全更新。

本仓库不改动应用逻辑,只把运行环境升级到当前维护中的 Node,并补上原镜像缺失的两件事
(数据持久化、健康检查)。

| | 上游镜像 | 本仓库 |
|---|---|---|
| 基础镜像 | `node:16-alpine` | `node:26-alpine` |
| Node 版本 | v16.18.1(2022-11) | v26.10.0 |
| 依赖 | 2023 年的 npm 树 | 按 `package.json` 重新解析安装 |
| 数据目录 | 写在容器内,**`docker rm` 即丢失** | 声明 `VOLUME`,可挂载到宿主机 |
| 健康检查 | 无 | 内置 `HEALTHCHECK` |
| 应用代码 | — | **与上游完全一致,未做任何修改** |

## 上游镜像的可用 tag(截至 2026-10)

```
latest              2023-01-20
2023.01.20.16.39    2023-01-20
2023.01.19.14.37    2023-01-19
2023.01.19.04.19    2023-01-19
```

即:没有更新版本可升,想要新 Node 只能自行重建。

## 构建

```bash
git clone https://github.com/j353719624/cookiecloud-node26.git
cd cookiecloud-node26
docker build -t cookiecloud:node26 .
```

依赖从 `registry.npmmirror.com` 拉取(仅构建时需要网络)。

## 运行

```bash
docker run -d --name cookiecloud \
  -p 8088:8088 \
  --restart always \
  -v /your/path/cookiecloud/data:/data/api/data \
  cookiecloud:node26
```

⚠️ **务必挂载 `/data/api/data`**。这是上游镜像的一个坑:数据写在容器内,
不挂载的话 `docker rm` 或重新 `docker run` 就丢了(你同步过的 cookie 都在里面)。

## 数据格式

```
/data/api/data/<uuid>.json
  {"encrypted": "<客户端加密后的 cookie 密文>"}
```

加密在客户端(浏览器扩展)完成,服务端只做存储与转发,不接触明文。
接口只有两个:

```
POST /update        {"encrypted": "...", "uuid": "..."}
GET  /get/:uuid
```

## 验证结果

在本机(fnOS, x86_64)实测:

- 数据兼容:切换后读取同一份 uuid,字节数与旧容器完全一致
- 读写往返:`/update` 返回 `{"action":"done"}`,`/get` 回读一致
- 边界:不存在的 uuid 返回 404(与上游行为一致)
- 压测:100 轮 1KB + 30 轮 300KB 写入读回,**0 失败**
- 内存:空闲 19 MiB;压测后升至 30 MiB,**GC 后回落到 19.5 MiB**(无泄漏特征)
- 运行 30 分钟:重启 0 次,日志仅 `Server start on http://localhost:8088`

短期表现全部通过。**长期稳定性(数周)未验证** —— Node 26 属 Current 分支而非 LTS,
若长期运行中遇到内存或兼容问题,可改用 `node:24-alpine`(LTS)重建,方法与本文档相同。

## 目录说明

```
Dockerfile            镜像定义(唯一改动点)
app/
  app.js              上游应用代码,未修改
  package.json        依赖清单,未修改
  package-lock.json   锁定版本,未修改
.dockerignore         排除 data/,避免把本地数据打进镜像
```

