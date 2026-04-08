import { ImageResponse } from 'next/og'
import { NextRequest } from 'next/server'
import { getCategoryLabel } from '@/lib/seo'


const BRAND_COLOR = '#059669'
const BRAND_COLOR_LIGHT = '#d1fae5'

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl
  const title = searchParams.get('title') || 'Nachbarschaftshilfe neu gedacht'
  const category = searchParams.get('category') || ''
  const type = searchParams.get('type') || 'default'

  // Dynamic font size based on title length
  const titleFontSize =
    title.length > 80 ? 36 : title.length > 50 ? 42 : title.length > 30 ? 48 : 56

  const categoryLabel = category ? getCategoryLabel(category) : ''

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          backgroundColor: '#ffffff',
          position: 'relative',
        }}
      >
        {/* Top accent bar */}
        <div
          style={{
            width: '100%',
            height: '6px',
            background: `linear-gradient(90deg, ${BRAND_COLOR} 0%, #38a169 100%)`,
          }}
        />

        {/* Content area */}
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'space-between',
            padding: '48px 60px 40px 60px',
          }}
        >
          {/* Top: Logo text */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
            }}
          >
            <div
              style={{
                width: '40px',
                height: '40px',
                borderRadius: '12px',
                background: `linear-gradient(135deg, ${BRAND_COLOR} 0%, #38a169 100%)`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
                fontSize: '20px',
                fontWeight: 800,
              }}
            >
              M
            </div>
            <span
              style={{
                fontSize: '24px',
                fontWeight: 700,
                color: BRAND_COLOR,
                letterSpacing: '-0.02em',
              }}
            >
              Mensaena
            </span>
          </div>

          {/* Middle: Title + Category */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: '16px',
              maxWidth: '900px',
            }}
          >
            {categoryLabel && (
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <span
                  style={{
                    backgroundColor: BRAND_COLOR_LIGHT,
                    color: BRAND_COLOR,
                    fontSize: '16px',
                    fontWeight: 600,
                    padding: '6px 16px',
                    borderRadius: '100px',
                  }}
                >
                  {categoryLabel}
                </span>
              </div>
            )}
            <h1
              style={{
                fontSize: `${titleFontSize}px`,
                fontWeight: 800,
                color: '#111827',
                lineHeight: 1.2,
                letterSpacing: '-0.02em',
                margin: 0,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                display: '-webkit-box',
                WebkitLineClamp: 3,
                WebkitBoxOrient: 'vertical',
              }}
            >
              {title}
            </h1>
          </div>

          {/* Bottom: URL + claim */}
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'flex-end',
            }}
          >
            <span
              style={{
                fontSize: '18px',
                fontWeight: 600,
                color: '#6b7280',
              }}
            >
              mensaena.de
            </span>
            <span
              style={{
                fontSize: '16px',
                color: '#9ca3af',
              }}
            >
              Nachbarschaftshilfe neu gedacht
            </span>
          </div>
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
      headers: {
        'Cache-Control': 'public, max-age=86400, s-maxage=86400',
      },
    },
  )
}
