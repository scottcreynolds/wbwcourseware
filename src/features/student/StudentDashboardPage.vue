<script setup lang="ts">
import {onMounted,ref} from 'vue'
import {enrollmentService} from '@/features/enrollment/enrollmentService'
import type {Course} from '@/types/course'
const courses=ref<Course[]>([]),loading=ref(true),errorMessage=ref<string|null>(null)
onMounted(async()=>{try{courses.value=await enrollmentService.studentCourses()}catch{errorMessage.value='Your courses could not be loaded.'}finally{loading.value=false}})
</script>
<template><v-alert v-if="errorMessage" type="error">{{ errorMessage }}</v-alert><v-skeleton-loader v-else-if="loading" type="list-item-two-line@3" /><v-empty-state v-else-if="!courses.length" headline="No courses yet" text="Courses appear after you accept an invitation." /><v-row v-else><v-col v-for="course in courses" :key="course.id" cols="12" md="6"><v-card border :to="`/student/courses/${course.id}`"><v-card-title>{{ course.title }}</v-card-title><v-card-subtitle>{{ course.start_date }}–{{ course.end_date }}</v-card-subtitle><v-card-text>Open course materials and assignments.</v-card-text></v-card></v-col></v-row></template>
