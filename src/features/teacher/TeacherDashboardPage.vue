<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { courseService } from '@/features/courses/courseService'
import type { Course } from '@/types/course'

const router = useRouter()
const courses = ref<Course[]>([])
const loading = ref(true)
const creating = ref(false)
const createDialog = ref(false)
const title = ref('')
const errorMessage = ref<string | null>(null)

async function load(): Promise<void> {
  loading.value = true
  errorMessage.value = null
  try {
    courses.value = await courseService.listCourses()
  } catch {
    errorMessage.value = 'Courses could not be loaded.'
  } finally {
    loading.value = false
  }
}

async function createCourse(): Promise<void> {
  if (!title.value.trim()) return
  creating.value = true
  try {
    const course = await courseService.createCourse(title.value)
    createDialog.value = false
    title.value = ''
    await router.push(`/teacher/courses/${course.id}`)
  } catch {
    errorMessage.value = 'Course could not be created.'
  } finally {
    creating.value = false
  }
}

onMounted(load)
</script>

<template>
  <v-alert v-if="errorMessage" type="error" class="mb-4" role="alert">{{ errorMessage }}</v-alert>
  <div class="section-heading">
    <p>Build reusable curriculum, then create teaching cohorts from it.</p>
    <v-btn color="primary" @click="createDialog = true">Create course</v-btn>
  </div>
  <v-skeleton-loader v-if="loading" type="list-item-two-line@3" />
  <v-empty-state v-else-if="courses.length === 0" headline="No courses yet" text="Create a course, then scaffold modules and pages from one outline." />
  <v-row v-else>
    <v-col v-for="course in courses" :key="course.id" cols="12" md="6">
      <v-card border :to="`/teacher/courses/${course.id}`">
        <v-card-title>{{ course.title }}</v-card-title>
        <v-card-subtitle>{{ course.status }}</v-card-subtitle>
        <v-card-text>{{ course.description || 'No description yet.' }}</v-card-text>
      </v-card>
    </v-col>
  </v-row>
  <v-dialog v-model="createDialog" max-width="32rem">
    <v-card title="Create course">
      <v-card-text><v-text-field v-model="title" label="Course title" autofocus @keyup.enter="createCourse" /></v-card-text>
      <v-card-actions><v-spacer /><v-btn @click="createDialog = false">Cancel</v-btn><v-btn color="primary" :loading="creating" :disabled="!title.trim()" @click="createCourse">Create</v-btn></v-card-actions>
    </v-card>
  </v-dialog>
</template>
