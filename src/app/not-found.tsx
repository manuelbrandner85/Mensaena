
export default function NotFound() {
  return (
    <html lang="de">
      <body style={{ margin: 0, fontFamily: 'sans-serif', background: '#f9fafb', display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
        <div style={{ textAlign: 'center', padding: '2rem' }}>
          <div style={{ fontSize: '4rem', marginBottom: '1rem' }}>🌿</div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: '#111827', marginBottom: '0.5rem' }}>Seite nicht gefunden</h1>
          <p style={{ color: '#6b7280', marginBottom: '1.5rem' }}>Diese Seite existiert nicht.</p>
          <a href="/" style={{ background: '#16a34a', color: 'white', padding: '0.75rem 1.5rem', borderRadius: '0.5rem', textDecoration: 'none', fontWeight: 600 }}>
            Zur Startseite
          </a>
        </div>
      </body>
    </html>
  )
}
