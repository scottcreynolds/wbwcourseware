export async function secretsMatch(provided: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder()
  const [providedHash, expectedHash] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(provided)),
    crypto.subtle.digest('SHA-256', encoder.encode(expected)),
  ])
  const a = new Uint8Array(providedHash)
  const b = new Uint8Array(expectedHash)
  return a.length === b.length && a.every((value, index) => value === b[index])
}
