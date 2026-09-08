import AxeBuilder from '@axe-core/playwright'
import { expect, test } from '@playwright/test'

test('redirects the public home page straight to sign in', async ({ page }) => {
  await page.goto('/')
  await expect(page).toHaveURL(/\/login$/)
  await expect(page.getByRole('heading', { name: 'Sign in', level: 1 })).toBeVisible()
})

test('supports keyboard skip navigation', async ({ page }) => {
  await page.goto('/')
  await page.keyboard.press('Tab')

  const skipLink = page.getByRole('link', { name: 'Skip to main content' })
  await expect(skipLink).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(page.locator('#main-content')).toBeFocused()
})

test.describe('public accessibility smoke checks', () => {
  for (const route of ['/login', '/forgot-password', '/accept-invite']) {
    test(`${route} has no detectable WCAG A/AA violations`, async ({ page }) => {
      await page.goto(route)
      await expect(page.locator('h1')).toBeVisible()

      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
        .analyze()

      expect(results.violations).toEqual([])
    })

    test(`${route} has no detectable WCAG A/AA violations in dark mode`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: 'dark' })
      await page.goto(route)
      await expect(page.locator('h1')).toBeVisible()

      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
        .analyze()

      expect(results.violations).toEqual([])
    })
  }
})

test('theme preference toggles, persists across reload, and can switch back', async ({ page }) => {
  await page.goto('/login')
  const themeButton = page.getByRole('button', { name: 'Choose color theme' })

  await themeButton.click()
  await page.getByRole('listitem').filter({ hasText: 'Dark' }).click()
  await expect
    .poll(() => page.evaluate(() => document.querySelector('.v-application')?.className))
    .toContain('v-theme--writersBeWritingDark')
  await expect.poll(() => page.evaluate(() => localStorage.getItem('theme-preference'))).toBe('dark')

  await page.reload()
  await expect
    .poll(() => page.evaluate(() => document.querySelector('.v-application')?.className))
    .toContain('v-theme--writersBeWritingDark')

  await themeButton.click()
  await page.getByRole('listitem').filter({ hasText: 'Light' }).click()
  await expect
    .poll(() => page.evaluate(() => document.querySelector('.v-application')?.className))
    .toContain('v-theme--writersBeWriting')
  await expect
    .poll(() => page.evaluate(() => document.querySelector('.v-application')?.className))
    .not.toContain('v-theme--writersBeWritingDark')
})

test('primary public page reflows at a 400% equivalent viewport', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Sign in', level: 1 })).toBeVisible()

  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }))
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth)
})
