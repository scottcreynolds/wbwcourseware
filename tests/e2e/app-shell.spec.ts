import { expect, test } from '@playwright/test'

test('opens the sign-in flow from the public home page', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Courseware', level: 1 })).toBeVisible()
  await page.getByRole('link', { name: 'Sign in' }).first().click()
  await expect(page.getByRole('heading', { name: 'Sign in', level: 1 })).toBeVisible()
})
