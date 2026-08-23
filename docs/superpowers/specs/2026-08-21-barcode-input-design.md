# 条码快速输入与服务配置设计

## 背景

系统已有商品主条码字段和 `product_barcodes` 多条码表，但商品维护与价格记录仍依赖手工输入条码和商品名。本设计为 Web 端与移动端增加相机扫码、外部商品信息回填、价格记录扫码识别商品，以及后台条码服务配置能力。

## 目标

- 商品维护时可通过相机扫码输入条码。
- 扫码后可按后台配置调用外部商品 API，自动填入商品信息。
- 维护价格记录时可通过扫码识别商品；本地不存在时询问是否新增商品，确认后进入预填的新增商品流程。
- 后台管理提供条码服务配置页，支持多个服务并行启用并按优先级依次尝试。
- 内置支持 Open Food Facts、mxnzp、云际（云 API 市场）商品条码 API，并支持若干自定义商品 API。
- 外部查询结果落库缓存，减少重复调用与配额消耗。

## 非目标

- 不做外部商品库全量同步。
- 不改变商品多条码管理模型，也不将主条码迁移到多条码表。
- 不让 Web 或移动端直接持有第三方密钥。

## 总体方案

后端提供统一的条码解析入口。Web 与移动端只调用系统接口，所有外部 API 请求、鉴权、优先级回退和缓存均由后端完成。

查询顺序为：

1. 本地商品 `products.barcode` 主条码。
2. 活跃 `product_barcodes.barcode` 记录。
3. 未过期的 `barcode_lookup_cache` 外部结果缓存。
4. 按后台配置优先级串行调用启用的外部服务。

本地商品命中永远优先。外部服务返回有效名称即停止尝试；全部失败时返回 404，并附带脱敏错误摘要，方便管理员判断配置或配额问题。

## 后端接口与数据

### 条码查询接口

新增：

`GET /api/v1/products/entity/barcode/{barcode}`

返回统一结构：

```json
{
  "found": true,
  "source": "local|cache|openfoodfacts|mxnzp|yunji|custom:<id>",
  "product": {
    "id": 1,
    "barcode": "6900000000000",
    "name": "示例商品",
    "brand": "示例品牌",
    "spec": "500g",
    "manufacturer": "示例厂商",
    "image_url": "https://example.com/a.jpg"
  },
  "errors": []
}
```

本地命中时返回本地商品 ID 与现有展示字段；外部命中时 `product.id` 为空。规格、厂商等扩展信息仅用于表单预填，不改变现有商品表结构。

### 缓存表

新增 `barcode_lookup_cache` 表：

- `barcode`：唯一索引。
- `payload`：统一商品 JSON。
- `source`：来源服务。
- `fetched_at`：外部获取时间。
- `expires_at`：过期时间。

默认 TTL 为 7 天，可在后台配置，范围为 1 分钟到 365 天。外部成功结果写入缓存；配置变更后删除对应缓存。缓存不缓存认证失败等错误，只缓存成功结果。

数据库变更按项目约束提供 Alembic 迁移和 SQLite/MySQL/PostgreSQL/PostGIS SQL 脚本。

## 外部服务配置

配置持久化为 `system_config.key = barcode_service_config` 的 JSON 值，不新增配置表。

### 内置服务

| 服务 | 提供方 | 申请/文档链接 | 鉴权 |
| --- | --- | --- | --- |
| Open Food Facts | Open Food Facts | `https://world.openfoodfacts.org/` | 无 |
| mxnzp | mxnzp | `https://www.mxnzp.com/doc/detail?id=6` | `app_id` + `app_secret` |
| 云际商品条码查询 | 云际，通过云 API 市场交付 | `https://market.aliyun.com/detail/cmapi031448` | AppCode Header |

内置服务默认请求与响应映射固化在后端 provider 中：

- Open Food Facts 使用 `https://world.openfoodfacts.org/api/v2/product/{barcode}.json`。
- mxnzp 使用 `/api/barcode/goods/details?barcode={barcode}&app_id=...&app_secret=...`。
- 云际使用云 API 市场分配的 `barcode100.market.alicloudapi.com` 域名，请求 `GET /getBarcode?Code={barcode}`，并发送 `Authorization: APPCODE <AppCode>`。名称、品牌、规格、厂商、图片分别映射 `ItemName`、`BrandName`、`ItemSpecification`、`FirmName`、`Image[0].Imageurl`；`status != 200` 视为未命中。

云际在界面文案中称为“云际（云 API 市场）”，不简称为阿里云，避免把市场平台和 API 提供方混淆。

### 自定义服务

每个自定义服务可配置：

- 名称与启用状态。
- 服务说明或申请链接，仅用于后台展示。
- GET URL 模板，必须包含 `{barcode}`。
- 若干静态 Header，用于 API Key、Bearer Token 等。
- 名称、品牌、规格、厂商、图片 URL 的 JSONPath 映射。

URL 只允许 `http/https`，并禁止解析到内网地址。JSONPath 只用于读取响应字段，不执行表达式。名称映射缺失或取不到有效值时视为该服务未命中。

### 优先级与安全

- 服务列表顺序即优先级，后台支持上移/下移。
- 每个服务单独配置超时时间，默认 5 秒。
- 密钥仅保存在后端配置中；读取接口返回脱敏值，保存 `null` 或 `***` 表示沿用旧值。
- 测试接口使用指定样例条码按单个服务真实调用，返回脱敏错误与解析结果，不返回原始密钥。

## 后台管理页面

新增 `/admin/barcode-services`，挂到后台管理首页，并加入管理员可访问路由：

- 服务卡片显示提供方名称、启用状态、优先级、当前配置状态。
- 内置服务卡片显示“查看/申请 API”外链，分别指向上表链接；Open Food Facts 显示官方站点，mxnzp 显示接口文档与申请入口，云际显示云 API 市场商品页。
- 自定义服务卡片显示配置的服务说明链接。
- 提供启用开关、优先级上移/下移、超时时间、测试条码和测试按钮。
- 内置服务密钥字段脱敏展示，保存空占位值不覆盖旧密钥。
- 自定义服务支持新增、编辑、删除，删除仅需软确认，不需要后台二次验证。

Web 本地模式同步实现配置读写代理和 IndexedDB handler。本地模式下条码查询先查本地商品，未命中时按配置在浏览器直连启用的外部服务；请求受第三方端点 CORS 策略约束，测试按钮返回同样的浏览器直连结果。本地模式暂不维护外部结果缓存。

## Web 端行为

### 商品维护

- 新增/编辑商品对话框和商品详情基本信息表单的条码输入框旁增加扫码按钮。
- 扫码弹窗请求相机权限，支持 EAN-8/EAN-13/UPC-A/UPC-E/Code 128/Code 39/ITF 等常见一维码。
- 识别后关闭相机，将条码写入条码字段，并调用统一查询接口。
- 名称、品牌、规格、厂商、图片只填空字段，不覆盖用户已录入内容。
- 未识别或相机不可用时保留手工输入，不给用户制造阻断。

Web 扫码使用 `@zxing/browser`，封装为可复用扫码组件。

### 价格记录

- 价格记录表单与快速填写页提供扫码入口。
- 本地商品命中：直接选中该商品，并带入价格记录表单。
- 外部命中但本地不存在：弹窗展示外部商品信息，询问“是否新增商品”。确认后进入新增商品流程并预填条码与外部信息；保存后返回价格记录流程并选中新商品。
- 全部未命中：提示未找到商品，可选择仅带条码进入新增商品流程。
- 用户取消时不改变当前价格记录草稿。

## 移动端行为

- 商品新增/编辑表单和价格记录表单提供同样扫码入口、外部信息预填和新增商品询问流程。
- 扫码使用 `mobile_scanner`。
- Android 声明相机权限；iOS `Info.plist` 增加 `NSCameraUsageDescription`。
- 移动端只调用系统统一条码接口，不直接访问第三方 API。
- 扫码返回后保留用户已输入的价格草稿；新增商品完成后自动回选并继续录入。

## 分支与交付

后端、Web 前端、后台配置先提交到 `master`，再合并到 `feat/mobile-app`；移动端改动在合并后的移动分支完成。若远端 `master` 在实施前更新，以 `origin/master` 为基准同步后实施。

## 验证

- 后端：provider 请求与响应映射、优先级回退、缓存读写与过期、本地主条码/多条码兼容、权限、配置脱敏、自定义 URL 与 JSONPath 校验。
- Web：后台配置页、扫码组件、商品表单预填、价格记录新增商品流程；执行前端构建。
- 移动端：条码模型/仓库、扫码入口、表单预填、返回流程；执行 `flutter analyze` 与现有测试。
- 相机扫码在真实设备上保留人工验收项，自动化不模拟摄像头硬件。
