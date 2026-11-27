// 后端公开页地址推导。
// VITE_API_URL 为绝对地址（如 https://api.example.com/api/v1）时据此推出后端根；
// 相对地址（默认 /api/v1）时按同域代理处理。
const apiBase = import.meta.env.VITE_API_URL || '/api/v1'

export const publicBase = apiBase.replace(/\/api\/v1\/?$/, '')

/** 后端直出的隐私政策 / 用户协议 HTML 页（可直接填入应用商店）。 */
export function legalPageUrl(doc: 'privacy' | 'terms', locale: string): string {
  const lang = locale.toLowerCase().startsWith('zh') ? 'zh' : 'en'
  return `${publicBase}/legal/${doc}?locale=${lang}`
}
