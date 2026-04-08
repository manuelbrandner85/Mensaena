import JsonLd from '@/components/JsonLd'
import { generateLandingSchemas } from '@/lib/structured-data'
import HomePage from './HomePage'

/**
 * Root page – server wrapper that injects JSON-LD structured data
 * (Organization + WebSite + FAQ) and renders the client-side HomePage.
 */
export default function Page() {
  return (
    <>
      <JsonLd data={generateLandingSchemas()} />
      <HomePage />
    </>
  )
}
