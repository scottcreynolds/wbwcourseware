import { expect, test } from '@playwright/test'

test('navigates between role placeholders', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Courseware', level: 1 })).toBeVisible()
  await page.getByRole('link', { name: 'Teacher dashboard' }).click()
  await expect(page.getByRole('heading', { name: 'Teacher dashboard', level: 1 })).toBeVisible()
})
