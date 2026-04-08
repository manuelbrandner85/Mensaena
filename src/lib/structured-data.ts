/* ═══════════════════════════════════════════════════════════════════════
   STRUCTURED  DATA  –  JSON-LD  SCHEMA  GENERATORS
   Schema.org compliant generators for rich search results.
   ═══════════════════════════════════════════════════════════════════════ */

import {
  SITE_URL,
  SITE_NAME,
  SITE_DESCRIPTION,
  CONTACT_EMAIL,
  DEFAULT_OG_IMAGE,
  getCanonicalUrl,
} from './seo'

// ── Types ────────────────────────────────────────────────────────────

/* eslint-disable @typescript-eslint/no-explicit-any */
type JsonLdObject = Record<string, any>

// ── Organization ─────────────────────────────────────────────────────

export function generateOrganizationSchema(): JsonLdObject {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: SITE_NAME,
    url: SITE_URL,
    logo: `${SITE_URL}/mensaena-logo.png`,
    description: SITE_DESCRIPTION,
    email: CONTACT_EMAIL,
    areaServed: [
      { '@type': 'Country', name: 'Germany' },
      { '@type': 'Country', name: 'Austria' },
      { '@type': 'Country', name: 'Switzerland' },
    ],
    foundingDate: '2025',
    sameAs: [],
  }
}

// ── WebSite ──────────────────────────────────────────────────────────

export function generateWebSiteSchema(): JsonLdObject {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: SITE_NAME,
    url: SITE_URL,
    description: SITE_DESCRIPTION,
    inLanguage: 'de',
    potentialAction: {
      '@type': 'SearchAction',
      target: `${SITE_URL}/search?q={search_term_string}`,
      'query-input': 'required name=search_term_string',
    },
  }
}

// ── BreadcrumbList ───────────────────────────────────────────────────

export function generateBreadcrumbSchema(
  items: { name: string; url: string }[],
): JsonLdObject {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: item.name,
      item: item.url,
    })),
  }
}

// ── Article (for posts) ──────────────────────────────────────────────

export interface PostSchemaInput {
  title: string
  description: string
  datePublished: string
  dateModified: string
  authorName: string
  category: string
  url: string
  image?: string
}

export function generatePostSchema(post: PostSchemaInput): JsonLdObject {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: post.title,
    description: post.description,
    datePublished: post.datePublished,
    dateModified: post.dateModified,
    author: {
      '@type': 'Person',
      name: post.authorName,
    },
    publisher: {
      '@type': 'Organization',
      name: SITE_NAME,
      logo: {
        '@type': 'ImageObject',
        url: `${SITE_URL}/mensaena-logo.png`,
      },
    },
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': post.url,
    },
    articleSection: post.category,
    inLanguage: 'de',
    ...(post.image ? { image: post.image } : {}),
  }
}

// ── Person (for profiles) ────────────────────────────────────────────

export interface ProfileSchemaInput {
  name: string
  description?: string
  image?: string
  url: string
}

export function generateProfileSchema(
  profile: ProfileSchemaInput,
): JsonLdObject {
  return {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name: profile.name,
    ...(profile.description ? { description: profile.description } : {}),
    ...(profile.image ? { image: profile.image } : {}),
    url: profile.url,
    memberOf: {
      '@type': 'Organization',
      name: SITE_NAME,
    },
  }
}

// ── FAQ ──────────────────────────────────────────────────────────────

export function generateFAQSchema(
  faqs: { question: string; answer: string }[],
): JsonLdObject {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.answer,
      },
    })),
  }
}

// ── Landing-page FAQ content ─────────────────────────────────────────

export const LANDING_FAQS: { question: string; answer: string }[] = [
  {
    question: 'Was ist Mensaena?',
    answer:
      'Mensaena ist eine Gemeinwohl-Plattform für Nachbarschaftshilfe. Sie verbindet Menschen in der Nachbarschaft, um sich gegenseitig zu helfen – sei es beim Einkaufen, Werkzeug leihen, Mitfahrgelegenheiten oder in Krisensituationen.',
  },
  {
    question: 'Ist Mensaena kostenlos?',
    answer:
      'Ja, Mensaena ist 100 % kostenlos. Die Plattform ist gemeinnützig und wird von der Gemeinschaft getragen. Es gibt keine versteckten Kosten oder Premium-Funktionen.',
  },
  {
    question: 'Ist Mensaena sicher?',
    answer:
      'Ja. Mensaena ist DSGVO-konform und legt großen Wert auf Datenschutz. Persönliche Daten werden verschlüsselt gespeichert und niemals an Dritte weitergegeben.',
  },
  {
    question: 'Wie kann ich mitmachen?',
    answer:
      'Erstelle ein kostenloses Konto auf mensaena.de, vervollständige dein Profil und schon kannst du Hilfe anbieten oder suchen. Die Registrierung dauert weniger als eine Minute.',
  },
  {
    question: 'Für wen ist Mensaena gedacht?',
    answer:
      'Mensaena ist für alle Menschen gedacht, die in ihrer Nachbarschaft aktiv werden möchten – unabhängig von Alter, Herkunft oder technischem Wissen. Ob du Hilfe brauchst oder anbieten möchtest, jeder ist willkommen.',
  },
]

// ── Helper: landing-page combined schemas ────────────────────────────

export function generateLandingSchemas(): JsonLdObject[] {
  return [
    generateOrganizationSchema(),
    generateWebSiteSchema(),
    generateFAQSchema(LANDING_FAQS),
  ]
}
