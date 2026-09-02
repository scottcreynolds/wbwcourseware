import type { AppRole } from '@/types/auth'

export function canAccessRole(userRole: AppRole, requiredRole?: AppRole): boolean {
  return requiredRole === undefined || userRole === requiredRole
}

export function homeForRole(role: AppRole): string {
  return role === 'teacher' ? '/teacher' : '/student'
}

