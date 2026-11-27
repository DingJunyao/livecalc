# 上架合规与提交材料（App Store / Google Play / 中国区）

> 依据：`app-store-compliance` 技能规则包 v2.5.3（117 条带日期来源，最近校验 2026-11-26）+ 人工核查。
> 本文档记录**已完成的代码层修复**、**仍待办的事项**与**两份商店的材料清单**。
> 管理端/服务器侧怎么配才合规，见 [COMPLIANCE_ADMIN_GUIDE.md](COMPLIANCE_ADMIN_GUIDE.md)。
> 政策会变，提审前请再跑一次扫描：`bash ~/.copilot/hooks/app-store-compliance-guard.sh mobile`

## 0. 结论速览

- 代码层「不修必退」的三项已落地：账号注销、隐私政策/用户协议（应用内 + 同意勾选）、明文流量收敛。
- 仍会阻断提审的是**运营准备**：可用的演示服务器与演示账号、商店元数据/截图、隐私标签与 Data safety 的如实填写。
- 国区是**独立的市场准入层**：App 备案（工信部）+ 境内服务器/域名 ICP + AI 备案或国区关 AI + 地图合规，个人开发者可以办但需要周期。

## 1. 已完成的代码层修复

| 项 | 落点 | 说明 |
|---|---|---|
| 账号注销端点 | `backend/app/api/auth.py` `POST /api/v1/auth/me/delete` | 校验密码（前端 SHA-256 后传），最后一个管理员禁止自助注销 |
| 注销数据清理 | `backend/app/services/account_deletion.py` | 按外键顺序清理 30+ 张表；他人引用的公开菜谱/商家匿名化保留；删除头像与菜谱图片对象并清 `image_tracking` |
| 注销单测 | `backend/tests/test_account_deletion.py` | 3 例：全量删除 / 跨用户引用保留与匿名化 / 最后管理员保护（隔离内存库，不碰开发库） |
| 应用内注销入口 | 移动端个人中心 → 「注销账号」 | 密码确认对话框，失败提示密码错误/网络错误；成功后清 token、凭据、离线队列并回登录页 |
| 隐私政策 / 用户协议 | `mobile/assets/legal/*.md` + `/legal/:doc` 路由 | 中英双版，离线可读；注册页必须勾选同意才能提交；个人中心常驻入口 |
| 商店用公开页 | 后端直出 `/legal/privacy`、`/legal/terms`（管理员可在「管理端 → 合规信息」编辑正文）；仓库 `legal/*.html` 为离线备份 | 商店链接填 **API 域名**（如 `https://api.example.com/legal/privacy`），不要填 Web 前端的 SPA 路由 |
| iOS ATS 收敛 | `ios/Runner/Info.plist` | 删除 `NSAllowsArbitraryLoads`，仅保留 `NSAllowsLocalNetworking`（局域网/回环可明文，公网必须 HTTPS） |
| Android 明文收敛 | `android/app/src/main/res/xml/network_security_config.xml` | 发布版默认禁明文，仅 `localhost`/`10.0.2.2` 例外；调试版单独放开（`src/debug/...`），便于真机连局域网 |
| Android 备份 | `AndroidManifest.xml` | `allowBackup="false"`，避免 token/离线队列进系统备份 |
| 模型注册 | `backend/app/models/__init__.py` | 补注册 operation_log / import_task / change_proposal / ingredient_merge_record，空库 `create_all` 不再缺表 |

## 2. 提审前待办（按优先级）

### P0（缺了必被退回）

- [ ] **演示服务器 + 演示账号**：应用启动必须填服务器地址（自建模式）。审核备注给出可公网访问的 HTTPS 地址、账号密码；确认服务器在**整个审核期**在线。
- [ ] **关闭邀请码**（或给 reviewer 邀请码）：`registration_require_invite_code=false`。
- [ ] **AI 配额**：审核账号的 `daily_ai_limit` 调高或取消（默认 20 次/天），否则 reviewer 试不出 AI 推荐。
- [ ] **隐私政策 URL 上线**：后端 `/legal/privacy`、`/legal/terms` 可直接用（正文在「管理端 → 合规信息」编辑）；App Store Connect 与 Play Console 填 **API 域名**下的链接。
- [ ] **Play 账号删除网页**：同一站点提供「删除账号说明页」或直接把隐私政策页的「注销账号」章节作为删除请求 URL（Play 要求独立可访问的删除链接）。

### P1（高概率被问/被拒）

- [ ] **AI 首次使用告知**：移动端首次调用 AI 前弹出说明（模型提供方 + 传输字段：饮食偏好、菜谱上下文），对应 Apple 5.1.2。国区方案见 §4。
- [ ] **地图底图合规**：现有 `map_config_provider.dart` 直连高德/腾讯/OSM 瓦片，国区应改为官方 SDK 或已授权瓦片服务，并在「关于」页展示审图号。
- [ ] **用户图片访问控制**：`/api/v1/images/<key>` 为公开重定向，建议改签名 URL 或鉴权；境内还需接内容安全审核。
- [ ] **R8**：`build.gradle.kts` release 开 `isMinifyEnabled` / `isShrinkResources`（Play 2027-02 技术质量要求）。
- [ ] **年龄分级问卷**：App Store Connect 2026 版（含 13+/16+/18+ 与内容描述符；AI 生成内容计入）。
- [ ] **Data safety / 隐私标签**如实填写（口径见 §6）。

### P2

- [ ] Android 应用名 `生计` 做 `values-en` 等资源本地化。
- [ ] 邀请码/注册流程在审核备注里说明；若默认开放注册，注明可自行注册。
- [ ] iPad 截图（已声明支持 iPad）。

## 3. Apple App Store 材料清单（个人开发者）

- Apple Developer Program 个人账号（$99/年，实名与备案主体一致）。
- App Store Connect 应用信息：名称（≤30）、副标题（≤30）、关键词、描述、**支持 URL**、**隐私政策 URL**。
- 图标 1024×1024（不透明、无圆角）。
- 截图：iPhone 6.9"、6.5"（如适用）、**iPad 13"**，3–10 张，展示真实页面而非启动图。
- 2026 版年龄分级问卷 + 内容描述符。
- App Privacy（隐私标签）：按 §6 口径逐项填写。
- 出口合规：`ITSAppUsesNonExemptEncryption=false`（已声明，HTTPS 属豁免）。
- 审核备注：见 §5 模板。
- 国区额外：**App 备案号**、AI 声明与备案号（或国区关闭 AI 的说明）。

## 4. 中国区（App Store 国区 + 国内安卓商店）准入

> 国区是**独立于代码**的市场准入层；个人主体可以办，但服务器必须在境内。

| 项 | 要求 | 个人怎么办 |
|---|---|---|
| **App 备案（工信部）** | 2023-09-01 起强制；苹果国区要求填备案号，无备案号无法上架/会被下架。备案主体、App 名称、包名须与商店一致 | 身份证 + 手机号 + 邮箱，通过**境内接入服务商**（阿里云/腾讯云备案系统）提交；需境内服务器 |
| **ICP 备案（域名）** | 后端 API 用境内域名时必需 | 域名实名 + 境内服务器，约 10–20 工作日 |
| **生成式 AI** | 国区提供 AI 推荐即属生成式 AI/深度合成服务：需用**已备案大模型**（通义/豆包/DeepSeek/智谱等），在 Apple「App Compliance」选 **Yes** 填备案号 + 授权协议；否则必须**国区禁用 AI** 并选 **No** | 个人无法自行为模型备案 → 采购已备案服务并拿授权，或国区关 AI。注意 App 内**不要出现 ChatGPT/Claude/OpenAI 等外部服务名**（地区退回风险），国区文案需处理 |
| **App Compliance 两项声明** | *AI-Generated or Synthetic Content* 与 *Security Assessment*，2027-01-31 前必须完成并验证；不提供该功能也必须显式选 No | Account Holder/Admin 在 App Store Connect 填写 |
| **地图** | 需有测绘资质的服务商 + 审图号 | 用高德/腾讯/百度官方 SDK；不要直连瓦片或 OSM；「关于」页展示审图号 |
| **个人信息保护（PIPL）** | 中文隐私政策（收集清单、第三方 SDK 目录、权限用途、保存期限、注销渠道、投诉渠道、未成年人条款）；定位属敏感个人信息需**单独同意**；撤回同意；账号注销 | 隐私政策/协议已在应用内 + `legal/*.html`；注册同意勾选已加；定位/相册权限的「单独同意」弹窗仍待补 |
| **数据出境** | 服务器/对象存储在境外且处理境内个人信息 → 标准合同备案或安全评估 | 建议全部境内 |
| **内容安全** | 用户图片 + AI 输出需审核；AI 生成内容需标识 | 接阿里云内容安全/腾讯云 CMS/网易易盾；App 内已有 AI 标识 |
| **软著** | 国区 App Store 不强制；华为/小米/OPPO/vivo 等国内商店基本都要《计算机软件著作权登记证书》 | 个人可申请，约 30 工作日，可加急 |
| **版号** | 仅游戏需要 | 本应用不需要 |

## 5. 审核备注模板（可直接粘贴）

```text
App: 生计 (LiveCalc) — 价格记录 / 菜谱成本 / 营养分析工具

1) 服务器
本应用是自建服务器客户端：首次启动需填写服务器地址。审核请使用：
  服务器：https://<your-demo-host>
  账号：<reviewer-username>
  密码：<reviewer-password>
该服务器为审核期专用演示环境，全天可用；账号已关闭邀请码限制，AI 每日配额已取消。

2) 注册
演示账号已可用；如需自行注册，注册不要求邀请码（服务器设置 registration_require_invite_code=false）。

3) AI 功能（可选）
「今日推荐」可切换为规则生成（无需 AI）。若使用 AI，推荐结果带有 AI 标识；
AI 仅发送饮食偏好与菜谱上下文，不含账号标识；模型提供方在设置页可见。

4) 权限
相机：扫描商品条码；相册：上传菜谱/头像图片；定位：在地图显示当前位置。
均按需申请，拒绝后仍可使用主要功能。

5) 账号删除
路径：个人中心 → 注销账号（输入密码确认）。删除会移除账号与全部个人数据。
```

## 6. 隐私标签 / Data safety 口径建议

本应用为**自建服务器客户端**：数据发送到用户自己（或其组织）配置的服务器，开发者不运营该服务器、无法读取其中数据。按这一事实填写：

- **Apple**：App Privacy 选「Data Not Collected」（不跟踪、不收集到开发者侧）。但若你同时运营一个公共实例并掌握数据，则必须按实际收集申报（邮箱、姓名、照片、位置、用户内容、标识符），并在 `ios/Runner/PrivacyInfo.xcprivacy` 的 `NSPrivacyCollectedDataTypes` 中同步声明。
- **Google Play**：Data safety 同理；若运营公共实例，需申报「收集并传输（加密）」，并勾选「用户可请求删除数据」。
- 两者都必须提供**可用的隐私政策链接**和**账号删除入口**（App Store 5.1.1(v) / Play 账号删除政策）。

## 7. 常用命令

```bash
# 合规扫描（含规则包版本与到期项）
bash ~/.copilot/hooks/app-store-compliance-guard.sh mobile

# 后端注销测试（隔离内存库）
cd backend && .venv/bin/python -m pytest tests/test_account_deletion.py -q

# 移动端检查
cd mobile && flutter analyze
flutter test test/features/auth test/features/profile

# 出包
cd mobile && flutter build apk --release && flutter build appbundle --release
flutter build ipa --release      # 需先在 Xcode 配 Team
```
