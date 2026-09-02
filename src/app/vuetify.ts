import { createVuetify } from 'vuetify'

export const vuetify = createVuetify({
  theme: {
    defaultTheme: 'writersBeWriting',
    themes: {
      writersBeWriting: {
        dark: false,
        colors: {
          primary: '#4f355f',
          secondary: '#9b5c42',
          background: '#f7f4ef',
          surface: '#ffffff',
          error: '#b3261e',
        },
      },
    },
  },
  defaults: {
    VBtn: { rounded: 'lg' },
    VCard: { rounded: 'lg', elevation: 0 },
  },
})
