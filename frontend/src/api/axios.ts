import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3000/api/v1',
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => {
    const authHeader = response.headers['authorization'] || response.headers['Authorization']
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '')
      localStorage.setItem('jwt', token)
    }
    return response
  },
  (error) => {
    // トークン付きのリクエストが401になったのは、有効期限切れ（24時間）か失効。
    // 入力を続けさせても保存に失敗するだけなので、ログイン画面に戻して理由を伝える。
    // ログイン自体の401（パスワード違い）は、ログイン画面が扱う
    // 同時に飛んでいた他のリクエストの401も同じ扱いにするため、「いまトークンがあるか」ではなく
    // 「そのリクエストがトークン付きで送られたか」で判定する
    const isLoginRequest = String(error.config?.url ?? '').endsWith('/login')
    const sentWithToken = !!error.config?.headers?.Authorization
    if (error.response?.status === 401 && !isLoginRequest && sentWithToken) {
      localStorage.removeItem('jwt')
      if (window.location.pathname !== '/login') window.location.assign('/login?expired=1')
      // 画面遷移で捨てられる呼び出し元や、ログアウト直後に（すでにログイン画面にいる状態で）返ってきた
      // 読み込み中だった取得が、エラー処理（未捕捉の例外や失敗表示）に入らないよう保留にする
      return new Promise(() => {})
    }
    return Promise.reject(error)
  },
)

export default api
