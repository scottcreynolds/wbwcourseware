import { ref, watch } from 'vue'
import { useTheme } from 'vuetify'

export type ThemePreference = 'system' | 'light' | 'dark'

const STORAGE_KEY = 'theme-preference'
const LIGHT_THEME = 'writersBeWriting'
const DARK_THEME = 'writersBeWritingDark'

function readStoredPreference(): ThemePreference {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored === 'light' || stored === 'dark' || stored === 'system') return stored
  } catch {
    // localStorage unavailable (private browsing, etc.) - fall back to system
  }
  return 'system'
}

const preference = ref<ThemePreference>(readStoredPreference())
let initialized = false

export function useThemePreference() {
  const theme = useTheme()
  const media = window.matchMedia('(prefers-color-scheme: dark)')

  function resolve(pref: ThemePreference): 'light' | 'dark' {
    if (pref === 'system') return media.matches ? 'dark' : 'light'
    return pref
  }

  function apply(): void {
    const mode = resolve(preference.value)
    theme.change(mode === 'dark' ? DARK_THEME : LIGHT_THEME)
    document.documentElement.style.colorScheme = mode
  }

  function setPreference(next: ThemePreference): void {
    preference.value = next
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch {
      // ignore write failures, preference still applies for this session
    }
  }

  if (!initialized) {
    initialized = true
    media.addEventListener('change', () => {
      if (preference.value === 'system') apply()
    })
    watch(preference, apply, { immediate: true })
  }

  return { preference, setPreference }
}
