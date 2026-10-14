import { describe, expect, it } from 'vitest'
import { crc32, createZip } from '@/lib/zip'

describe('crc32', () => {
  it('matches the standard check value', () => {
    expect(crc32(new TextEncoder().encode('123456789'))).toBe(0xcbf43926)
  })
})

describe('createZip', () => {
  it('writes local headers, central directory, and end record for each entry', () => {
    const archive = createZip([
      { path: 'course/README.md', content: '# Café\n' },
      { path: 'course/01-intro/README.md', content: '' },
    ])
    const view = new DataView(archive.buffer)
    expect(view.getUint32(0, true)).toBe(0x04034b50)
    expect(view.getUint16(6, true) & 0x0800).toBe(0x0800)

    const endOffset = archive.length - 22
    expect(view.getUint32(endOffset, true)).toBe(0x06054b50)
    expect(view.getUint16(endOffset + 10, true)).toBe(2)
    const centralOffset = view.getUint32(endOffset + 16, true)
    expect(view.getUint32(centralOffset, true)).toBe(0x02014b50)

    const nameLength = view.getUint16(26, true)
    const dataLength = view.getUint32(18, true)
    const data = archive.slice(30 + nameLength, 30 + nameLength + dataLength)
    expect(new TextDecoder().decode(data)).toBe('# Café\n')
    expect(view.getUint32(14, true)).toBe(crc32(data))
  })
})
