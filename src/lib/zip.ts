export type ZipEntry = { path: string; content: string }

const LOCAL_FILE_HEADER_SIGNATURE = 0x04034b50
const CENTRAL_DIRECTORY_SIGNATURE = 0x02014b50
const END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054b50
const ZIP_VERSION = 20
const UTF8_FILENAME_FLAG = 0x0800
const STORED_METHOD = 0
const MAX_ENTRIES = 0xffff

const crcTable = (() => {
  const table = new Uint32Array(256)
  for (let index = 0; index < 256; index++) {
    let value = index
    for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
    table[index] = value >>> 0
  }
  return table
})()

export function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff
  for (const byte of bytes) crc = crcTable[(crc ^ byte) & 0xff]! ^ (crc >>> 8)
  return (crc ^ 0xffffffff) >>> 0
}

function toDosDateTime(date: Date): { time: number; date: number } {
  const year = Math.max(date.getFullYear(), 1980)
  return {
    time: (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2),
    date: ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate(),
  }
}

/**
 * Builds an uncompressed (STORE) zip archive. Markdown exports are small, so
 * skipping DEFLATE keeps this dependency-free without a meaningful size cost.
 * No ZIP64 support: callers must stay under 65,535 entries and 4 GiB.
 */
export function createZip(entries: ZipEntry[], modifiedAt = new Date()): Uint8Array {
  if (entries.length > MAX_ENTRIES) throw new Error('Too many files for a zip archive.')
  const encoder = new TextEncoder()
  const dos = toDosDateTime(modifiedAt)
  const localParts: Uint8Array[] = []
  const centralParts: Uint8Array[] = []
  let offset = 0

  for (const entry of entries) {
    const name = encoder.encode(entry.path)
    const data = encoder.encode(entry.content)
    const checksum = crc32(data)

    const local = new DataView(new ArrayBuffer(30))
    local.setUint32(0, LOCAL_FILE_HEADER_SIGNATURE, true)
    local.setUint16(4, ZIP_VERSION, true)
    local.setUint16(6, UTF8_FILENAME_FLAG, true)
    local.setUint16(8, STORED_METHOD, true)
    local.setUint16(10, dos.time, true)
    local.setUint16(12, dos.date, true)
    local.setUint32(14, checksum, true)
    local.setUint32(18, data.length, true)
    local.setUint32(22, data.length, true)
    local.setUint16(26, name.length, true)
    local.setUint16(28, 0, true)

    const central = new DataView(new ArrayBuffer(46))
    central.setUint32(0, CENTRAL_DIRECTORY_SIGNATURE, true)
    central.setUint16(4, ZIP_VERSION, true)
    central.setUint16(6, ZIP_VERSION, true)
    central.setUint16(8, UTF8_FILENAME_FLAG, true)
    central.setUint16(10, STORED_METHOD, true)
    central.setUint16(12, dos.time, true)
    central.setUint16(14, dos.date, true)
    central.setUint32(16, checksum, true)
    central.setUint32(20, data.length, true)
    central.setUint32(24, data.length, true)
    central.setUint16(28, name.length, true)
    central.setUint32(42, offset, true)

    const localHeader = new Uint8Array(local.buffer)
    localParts.push(localHeader, name, data)
    centralParts.push(new Uint8Array(central.buffer), name)
    offset += localHeader.length + name.length + data.length
  }

  const centralSize = centralParts.reduce((total, part) => total + part.length, 0)
  const end = new DataView(new ArrayBuffer(22))
  end.setUint32(0, END_OF_CENTRAL_DIRECTORY_SIGNATURE, true)
  end.setUint16(8, entries.length, true)
  end.setUint16(10, entries.length, true)
  end.setUint32(12, centralSize, true)
  end.setUint32(16, offset, true)

  const parts = [...localParts, ...centralParts, new Uint8Array(end.buffer)]
  const archive = new Uint8Array(offset + centralSize + 22)
  let cursor = 0
  for (const part of parts) {
    archive.set(part, cursor)
    cursor += part.length
  }
  return archive
}
