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

  it('opens links in a new tab only when requested, leaving in-page anchors alone', () => {
    const source = '[site](https://example.com) [jump](#notes)'
    const linkTargets = (html: string) =>
      [...new DOMParser().parseFromString(html, 'text/html').querySelectorAll('a')].map((link) => ({
        target: link.getAttribute('target'),
        rel: link.getAttribute('rel'),
      }))

    expect(linkTargets(renderMarkdown(source))).toEqual([
      { target: null, rel: 'noopener noreferrer' },
      { target: null, rel: 'noopener noreferrer' },
    ])
    expect(linkTargets(renderMarkdown(source, { openLinksInNewTab: true }))).toEqual([
      { target: '_blank', rel: 'noopener noreferrer' },
      { target: null, rel: 'noopener noreferrer' },
    ])
  })

  it('does not let authored target attributes survive sanitization', () => {
    expect(renderMarkdown('<a href="https://example.com" target="_blank">x</a>')).not.toContain('target=')
  })
})

