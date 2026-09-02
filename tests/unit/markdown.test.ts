import { describe, expect, it } from 'vitest'
import { renderMarkdown } from '@/lib/markdown'

describe('renderMarkdown', () => {
  it('renders Markdown and removes executable HTML', () => {
    const html = renderMarkdown('# Hello\n<script>alert(1)</script><img src=x onerror="alert(2)">')
    expect(html).toContain('<h1>Hello</h1>')
    expect(html).not.toContain('<script')
    expect(html).not.toContain('onerror')
  })

  it('allows approved video iframes and removes unknown hosts', () => {
    expect(renderMarkdown('<iframe src="https://www.youtube-nocookie.com/embed/abc"></iframe>')).toContain(
      'youtube-nocookie.com',
    )
    expect(renderMarkdown('<iframe src="https://evil.example/embed/abc"></iframe>')).not.toContain('<iframe')
  })
})

