import { createVuetify } from 'vuetify'

export const vuetify = createVuetify({
  theme: {
    defaultTheme: 'writersBeWriting',
    themes: {
      writersBeWriting: {
        dark: false,
        colors: {
          primary: '#1565c0',
          secondary: '#9b5c42',
          background: '#f7f4ef',
          surface: '#ffffff',
          error: '#b3261e',
          success: '#2e7d32',
          warning: '#a3620c',
          neutral: '#616161',
        },
      },
      writersBeWritingDark: {
        dark: true,
        colors: {
          primary: '#42a5f5',
          secondary: '#d19a80',
          background: '#121212',
          surface: '#1e1e1e',
          error: '#e57373',
          success: '#66bb6a',
          warning: '#e0a339',
          neutral: '#9e9e9e',
        },
      },
    },
  },
  defaults: {
    VBtn: { rounded: 'lg' },
    VCard: { rounded: 'lg', elevation: 0 },
  },
})
