# 多币种与地区化计算——后续需处理事项

> 本文记录本特性的后续待办，随分支保留。2026-08-24 整理。

## 分支状态（整理后）

- `feat/multi-currency`：web 前端 + 后端（含 gap 修复、代码审查修复、本笔记）
- `feat/multi-currency-mobile`：web 前端 + 后端 + 移动端 + 设计文档 + 本笔记
- `master` / `feat/mobile-app`：新功能添加前的状态（供独立 bug 修复）

## 待办

### 1. 代码审查 Minor 项（后端+Web，未修）
- `price_region.py` 子树前缀匹配用 `path LIKE '{path}%'` 偏宽松（建议 `path = :p OR path LIKE :p || '/%'`）
- `apply_region_filter` 每次 2 条查询，成本趋势/sparkline 场景有 N+1（建议每请求解析一次子树集合复用）
- `exchange_rates.py` status 硬编码基准 `"EUR"`，应改用 `settings.exchange_rate_base_currency`
- 重算脚本 `recompute_user_currency.py` 复制了 `exchange_rate_service.convert`（建议复用）；`base="EUR"` 是死变量
- `exchange_rate_scheduler.py` 拉取失败 `except: pass` 无日志（建议 `logger.warning`）
- `RegionSelect.vue` 不从不为空的 `modelValue` 回显祖先链；地图反查后级联仍空白，用户再操作可能重置 region_id
- 前端无 vitest/vue-tsc 测试（计划里 Task1/2 的 spec 未交付；新增代码大量 `any`）
- `products.py` update 只改 `recorded_at` 时不重算汇率快照（与 create 语义不一致）
- `config.py` 历史提交含行尾噪声（审查时用 `--ignore-space-at-eol`）

### 2. 移动端代码审查
- `feat/multi-currency-mobile` 的移动端部分尚未做正式代码审查（本次只审了后端+Web）

### 3. 分支合并（未做）
- `feat/multi-currency` → merge 到 `master`
- `feat/multi-currency-mobile` → merge 到 `master`（建议移动端审查后再合）
- 设计文档（spec + 三份计划）随 `feat/multi-currency-mobile` 保留；master 上是否携带文档另行决定

### 4. 既有问题（与本次无关）
- 后端宽范围测试 18 个既有失败：storage(S3)/export/translate(缺 key)/downloader(USDA 网络)，非本次引入
- `tests/test_shared_data.py::test_dispatch_ingredient_merge_non_admin_submits_proposal` 既有失败（合并提议消息格式与测试预期不符）
- `mobile/pubspec.lock` 存在本地 pub 镜像改动，未提交（被 stash/还原多次）
- `master` 被检出在 `D:\code\live_calc-master` 工作区（可写根之外），合并需提权或人工处理

### 5. 环境说明
- 子代理无法提交（沙箱 `.git` 只读），提交由控制者提权完成
- Web 无 vitest/vue-tsc → 验证用 `vite build`
- 移动端 `flutter` 命令卡网络 → 验证用直接 `dart.exe analyze`