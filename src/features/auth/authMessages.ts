const genericAuthError = 'We could not complete that request. Check your information and try again.'

export function toAuthMessage(error: unknown): string {
  if (!(error instanceof Error)) return genericAuthError

  const message = error.message.toLowerCase()
  if (message.includes('invalid login credentials')) return 'Email or password is incorrect.'
  if (message.includes('email not confirmed')) return 'Confirm your email before signing in.'
  if (message.includes('password should be')) return 'Password does not meet security requirements.'
  if (message.includes('same password')) return 'Choose a password you have not already used.'
  if (message.includes('expired') || message.includes('otp')) return 'This link is invalid or expired. Request a new one.'
  return genericAuthError
}

