import Link from 'next/link'
import { ArrowRight, Leaf } from 'lucide-react'

export default function CTASection() {
  return (
    <section className="py-24 bg-gradient-to-br from-primary-700 via-primary-600 to-primary-800 relative overflow-hidden">
      {/* Background decorations */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-20 -right-20 w-64 h-64 bg-white/5 rounded-full blur-2xl" />
        <div className="absolute -bottom-20 -left-20 w-64 h-64 bg-white/5 rounded-full blur-2xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-primary-500/20 rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        {/* Icon */}
        <div className="inline-flex items-center justify-center w-16 h-16 bg-white/20 backdrop-blur rounded-2xl mb-8">
          <Leaf className="w-8 h-8 text-white" />
        </div>

        {/* Headline */}
        <h2 className="text-4xl md:text-5xl font-bold text-white mb-6 text-balance">
          Werde Teil der Gemeinschaft
        </h2>
        <p className="text-xl text-primary-100 leading-relaxed mb-10 text-balance max-w-2xl mx-auto">
          Mensaena ist kostenlos, werbefrein und für alle. Registriere dich heute 
          und beginne, deine Nachbarschaft aktiv mitzugestalten.
        </p>

        {/* Buttons */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link
            href="/register"
            className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-white text-primary-700 font-bold text-base rounded-xl hover:bg-primary-50 transition-all duration-200 shadow-lg hover:shadow-xl hover:-translate-y-0.5 w-full sm:w-auto"
          >
            Kostenlos registrieren
            <ArrowRight className="w-5 h-5" />
          </Link>
          <Link
            href="/login"
            className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-transparent text-white font-semibold text-base rounded-xl border-2 border-white/40 hover:border-white/70 hover:bg-white/10 transition-all duration-200 w-full sm:w-auto"
          >
            Bereits registriert? Anmelden
          </Link>
        </div>

        {/* Social Proof */}
        <p className="mt-10 text-primary-200 text-sm">
          ✓ Keine Kreditkarte &nbsp;·&nbsp; ✓ Keine versteckten Kosten &nbsp;·&nbsp; ✓ Jederzeit kündbar
        </p>
      </div>
    </section>
  )
}
