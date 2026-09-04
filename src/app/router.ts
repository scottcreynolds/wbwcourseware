import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { canAccessRole } from '@/features/auth/authRules'
import { useAuthStore } from '@/features/auth/authStore'

export const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'home',
    component: () => import('@/features/home/HomePage.vue'),
    meta: { title: 'Courseware' },
  },
  {
    path: '/login',
    name: 'login',
    component: () => import('@/features/auth/LoginPage.vue'),
    meta: { title: 'Sign in', public: true },
  },
  {
    path: '/forgot-password',
    name: 'forgot-password',
    component: () => import('@/features/auth/ForgotPasswordPage.vue'),
    meta: { title: 'Reset password', public: true },
  },
  {
    path: '/update-password',
    name: 'update-password',
    component: () => import('@/features/auth/UpdatePasswordPage.vue'),
    meta: { title: 'Choose new password', public: true },
  },
  {
    path: '/confirm-email',
    name: 'confirm-email',
    component: () => import('@/features/auth/ConfirmEmailPage.vue'),
    meta: { title: 'Confirm email', public: true },
  },
  {path:'/accept-invite',name:'accept-invite',component:()=>import('@/features/enrollment/AcceptInvitePage.vue'),meta:{title:'Accept invitation',public:true}},
  {
    path: '/access-denied',
    name: 'access-denied',
    component: () => import('@/features/auth/AccessDeniedPage.vue'),
    meta: { title: 'Access denied', public: true },
  },
  {
    path: '/teacher',
    name: 'teacher-dashboard',
    component: () => import('@/features/teacher/TeacherDashboardPage.vue'),
    meta: { title: 'Teacher dashboard', requiresAuth: true, requiredRole: 'teacher' },
  },
  {
    path: '/teacher/courses/:courseId',
    name: 'course-editor',
    component: () => import('@/features/courses/CourseEditorPage.vue'),
    meta: { title: 'Course editor', requiresAuth: true, requiredRole: 'teacher' },
  },
  {
    path: '/teacher/courses/:courseId/items/:itemId',
    name: 'item-editor',
    component: () => import('@/features/courses/ItemEditorPage.vue'),
    meta: { title: 'Curriculum editor', requiresAuth: true, requiredRole: 'teacher' },
  },
  { path:'/teacher/cohorts/:cohortId',name:'cohort-editor',component:()=>import('@/features/cohorts/CohortEditorPage.vue'),meta:{title:'Cohort dashboard',requiresAuth:true,requiredRole:'teacher'} },
  {
    path: '/student',
    name: 'student-dashboard',
    component: () => import('@/features/student/StudentDashboardPage.vue'),
    meta: { title: 'My courses', requiresAuth: true, requiredRole: 'student' },
  },
  {
    path: '/student/cohorts/:cohortId',
    name: 'student-cohort',
    component: () => import('@/features/learning/StudentCohortPage.vue'),
    meta: { title: 'Course materials', requiresAuth: true, requiredRole: 'student' },
  },
  {
    path: '/student/cohorts/:cohortId/items/:itemId',
    name: 'student-item',
    component: () => import('@/features/learning/StudentItemPage.vue'),
    meta: { title: 'Course page', requiresAuth: true, requiredRole: 'student' },
  },
  {
    path: '/student/cohorts/:cohortId/items/:itemId/print',
    name: 'student-item-print',
    component: () => import('@/features/learning/StudentItemPage.vue'),
    meta: {
      title: 'Printable course page',
      requiresAuth: true,
      requiredRole: 'student',
      printView: true,
    },
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'not-found',
    component: () => import('@/features/system/NotFoundPage.vue'),
    meta: { title: 'Page not found' },
  },
]

export const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return true

  const auth = useAuthStore()
  await auth.initialize()
  if (!auth.isAuthenticated || !auth.profile) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (!canAccessRole(auth.profile.role, to.meta.requiredRole)) return { name: 'access-denied' }
  return true
})

router.afterEach((to, from) => {
  document.title = `${String(to.meta.title ?? 'Courseware')} · Writers Be Writing`
  if (from.name) {
    requestAnimationFrame(() => document.querySelector<HTMLElement>('#main-content')?.focus())
  }
})
