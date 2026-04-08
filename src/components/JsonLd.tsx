/**
 * Renders a <script type="application/ld+json"> tag for structured data.
 *
 * Pass a single schema object or an array of schemas.  When an array is
 * provided the items are wrapped in a @graph container so crawlers can
 * parse all schemas from a single script tag.
 */

/* eslint-disable @typescript-eslint/no-explicit-any */
interface JsonLdProps {
  data: Record<string, any> | Record<string, any>[]
}

export default function JsonLd({ data }: JsonLdProps) {
  const payload = Array.isArray(data)
    ? { '@context': 'https://schema.org', '@graph': data.map(({ '@context': _ctx, ...rest }) => rest) }
    : data

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(payload) }}
    />
  )
}
