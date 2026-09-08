import { expect, test } from '@playwright/test'

const teacherEmail = process.env.E2E_TEACHER_EMAIL
const teacherPassword = process.env.E2E_TEACHER_PASSWORD

test('teacher and student complete the local-staging course journey', async ({ page, browser }) => {
  test.setTimeout(90_000)
  test.skip(!teacherEmail || !teacherPassword, 'Local-staging teacher credentials are required')

  await page.goto('/login')
  await page.getByLabel('Email').fill(teacherEmail!)
  await page.getByLabel('Password').fill(teacherPassword!)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('heading', { name: 'Teacher dashboard' })).toBeVisible()

  const suffix = Date.now()
  await page.getByRole('button', { name: 'Create course' }).click()
  await page.getByLabel('Course title').fill(`Deployment course ${suffix}`)
  await page.getByRole('button', { name: 'Create', exact: true }).click()
  await expect(page.getByText('Course details')).toBeVisible()

  await page.getByRole('button', { name: 'Import outline' }).click()
  await expect(page.getByLabel('Module title')).toHaveValue('Foundations')
  await page.getByRole('button', { name: 'Import', exact: true }).click()
  await expect(page.getByText('Course outline imported.')).toBeVisible()
  await expect(page.getByText('Foundations', { exact: true })).toBeVisible()

  await page.getByText('Foundations', { exact: true }).click()
  await page.getByRole('link', { name: 'Scene Analysis' }).click()
  const itemStatus = page.getByRole('combobox', { name: 'Status' })
  await page.locator('.v-select').nth(1).click()
  await page.getByRole('option', { name: 'published', exact: true }).click()
  await expect(itemStatus).toHaveValue('published')
  await page.getByLabel('Markdown and sanitized HTML').fill('# Submit your scene analysis')
  await page.getByRole('button', { name: 'Save', exact: true }).click()
  await expect(page.getByText('Curriculum item saved.')).toBeVisible()
  await page.getByRole('link', { name: 'Back to course' }).click()

  const courseStatus = page.getByRole('combobox', { name: 'Status' })
  await page.locator('.v-select').nth(3).click()
  await page.getByRole('option', { name: 'active', exact: true }).click()
  await expect(courseStatus).toHaveValue('active')
  await page.getByRole('button', { name: 'Save course' }).click()
  await expect(page.getByText('Course details saved.')).toBeVisible()

  await page.getByRole('tab', { name: 'Release & due dates' }).click()
  await page.getByRole('button', { name: 'Release now' }).click()
  await expect(page.getByText('Module release updated.')).toBeVisible()

  await page.getByRole('tab', { name: 'Students' }).click()
  const studentEmail = `student-${suffix}@local.test`
  const studentPassword = 'LocalStudentPass123!'
  await page.getByLabel('Student email').fill(studentEmail)
  await page.getByRole('button', { name: 'Send invite' }).click()
  await expect(page.getByText('Local invite link:')).toBeVisible()
  await expect(page.getByText(studentEmail, { exact: true })).toBeVisible()
  const invitationUrl = await page.getByText(/http:\/\/127\.0\.0\.1:4173\/accept-invite/).getAttribute('href')
  expect(invitationUrl).toBeTruthy()

  const studentContext = await browser.newContext()
  const studentPage = await studentContext.newPage()
  await studentPage.goto(invitationUrl!)
  await studentPage.getByLabel('Name').fill('Local Student')
  await studentPage.getByLabel('Password', { exact: true }).fill(studentPassword)
  await studentPage.getByLabel('Confirm password').fill(studentPassword)
  await studentPage.getByRole('button', { name: 'Accept invitation' }).click()
  await expect(studentPage.getByText('Invitation accepted.')).toBeVisible()
  await studentPage.getByRole('link', { name: 'Continue to sign in' }).click()
  await studentPage.getByLabel('Email').fill(studentEmail)
  await studentPage.getByLabel('Password', { exact: true }).fill(studentPassword)
  await studentPage.getByRole('button', { name: 'Sign in' }).click()
  await expect(studentPage.getByRole('heading', { name: 'My courses' })).toBeVisible()
  await studentPage.getByText(`Deployment course ${suffix}`, { exact: true }).click()
  await expect(studentPage.getByText('Scene Analysis', { exact: true })).toBeVisible()
  await studentPage.getByText('Scene Analysis', { exact: true }).click()
  await expect(studentPage.getByText('Submit your scene analysis')).toBeVisible()
  await studentPage.locator('input[type="file"]').setInputFiles({
    name: 'scene-analysis.pdf',
    mimeType: 'application/pdf',
    buffer: Buffer.from('%PDF-1.4\n%%EOF'),
  })
  await studentPage.getByRole('button', { name: 'Submit files' }).click()
  await expect(studentPage.getByText('Submission version added.')).toBeVisible()
  await studentPage.getByText(/Local Student · 1 version/).click()
  await expect(studentPage.getByText('Version 1')).toBeVisible()

  await page.goto('/login')
  await page.getByLabel('Email').fill(teacherEmail!)
  await page.getByLabel('Password').fill(teacherPassword!)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('heading', { name: 'Teacher dashboard' })).toBeVisible()
  await page.getByText(`Deployment course ${suffix}`, { exact: true }).click()
  await expect(page.getByText(studentEmail, { exact: true })).toBeVisible()
  const announcements = page.getByRole('region', { name: 'Announcements' })
  await page.getByRole('tab', { name: 'Announcements' }).click()
  await announcements.getByLabel('Title', { exact: true }).fill(`Local announcement ${suffix}`)
  await announcements.getByLabel('Message (Markdown)').fill('Local delivery check')
  await announcements.getByRole('button', { name: 'Publish now' }).click()
  await expect(page.getByText('Announcement published.')).toBeVisible()

  await studentPage.getByRole('link', { name: 'Course modules' }).click()
  await expect(studentPage.getByText(`Local announcement ${suffix}`, { exact: true })).toBeVisible()
  await studentPage.getByLabel('Topic title').fill(`Workshop topic ${suffix}`)
  await studentPage.getByLabel('Message (Markdown)').fill('Student discussion message')
  await studentPage.getByRole('button', { name: 'Post topic' }).click()
  await expect(studentPage.getByText(`Workshop topic ${suffix}`, { exact: true })).toBeVisible()

  await page.getByRole('tab', { name: 'Release & due dates' }).click()
  await expect(page.getByText(/Local Student · 1 version/)).toBeVisible()

  await page.getByRole('tab', { name: 'Students' }).click()
  page.once('dialog', async (dialog) => dialog.accept())
  await page.getByRole('button', { name: 'Remove', exact: true }).click()
  await expect(page.getByText('Student removed.')).toBeVisible()
  await studentPage.getByRole('link', { name: 'My courses' }).click()
  await expect(studentPage.getByText('No courses yet')).toBeVisible()

  await studentContext.close()
})
