# 合规运维指南（后端 / Web 管理端）

> 面向：**部署并运营本系统的人**（自建服务器管理员）。
> 依据：`app-store-compliance` 规则包 v2.5.3 + 本仓库实际配置项（2026-11-27 核对代码）。
> 相关文档：[STORE_SUBMISSION.md](STORE_SUBMISSION.md)（商店提审材料）、应用内隐私政策/用户协议（`mobile/assets/legal/`、`legal/*.html`）。

## 0. 先明确「谁负责」

本 App 是**自建服务器客户端**：数据存在你（管理员）部署的服务器上，**你**才是《个人信息保护法》意义上的个人信息处理者；App 开发者不接触这些数据（除非开发者同时运营公共实例）。

由此推出三条硬要求：

1. 你必须在自己的域名下**提供隐私政策与用户协议**（可直接托管仓库里的 `legal/*.html`），并在 App Store Connect / Play Console 填你自己的链接。
2. 应用内隐私政策写的是「服务器由你或你所在组织提供、保存期限由运营者决定」——你的实际做法必须与之相符（尤其备份保留期、日志保留期）。
3. 商店提审用的演示账号与演示服务器也由你提供，且**审核期全程在线**。

## 1. 上线前必配（缺一不可）

| 项 | 要求 | 检查方式 |
|---|---|---|
| HTTPS | 公网必须 HTTPS（客户端已收紧：iOS 不再允许任意明文，Android 发布版只放行 localhost/10.0.2.2） | `curl -I https://你的域名/api/v1/auth/config` |
| 反向代理 | Nginx/Caddy 终结 TLS，`X-Forwarded-For` 透传但要防伪造（只信任内网代理来源） | 检查 `proxy_set_header` |
| 域名与 ICP | 境内服务器需域名 ICP 备案；App 上架国区还需**工信部 App 备案**并填进 App Store Connect | 备案系统截图 |
| 数据库 | 默认 SQLite 仅适合小规模/单机；多人使用建议 PostgreSQL/MySQL，并开启定期备份 | 见 §4 |
| 静态图片 | `/api/v1/images/<key>` 为**公开重定向**（凭 key 访问），确认这是你要的开放程度（见 §3.4） | `curl -I` |
| 隐私政策 URL | 托管 `legal/privacy-policy.html`，与 App 内文案一致 | 浏览器打开 |
| 联系邮箱 | 隐私政策/用户协议里的邮箱必须是真实可达的（当前：dingjunyao0703@163.com） | 发一封测试信 |

## 1.5 数据库影响（无表结构变更）

本次合规相关改动**不新增/修改任何表结构**：

- 账号注销：只使用既有表（`users` / `recipes` / `merchants` / `meal_plans` / `product_records` / `favorites` / `agent_*` / `operation_logs` 等），按外键顺序清理。
- 合规信息（AI 模型/备案、地图审图号、法律文档正文）：存在既有 `system_config` 表的 `value`（Text，存 JSON），键为 `compliance_ai` / `compliance_map` / `legal_docs`。
- 因此**不需要新的 alembic 迁移**，也没有对应的建表/加列 SQL。

唯一的前置检查：`operation_logs` 表必须存在（迁移 `20260320_0001` 里定义）。旧库若因历史原因缺这张表，注销接口会报 `no such table: operation_logs`。三种补法任选其一：

1. **重启后端**（启动时 `Base.metadata.create_all` 会补建缺失表，最省事）；
2. `alembic upgrade head`；
3. 手工执行 `backend/scripts/sql/20261127_operation_logs_{sqlite,mysql,postgresql}.sql`（幂等）。

部署自检（只读，三种引擎通用写法按需调整）：

```sql
-- 注销会触碰的表必须齐全；缺哪张补哪张
SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema()
  AND table_name IN ('users','recipes','recipe_ingredients','recipe_cost_history',
                     'merchants','product_records','meal_plans','meal_plan_items',
                     'daily_recommendations','daily_recommendation_items',
                     'agent_sessions','agent_messages','agent_approvals',
                     'operation_logs','import_tasks','change_proposals',
                     'ingredient_merge_records','nutrition_edit_history',
                     'ai_ingredient_matches','image_tracking','system_config');
```

SQLite 用 `SELECT name FROM sqlite_master WHERE type='table' AND name IN (...)`；MySQL 把 `current_schema()` 换成 `DATABASE()`。

## 2. 管理端逐页合规对照

> 路径：Web 管理端 → 左侧「管理」分组。以下「风险」指**合规/安全**风险，不是功能缺陷。

### 2.1 系统设置 / 邀请码（AdminDashboard、InviteCodesView）

- `registration_require_invite_code`
  - 关闭 = 任何人可注册：必须配合**邮箱验证/风控**，否则会被批量注册刷 AI 配额。
  - 开启 = 审核人无法自行注册：**必须**在审核备注里给演示账号或邀请码。
  - **不建议**把邀请码公开发在社交平台（等同关闭限制）。
- 邀请码是「谁邀请谁」的证据链，泄露后可追溯；批量生成后请记录用途。

### 2.2 用户管理（UserManagementView）

- `is_admin`：只给必要的人；管理员可看全站数据（含他人价格/菜谱）。
- 停用（`is_active=false`）≠ 删除：停用只是禁止登录，**数据仍在**。用户要求删除时必须走「注销账号」（`POST /api/v1/auth/me/delete`）或管理员删除。
- 管理员离职/交接：及时降权并轮换 `SECRET_KEY`/`JWT_SECRET_KEY`（会强制所有人重新登录）。
- **不要**用后台直接改 `password_hash`（前端 SHA-256 在前，口径不一致会锁死账号）。

### 2.3 AI 配置（AiConfigView / `PUT /admin/translation-config`）

这是合规风险最集中的一页。

| 配置 | 合规影响 | 建议 |
|---|---|---|
| `ai.providers.*`（**Claude Code / Codex / OpenAI 兼容 API / Anthropic 兼容 API**） | `claude_code`、`codex` 直接驱动本机安装的对应工具（工具本身可再指向第三方模型）；`openai`、`anthropic` 是「兼容 API」入口，可指向任意兼容服务。国区对外提供服务需**已备案模型**，否则不得在国区提供 AI | 国区：只启用已备案模型，或在国区关闭 AI（App Compliance 选 No） |
| 各 provider 的 **模型名称 / 备案号 / 备注** | 需要在 App 内展示（国区要求标明模型与备案信息） | 在 **管理端 → 合规信息**（`/admin/compliance`）填写，App「关于」页与公开配置接口会展示；未填写时只显示展示名称 |
| `meal_plan.provider` | 决定推荐由谁生成 | 同上；同时确认该 provider 的**服务条款允许你的使用方式** |
| `ai_policy.default_method` | `system_ai` = 用户默认就把偏好发给第三方模型 | 首次使用必须有告知（移动端已规划弹窗）；对隐私敏感场景建议默认 `rule` |
| `ai_policy.allow_byok` | 用户密钥保存在你的服务器（Fernet 加密，密钥派生自 `JWT_SECRET_KEY`） | 开启即承担托管用户密钥的责任；轮换 `JWT_SECRET_KEY` 会导致密钥不可解密（用户需重填） |
| `ai_policy.allow_custom_base_url` | 用户可指定任意地址 → SSRF / 数据外泄风险 | **保持 false** |
| `ai_policy.daily_ai_limit` | 成本与滥用；审核账号需调高/取消 | 审核期临时放开，审核后回落 |
| `ai_policy.show_ai_badge` | **关闭会违反国区 AI 生成内容标识要求**（深度合成规定） | **保持 true**；如关闭，国区不得提供 AI |
| 翻译（machine providers：baidu/aliyun/deepl） | 若把用户内容送去翻译，等同第三方处理 | 只翻系统词条，不翻用户隐私内容；密钥按最小权限申请 |

> 另：`GET /admin/translation-config` 当前把 api_key 原文回显给管理员（前端可见）。请只把管理端给可信人员，并在网络层限制 `/admin/*`（见 §3.1）。

### 2.4 地图（MapSettingsView）

- `available_maps` / `default_map`：**高德、百度、腾讯、天地图均可合规使用**（天地图是国家地理信息公共服务平台，凭 key/token 使用）；OSM 等境外底图在中国境内不建议提供。
- `map_api_keys`：必须按**包名/iOS Bundle ID 或域名**做 Key 限制；`amap_security` 是安卓高德安全密钥，泄露可被别人盗刷配额。
- **审图号**：在 **管理端 → 合规信息** 为每个启用的底图填写审图号，App「关于」页会按已启用的底图自动带出展示（当前 App 没有独立「关于」以外的地图说明位）。
- 地理编码（`geocoding.*`）会把地址发给对应厂商：隐私政策已声明「商家坐标/地址」会用于地图展示。

### 2.5 图片存储（StorageConfigView、UnusedImagesView）

- `backend=local` 时图片由你的服务器直接对外提供；`s3` 时用对象存储。
- `s3_access_key/secret_key` 只给最小权限（读写指定 bucket，禁止列举全桶）。
- `s3_custom_domain` 若用 CDN，注意屏蔽目录列举。
- **公开访问**：`/api/v1/images/<key>` 靠 key 不可猜（uuid）来保护，**不等于鉴权**。图片属个人信息（头像、菜谱），建议：
  - 生产环境改成**签名 URL**（短期有效），或
  - 至少只对已登录用户开放 `/images/*`（当前是公开，改动在 `main.py` 的 images 路由）。
- **清理未使用图片（UnusedImagesView）**：先确认 `image_tracking` 没有误判（扫描后再删），删前做一次备份；该操作不可恢复。

### 2.6 邮件（EmailConfigView）

- SMTP 密码建议用**应用专用密码**，不要用主邮箱密码。
- `from_address` 建议与域名一致并配置 SPF/DKIM，否则验证邮件进垃圾箱会被用户判定为「注册失败」。
- 若开启邮件验证/找回密码：这些邮件属于「事务性通知」，可在隐私政策中说明；**不得**用该地址发营销邮件（未经同意的商业推送）。

### 2.7 条形码服务（BarcodeServicesView）

- 第三方条码库会收到 UPC/EAN（不含用户身份），但会关联你的 API Key；按服务商条款限制调用量。
- 若服务商要求「缓存条码结果」，注意缓存里不要带用户标识（当前 `barcode_lookup_cache` 是全局缓存，合规）。

### 2.8 数据维护 / 导入（DataMaintenanceView、RecipeImportView）

- USDA 数据导入、地区/单位种子、菜谱 URL 导入：涉及第三方内容版权，注意来源许可（项目 README 已注明 HowToCook/USDA）。
- 从 URL 导入菜谱会抓取外部页面：确认目标站点允许，避免版权/反爬争议。
- 导入脚本会写全站共享数据，**不要**在业务库上直接跑实验脚本。

### 2.9 Agent 控制台（AgentTaskConsole）

- 该功能可让 AI 生成并执行 SQL（需人工审批）。**只给可信管理员**，生产库建议只读账号或限制到维护窗口。
- 事件流用 `?token=<JWT>` 传参（浏览器 EventSource 限制），token 会进 **Nginx access log**。必须：access log 脱敏 query、缩短 token 有效期，或把该端点限制在内网。
- 审批记录（`agent_approvals`）保留 SQL 原文，注意其中可能含个人信息。

### 2.10 提案 / 黑名单组（ProposalsView、BlacklistGroupsView）

- 黑名单组若共享给多人，组内会暴露「谁屏蔽了什么」；不要把敏感偏好放进共享组名。
- 提案审核人信息（`reviewer_id`）在账号注销时置空（已实现），但审核历史本身会保留。

### 2.11 合规信息（ComplianceView，`/admin/compliance`）

集中填写「展示给用户的合规信息」，存 `system_config`（JSON），无需迁移：

- **AI 服务**：为四个提供方（Claude Code / Codex / OpenAI 兼容 API / Anthropic 兼容 API）填写展示名称、模型名称、备案号、备注。只有「已启用」的提供方才对用户展示。
- **地图服务**：为高德/百度/腾讯/天地图/OSM 填写展示名称、审图号、备注；只展示已启用的底图。
- **隐私政策 / 用户协议**：可直接在后台编辑中文/英文正文（Markdown），或清空以回退到随服务端分发的默认文案；同时填写联系邮箱。
- 保存后立即可用：
  - App「关于」页展示 AI/地图信息、联系邮箱、文档更新时间；
  - 公开接口 `GET /api/v1/app/config` 返回同样内容（App 启动读取，不含密钥）；
  - 公开页面 **`/legal/privacy`**、**`/legal/terms`**（HTML）直接作为商店的隐私政策/用户协议链接，建议用 API 域名（如 `https://api.example.com/legal/privacy`），不要填 Web 前端的 SPA 路由。

## 3. 高风险项「谨慎提供」清单

| 风险 | 为什么 | 怎么做 |
|---|---|---|
| 公网开放管理端 `/admin/*` 与 `/api/v1/agent/*` | 管理员可看全站数据、可跑 SQL | 仅内网/VPN 访问，或加 IP 白名单 + 独立 Basic Auth |
| 把 `SECRET_KEY`/`JWT_SECRET_KEY` 提交进仓库或写进镜像 | 泄露 = 可伪造任意用户 token、可解密用户 AI 密钥 | 用环境变量/密钥管理系统；轮换后所有人重登 |
| 明文 HTTP 暴露给用户 | 密码、token、个人数据可被中间人读取 | 强制 HTTPS，HTTP 301 到 HTTPS + HSTS |
| 日志打印请求体/响应体 | 邮箱、密码哈希、AI 密钥可能落盘 | 只记路径、状态码、耗时；脱敏 Authorization 与 query token |
| 无限制注册 + 无 AI 限额 | 被刷额度、被当免费代理 | 邀请码或邮箱验证 + `daily_ai_limit` + 反代限流 |
| 备份含个人信息且长期保留 | 超出「最小必要」保留期 | 设保留期（如 7/30 天）、加密备份、与隐私政策一致 |
| 图片公开可访问 | 头像/菜谱可被外链扩散 | 签名 URL 或登录鉴权；CDN 禁目录列举 |
| 面向未成年人开放 | 需监护人同意、青少年模式 | 年龄分级如实填写；不做面向未成年人的推荐推送 |
| 国区提供未备案 AI | 违反生成式 AI 管理办法 | 用已备案模型或国区关闭 AI（并在 App Compliance 选 No） |
| 使用未授权底图/缺审图号 | 违反测绘法与审图号要求（高德/百度/腾讯/天地图均需按其要求展示审图号） | 用官方底图或已授权瓦片，并在「合规信息」填写审图号 |

## 4. 运营期义务

1. **账号注销**：App 内已提供；管理员在后台手动删除用户时必须走同一套清理逻辑（`app/services/account_deletion.py`），不要直接 `DELETE FROM users`（会留下孤儿数据与未删图片）。
2. **数据导出**：`GET /api/v1/export/data` 已实现，向用户提供副本；导出文件不要长期留在服务器。
3. **备份与恢复**：备份加密、限制访问、定期演练恢复；数据库备份里的个人信息同样受保留期约束。
4. **日志保留**：建议 30–90 天，安全事件可延长；到期自动清理。
5. **安全事件**：发现泄露应在 72 小时内评估并按法律要求告知用户与监管；保留处置记录。
6. **变更管理**：隐私政策/协议有实质变化时，更新 `legal/*.html` 与应用内 `mobile/assets/legal/*.md`，并在 App 内重新征求同意（当前实现是注册时勾选，老用户可在个人中心查看）。

## 5. 国区专项

| 项 | 你要做的 |
|---|---|
| 工信部 App 备案 | 境内接入服务商提交；备案主体/名称/包名与商店一致；把备案号填进 App Store Connect |
| 域名 ICP | 境内服务器 + 域名实名；未备案域名无法在境内提供 Web API |
| 生成式 AI | 采购已备案模型服务（通义/豆包/DeepSeek/智谱等）并保留授权协议；在 Apple「App Compliance」按实际选 Yes/No |
| 地图 | 官方 SDK + 审图号展示 |
| 内容审核 | 用户图片与 AI 输出接入内容安全服务（阿里云/腾讯云/网易易盾），保留审核日志 |
| 敏感个人信息 | 位置属行踪轨迹：单独同意 + 说明必要性；不后台定位（当前已符合） |
| 数据出境 | 数据/备份不出境；用境外对象存储会触发出境义务 |

## 6. 只读自检（不修改数据）

```sql
-- 最近 7 天新增用户（异常注册量）
SELECT date(created_at) d, count(*) FROM users GROUP BY d ORDER BY d DESC LIMIT 7;

-- 是否有非管理员却持有管理员权限之外的高危数据（示例：看管理员名单）
SELECT id, username, email, created_at FROM users WHERE is_admin = true;

-- 邀请码使用情况（泄露/滥用排查）
SELECT code, used_by, used_at FROM invite_codes ORDER BY created_at DESC LIMIT 20;

-- AI 用量（配额与滥用）
SELECT date(created_at) d, method, provider, count(*) FROM ai_usage_events GROUP BY d, method, provider ORDER BY d DESC LIMIT 20;

-- 未使用图片（清理前先核对）
SELECT count(*), sum(file_size) FROM image_tracking WHERE key NOT IN (
  SELECT json_each.value FROM recipes, json_each(recipes.images)
) AND key NOT IN (SELECT avatar FROM users WHERE avatar IS NOT NULL);
```

（PostgreSQL 下把 `json_each` 改为 `json_array_elements_text(recipes.images::json)`。）

## 7. 交给开发者/提审的信息（管理员输出）

- [ ] 演示服务器地址（HTTPS）+ 演示账号/密码（审核期有效）
- [ ] 是否关闭邀请码；AI 每日限额是否放开
- [ ] 你的隐私政策 URL、用户协议 URL、支持 URL、联系邮箱
- [ ] Data safety / 隐私标签口径：**你运营公共实例吗？** 是 → 按实际收集申报；否（纯自建）→ 开发者侧可填「不收集」
- [ ] App 备案号（国区）、AI 备案号（国区提供 AI 时）、地图审图号
- [ ] 备份保留期、日志保留期（要与隐私政策一致）

## 8. 移动端配合项（当前状态）

已符合：
- 注册必须勾选同意隐私政策/用户协议；个人中心可随时查看两份文档。
- 账号注销入口 + 密码确认 + 清本地凭据与离线队列；旧服务端（404）会提示升级。
- 公网强制 HTTPS（iOS ATS / Android network security config）。
- **法律文档服务端优先**：读取 `GET /api/v1/legal/{doc}`（管理员在后台编辑的版本），服务器不可用时回退到随包分发的默认文案。
- **「关于」页**（个人中心 → 关于）：版本、服务器地址、联系方式、AI 服务（展示名称/模型/备案号/备注）、地图服务（展示名称/审图号/备注）、法律文档入口与更新时间。
- **AI 首次使用告知**：首次出现 AI 来源的推荐时弹一次性说明（会把偏好/营养目标/菜谱名发送到服务器配置的模型服务），可跳转「关于」查看具体模型与备案信息。服务器未启用 AI 时不会出现。

仍需注意：
1. **AI 开关联动**：管理员关闭 AI（`default_method=rule` 或禁用 provider）时，公共配置里的 `ai.enabled` 为 false、「关于」页显示「未启用」；推荐卡上的 AI 标识由服务端返回的 `source` 决定，管理员不要手工伪造该字段。
2. **国区文案**：App 内不出现境外 AI 服务名。展示名来自管理员在「合规信息」里填的 `display_name`，国区请填中文/中性名称（如「AI 助手」），不要直接写 OpenAI/Claude。
3. **地图审图号缺失时**：App 仍展示底图名称但不显示审图号——国区上架前务必在「合规信息」补全。
4. **服务端需为最新版本**：`/api/v1/app/config`、`/api/v1/legal/*`、`/legal/*` 与注销端点都在本版本新增，旧服务端下 App 会走回退逻辑（内置文案、无 AI 告知、注销提示升级）。
