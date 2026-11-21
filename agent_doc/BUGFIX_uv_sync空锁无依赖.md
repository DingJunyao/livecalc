# BUGFIX: uv sync 空锁、依赖不安装

## 现象

在 `backend/` 执行 `uv sync` 显示成功但什么都不装，`backend/.venv` 里没有 fastapi 等任何依赖；`uv sync --dry-run` 输出 `Resolved 1 package / Would make no changes`。工作区 `uv.lock` 出现 `revision 3→5`、`requires-python >=3.13→>=3.15` 的改动（uv 0.13.9 重写）。

## 根因

`backend/pyproject.toml` 是 Poetry 格式（`[tool.poetry.dependencies]` + poetry-core build backend），**uv 不读取这个表**（uv 只认 PEP 621 的 `[project]`）。uv 眼里项目无依赖，只锁了 `[dependency-groups]` 的 i18n 组 → uv.lock 从首次提交起就只有 babel 一个包。生产走 `requirements.txt`（Dockerfile pip 安装），仓库无 poetry.lock，Poetry 实际未完整使用，与 AGENTS.md「使用 uv 管理」脱节。

master 与 feat/mobile-app 的 `pyproject.toml` / `uv.lock` / `requirements.txt` 内容完全一致（仅行尾 CRLF/LF 差异），问题两分支同源。

## 修复

- `pyproject.toml` 迁移为 PEP 621：`[project]` 表（`requires-python = ">=3.11,<4.0"`），依赖逐条从 poetry 语义转 PEP 621 区间（`^0.138.0` → `>=0.138.0,<0.139.0` 等，与 requirements.txt 对齐）；poetry 的 `optional = true`（celery/redis）转 `[project.optional-dependencies]`；poetry dev 组转 `[dependency-groups] dev`（uv sync 默认装 dev）。
- 新增 `[tool.uv] package = false`：后端从源码跑 uvicorn，无需把项目构建为包（也避免 poetry-core 构建根包）；删除 `[build-system]`。
- 新增 `backend/.python-version`（`3.11`）：不固定的话 uv sync 会取本机默认解释器（当时 3.15.2），与 Docker `python:3.11-slim` 不一致；`.python-version` 同时约束 uv 与 pyenv。
- 删除重建 `backend/.venv`（旧的 3.15.2 venv 为空，无损失）。
- AGENTS.md 修正 venv 位置（原写「根目录下的 `.venv`」，实际不存在；为 `backend/.venv`）并补充 uv 用法。

## 验证

- `uv.lock` 131 包（原 1 包），`uv sync` 全量安装，venv 为 Python 3.11.18。
- 核心依赖全部导入 OK（fastapi 0.138.2 / sqlalchemy 2.1.9 / alembic 1.20.1 / langchain 1.5.2 / openai-codex / mcp / boto3 等）；`from app.main import app` 成功（47 路由）。

## 注意

- `uv sync` 默认装 dev 组；celery/redis 走 `uv sync --extra celery --extra redis`（生产 requirements.txt 中同样是注释状态）。
- 依赖区间变更时 requirements.txt 与 pyproject.toml 需同步维护（双轨）。
- 无数据库迁移、无前后端代码改动。
