<script setup lang="ts">
import {onMounted,ref} from 'vue'
import {enrollmentService} from '@/features/enrollment/enrollmentService'
import type {Cohort} from '@/types/cohort'
const cohorts=ref<Cohort[]>([]),loading=ref(true),errorMessage=ref<string|null>(null)
onMounted(async()=>{try{cohorts.value=await enrollmentService.studentCohorts()}catch{errorMessage.value='Your cohorts could not be loaded.'}finally{loading.value=false}})
</script>
<template><v-alert v-if="errorMessage" type="error">{{ errorMessage }}</v-alert><v-skeleton-loader v-else-if="loading" type="list-item-two-line@3" /><v-empty-state v-else-if="!cohorts.length" headline="No cohorts yet" text="Cohorts appear after you accept an invitation." /><v-row v-else><v-col v-for="cohort in cohorts" :key="cohort.id" cols="12" md="6"><v-card border :to="`/student/cohorts/${cohort.id}`"><v-card-title>{{ cohort.title }}</v-card-title><v-card-subtitle>{{ cohort.start_date }}–{{ cohort.end_date }}</v-card-subtitle><v-card-text>Open course materials and assignments.</v-card-text></v-card></v-col></v-row></template>
