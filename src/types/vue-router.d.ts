import type { AppRole } from '@/types/auth'

export {}

declare module 'vue-router' {
  interface RouteMeta {
    title?: string
    public?: boolean
    requiresAuth?: boolean
    requiredRole?: AppRole
  }
}
