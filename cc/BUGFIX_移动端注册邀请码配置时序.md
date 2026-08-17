# BUGFIX_移动端注册邀请码配置时序

> 日期：2026-08-17
> 分支：feat/mobile-app（仅移动端）
> 背景：注册页打开时邀请码注册关闭，后台随后开启；移动端仍按旧配置提交且没有邀请码输入框。注册失败还会被路由守卫送回登录页，并显示“用户名或密码错误”。

## 问题

1. `authConfigProvider` 是常驻 `FutureProvider`，首次读取后一直复用旧值；离开注册页再回来也不会重新请求。
2. 注册流程开始时全局认证状态变为 `loading`，路由守卫把所有 `loading` 页面重定向到 splash；注册失败后落入 `/login`。
3. 注册失败复用登录错误映射，400/403 均显示“用户名或密码错误”，没有透出后端 `detail`。

## 修复

- [register_screen.dart](../mobile/lib/features/auth/screens/register_screen.dart)
  - 打开注册页立即刷新 `/auth/config`。
  - 注册页存活期间每 5 秒刷新一次配置；应用从后台恢复时也刷新。
  - 提交前强制刷新配置。若服务器刚开启邀请码而输入框尚不存在，直接拦截请求，显示邀请码输入框并提示“注册失败：服务器已开启邀请码注册，请填写邀请码”。
  - 若配置在提交前 GET 与注册 POST 之间变化，注册失败后再刷新一次，保证新要求的邀请码输入框立即出现。
  - 进入注册页清除旧登录错误，避免登录页错误残留到注册表单。
- [auth_provider.dart](../mobile/lib/features/auth/providers/auth_provider.dart)
  - `authConfigProvider` 改为 `autoDispose`，离开注册页后释放旧配置。
  - 注册失败使用独立错误映射，优先显示后端 `detail`，例如“注册失败：需要邀请码”。
- [app_router.dart](../mobile/lib/core/router/app_router.dart)
  - 登录/注册页处于 `loading` 时保持在当前表单；只有非认证页面的会话恢复仍进入 splash。

## 测试

- 注册失败显示后端原因，不再显示登录错误。
- 提交前配置从“无需邀请码”变为“需要邀请码”时不发送注册请求，输入框即时出现。
- 后端拒绝注册后停留在注册页，显示失败原因并刷新出邀请码输入框。
- 注册页停留期间配置轮询会更新邀请码输入框。
- 认证相关测试 22/22 通过。
- 完整 `flutter test` 365/365 通过。
- `flutter analyze --no-pub` 无问题。
