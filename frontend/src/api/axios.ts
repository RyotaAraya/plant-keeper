import axios from 'axios'

const api = axios.create({
  baseURL: 'http://localhost:3000/api/v1',
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use((response) => {
  const token = response.headers['authorization']
  if (token) {
    localStorage.setItem('jwt', token.replace('Bearer ', ''))
  }
  return response
})

export default api
