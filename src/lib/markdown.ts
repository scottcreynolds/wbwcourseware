import DOMPurify from 'dompurify'
import MarkdownIt from 'markdown-it'

const markdown = new MarkdownIt({ html: true, linkify: true, typographer: true })
const iframeHosts = new Set(['www.youtube.com', 'www.youtube-nocookie.com', 'player.vimeo.com'])

export function renderMarkdown(source: string): string {
  const rendered = markdown.render(source)
  const sanitized = DOMPurify.sanitize(rendered, {
    ADD_TAGS: ['iframe'],
    ADD_ATTR: [
      'allow',
      'allowfullscreen',
      'class',
      'height',
      'loading',
      'referrerpolicy',
      'sandbox',
      'style',
      'title',
      'width',
    ],
    FORBID_TAGS: ['form', 'input', 'button', 'object', 'embed', 'meta', 'base'],
  })

  const document = new DOMParser().parseFromString(sanitized, 'text/html')
  document.querySelectorAll('iframe').forEach((iframe) => {
    const src = iframe.getAttribute('src')
    try {
      const url = new URL(src ?? '')
      if (url.protocol !== 'https:' || !iframeHosts.has(url.hostname)) {
        iframe.remove()
        return
      }
      iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-presentation')
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
      iframe.setAttribute('loading', 'lazy')
      if (!iframe.getAttribute('title')) iframe.setAttribute('title', 'Embedded video')
    } catch {
      iframe.remove()
    }
  })
  document.querySelectorAll('a').forEach((link) => {
    link.setAttribute('rel', 'noopener noreferrer')
  })
  document.querySelectorAll<HTMLElement>('[style]').forEach((element) => {
    const style = element.getAttribute('style') ?? ''
    if (/url\s*\(|expression\s*\(|position\s*:\s*fixed/i.test(style)) element.removeAttribute('style')
  })
  return document.body.innerHTML
}

