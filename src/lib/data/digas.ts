// ─────────────────────────────────────────────────────────────────────────────
// DiGA-Verzeichnis – Digitale Gesundheitsanwendungen (§ 139e SGB V)
//
// Quelle: BfArM DiGA-Verzeichnis (https://diga.bfarm.de/de/verzeichnis)
// Stand: 2026-04 – kuratierte Liste zugelassener DiGAs
//
// Hinweis: Ärzt:innen können DiGAs auf Rezept verordnen, Versicherte können
// sie auch direkt bei der Krankenkasse beantragen (§ 33a SGB V).
// ─────────────────────────────────────────────────────────────────────────────

export type DigaCategory =
  | 'depression'
  | 'anxiety'
  | 'sleep'
  | 'pain'
  | 'cardio'
  | 'neurology'
  | 'diabetes'
  | 'addiction'
  | 'oncology'
  | 'other'

export interface DiGA {
  id:                   string
  name:                 string
  manufacturer:         string
  indication:           string
  category:             DigaCategory
  description:          string
  prescriptionRequired: boolean
  url:                  string
  appStoreUrl?:         string
  playStoreUrl?:        string
}

export const DIGA_CATEGORIES: Record<DigaCategory, { label: string; emoji: string; color: string }> = {
  depression: { label: 'Depressionen',         emoji: '💙', color: '#3B82F6' },
  anxiety:    { label: 'Angststörungen',        emoji: '🧘', color: '#8B5CF6' },
  sleep:      { label: 'Schlafstörungen',       emoji: '😴', color: '#6366F1' },
  pain:       { label: 'Schmerz & Bewegung',    emoji: '💪', color: '#F59E0B' },
  cardio:     { label: 'Herz-Kreislauf',        emoji: '❤️', color: '#EF4444' },
  neurology:  { label: 'Neurologie',            emoji: '🧠', color: '#EC4899' },
  diabetes:   { label: 'Diabetes & Stoffwechsel', emoji: '🩺', color: '#10B981' },
  addiction:  { label: 'Sucht & Abhängigkeit',  emoji: '🌱', color: '#14B8A6' },
  oncology:   { label: 'Onkologie',             emoji: '🎗️', color: '#F97316' },
  other:      { label: 'Sonstige',              emoji: '⚕️', color: '#6B7280' },
}

export const DIGAS: DiGA[] = [
  // ── Depression ────────────────────────────────────────────────────────────
  {
    id: 'deprexis',
    name: 'Deprexis',
    manufacturer: 'GAIA AG',
    indication: 'Leichte bis mittelschwere Depression',
    category: 'depression',
    description: 'Web-basiertes Programm mit kognitiv-verhaltenstherapeutischen Modulen zur Behandlung depressiver Symptome. Clinisch validiert in über 20 Studien.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/878',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.gaia.deprexis',
  },
  {
    id: 'novego',
    name: 'Novego',
    manufacturer: 'Servier Deutschland GmbH',
    indication: 'Depressive Episode (leicht bis mittelgradig)',
    category: 'depression',
    description: 'Digitales Therapieprogramm für Erwachsene mit leichter bis mittelschwerer Depression. Bietet interaktive Lektionen und Übungen aus der KVT.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1116',
  },
  {
    id: 'hb-depression',
    name: 'HelloBetter Depression',
    manufacturer: 'HelloBetter (GET.ON Institut GmbH)',
    indication: 'Depressive Episoden',
    category: 'depression',
    description: 'Online-Therapieprogramm mit psychologisch begleiteten Übungen aus der kognitiven Verhaltenstherapie, speziell für Depressionen entwickelt.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1186',
  },
  {
    id: 'selfapy-depression',
    name: 'Selfapy',
    manufacturer: 'Selfapy GmbH',
    indication: 'Depressionen, Angst, Burnout',
    category: 'depression',
    description: 'Online-Kurs mit psychologisch begleiteten Übungen zu Depression, Angst und Burnout. Basiert auf kognitiver Verhaltenstherapie und Achtsamkeit.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1183',
    appStoreUrl: 'https://apps.apple.com/de/app/selfapy/id1140558095',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=de.selfapy.app',
  },

  // ── Angststörungen ────────────────────────────────────────────────────────
  {
    id: 'velibra',
    name: 'Velibra',
    manufacturer: 'GAIA AG',
    indication: 'Generalisierte Angststörung, Soziale Phobie, Panikstörung',
    category: 'anxiety',
    description: 'Webbasierte kognitive Verhaltenstherapie für verschiedene Angststörungen. Strukturiertes 12-Wochen-Programm mit über 50 Übungen.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1069',
  },
  {
    id: 'mindable',
    name: 'Mindable',
    manufacturer: 'Mindable Health GmbH',
    indication: 'Panikstörung, Agoraphobie',
    category: 'anxiety',
    description: 'App zur Behandlung von Panikstörungen mit Expositionsübungen, KVT-Modulen und Biofeedback über die Kamera des Smartphones.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1117',
    appStoreUrl: 'https://apps.apple.com/de/app/mindable/id1450253052',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=de.mindable.app',
  },
  {
    id: 'invirto',
    name: 'Invirto',
    manufacturer: 'GAIA AG',
    indication: 'Soziale Angststörung, Panikstörung, Agoraphobie',
    category: 'anxiety',
    description: 'Verhaltenstherapeutisches Online-Programm zur Behandlung sozialer Phobien und Panikstörungen, ergänzt durch Virtual-Reality-Expositions­elemente.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1227',
  },
  {
    id: 'hb-panik',
    name: 'HelloBetter Panik & Angst',
    manufacturer: 'HelloBetter (GET.ON Institut GmbH)',
    indication: 'Panikstörung, Agoraphobie',
    category: 'anxiety',
    description: 'Psychologisch begleitetes Online-Programm für Panikstörungen und Agoraphobie mit KVT-basierten Modulen und Expositionsübungen.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1187',
  },

  // ── Schlafstörungen ───────────────────────────────────────────────────────
  {
    id: 'somnio',
    name: 'Somnio',
    manufacturer: 'mementor DE GmbH',
    indication: 'Chronische Insomnie (Schlafstörungen)',
    category: 'sleep',
    description: 'Digitale Kognitive Verhaltenstherapie bei Schlafstörungen (KVT-I). Sechs-Wochen-Programm mit Schlaftagebuch, Entspannungsübungen und Schlafrestriktion.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/887',
    appStoreUrl: 'https://apps.apple.com/de/app/somnio-schlaf-therapie/id1450263826',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=de.mementor.somnio',
  },
  {
    id: 'nia',
    name: 'Nia',
    manufacturer: 'Nia Health GmbH',
    indication: 'Schlafstörungen (Insomnie)',
    category: 'sleep',
    description: 'Digitales Therapieprogramm bei Ein- und Durchschlafstörungen. Nutzt KVT-I mit personalisierten Schlafrestriktionsplänen und Biofeedback.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1211',
    appStoreUrl: 'https://apps.apple.com/de/app/nia-schlaf/id1498834543',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=health.nia.app',
  },

  // ── Schmerz & Bewegung ────────────────────────────────────────────────────
  {
    id: 'vivira',
    name: 'Vivira',
    manufacturer: 'Vivira Health Lab GmbH',
    indication: 'Rückenschmerzen, Hüft- und Knieschmerzen',
    category: 'pain',
    description: 'Digitales Übungsprogramm bei muskuloskelettalen Beschwerden. Personalisierte Bewegungsübungen per Video, täglich 10–20 Minuten.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/871',
    appStoreUrl: 'https://apps.apple.com/de/app/vivira/id1084764736',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.vivira.app',
  },
  {
    id: 'mawendo',
    name: 'Mawendo',
    manufacturer: 'Mawendo GmbH',
    indication: 'Gonarthrose (Kniearthrose)',
    category: 'pain',
    description: 'Digitale Bewegungstherapie bei Kniearthrose mit physiotherapeutisch entwickelten Video-Übungen und Fortschrittsmonitoring.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1036',
    appStoreUrl: 'https://apps.apple.com/de/app/mawendo/id1441946028',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.mawendo.app',
  },
  {
    id: 'kaia-ruecken',
    name: 'Kaia Rücken',
    manufacturer: 'Kaia Health GmbH',
    indication: 'Nicht-spezifische Rückenschmerzen',
    category: 'pain',
    description: 'Multimodales Schmerztherapie-Programm mit Bewegung, Achtsamkeit und Wissensmodulen. Verwendet KI-gestützte Bewegungskorrektur via Smartphone-Kamera.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1016',
    appStoreUrl: 'https://apps.apple.com/de/app/kaia/id1097603847',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.kaiahealth.backpain',
  },
  {
    id: 'm-sense',
    name: 'M-sense Migraine',
    manufacturer: 'newsenselab GmbH',
    indication: 'Migräne (episodisch)',
    category: 'pain',
    description: 'Digitales Migräne-Tagebuch mit individueller Triggererkennung, Biofeedback-Entspannung und verhaltenstherapeutischen Modulen zur Anfallsreduktion.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/909',
    appStoreUrl: 'https://apps.apple.com/de/app/m-sense-migraine/id1037634534',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=de.newsenselab.msense',
  },

  // ── Herz-Kreislauf ────────────────────────────────────────────────────────
  {
    id: 'actensio',
    name: 'Actensio',
    manufacturer: 'Heartbeat Medical GmbH',
    indication: 'Essentielle Hypertonie (Bluthochdruck)',
    category: 'cardio',
    description: 'Digitale Therapiebegleitung bei Bluthochdruck mit Blutdrucktagebuch, Lebensstilinterventionen und individuellen Handlungsempfehlungen.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1191',
  },
  {
    id: 'vantis-khk',
    name: 'Vantis KHK',
    manufacturer: 'Servier Deutschland GmbH',
    indication: 'Koronare Herzkrankheit (KHK)',
    category: 'cardio',
    description: 'Digitales Unterstützungsprogramm für Patientinnen und Patienten mit koronarer Herzkrankheit zur Verbesserung des Selbstmanagements und der Lebensqualität.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1112',
  },

  // ── Neurologie ────────────────────────────────────────────────────────────
  {
    id: 'kalmeda',
    name: 'Kalmeda',
    manufacturer: 'mynoise GmbH',
    indication: 'Chronischer Tinnitus',
    category: 'neurology',
    description: 'Digitale Verhaltenstherapie bei chronischem Tinnitus. Psychoedukation, KVT-basierte Übungen und Klangtherapie für eine bessere Krankheitsbewältigung.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/869',
    appStoreUrl: 'https://apps.apple.com/de/app/kalmeda-tinnitus-app/id1437811940',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.mynoise.kalmeda',
  },
  {
    id: 'elevida',
    name: 'Elevida',
    manufacturer: 'GAIA AG',
    indication: 'Multiple Sklerose (Fatigue)',
    category: 'neurology',
    description: 'Digitales Programm zur Behandlung von MS-assoziierter Fatigue. Verhaltenstherapeutische Module zur Energieregulation und Aktivitätsmanagement.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1140',
  },
  {
    id: 'rehappy',
    name: 'Rehappy',
    manufacturer: 'Rehappy GmbH',
    indication: 'Schlaganfall-Rehabilitation',
    category: 'neurology',
    description: 'Digitale Unterstützung nach Schlaganfall. Informationen, Übungen und ein Tagebuch helfen Betroffenen und Angehörigen im Rehabilitationsalltag.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1050',
    appStoreUrl: 'https://apps.apple.com/de/app/rehappy/id1456706553',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.rehappy.app',
  },

  // ── Diabetes & Stoffwechsel ───────────────────────────────────────────────
  {
    id: 'glucura',
    name: 'Glucura',
    manufacturer: 'FIMO Health GmbH',
    indication: 'Diabetes mellitus Typ 2',
    category: 'diabetes',
    description: 'Digitales Therapieprogramm bei Typ-2-Diabetes mit personalisierter Ernährungsberatung, Bewegungscoaching und kontinuierlichem Glukosemonitoring.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1201',
    appStoreUrl: 'https://apps.apple.com/de/app/glucura/id1544571898',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.fimohealth.glucura',
  },
  {
    id: 'zanadio',
    name: 'Zanadio',
    manufacturer: 'aidhere GmbH',
    indication: 'Adipositas (Grad I & II)',
    category: 'diabetes',
    description: 'Digitales Therapieprogramm zur nachhaltigen Gewichtsreduktion bei Adipositas. Kombination aus Ernährungs-, Bewegungs- und Verhaltenstherapie.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/885',
    appStoreUrl: 'https://apps.apple.com/de/app/zanadio/id1456862011',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.aidhere.zanadio',
  },

  // ── Sucht & Abhängigkeit ──────────────────────────────────────────────────
  {
    id: 'vorvida',
    name: 'Vorvida',
    manufacturer: 'GAIA AG',
    indication: 'Alkoholmissbrauch (schädlicher Konsum)',
    category: 'addiction',
    description: 'Digitales Selbsthilfeprogramm zur Reduktion von problematischem Alkoholkonsum. Basiert auf motivierender Gesprächsführung und Verhaltenstherapie.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/879',
  },

  // ── Onkologie ─────────────────────────────────────────────────────────────
  {
    id: 'cara-care',
    name: 'Cara Care für Reizdarm',
    manufacturer: 'HiDoc Technologies GmbH',
    indication: 'Reizdarmsyndrom (IBS)',
    category: 'other',
    description: 'Digitales multimodales Therapieprogramm beim Reizdarmsyndrom. Ernährungstagebuch, Stressmanagement und verhaltenstherapeutische Module.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/877',
    appStoreUrl: 'https://apps.apple.com/de/app/cara-care/id1200456356',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=de.cara.app',
  },
  {
    id: 'cankado',
    name: 'Cankado PRO-react HER2',
    manufacturer: 'cankado service GmbH',
    indication: 'Brustkrebs (HER2-positiv)',
    category: 'oncology',
    description: 'Digitale Therapiebegleitung bei HER2-positivem Brustkrebs. Dokumentation von Symptomen und Nebenwirkungen während der Krebstherapie.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1082',
    appStoreUrl: 'https://apps.apple.com/de/app/cankado/id985596680',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.cankado.app',
  },

  // ── Sonstige ──────────────────────────────────────────────────────────────
  {
    id: 'hb-stress',
    name: 'HelloBetter Stress & Burnout',
    manufacturer: 'HelloBetter (GET.ON Institut GmbH)',
    indication: 'Stressreduktion, Burnout-Prävention',
    category: 'other',
    description: 'Online-Therapieprogramm zur Reduktion von Stress und Burnout-Symptomen. KVT-basierte Module mit psychologischer Begleitung.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1188',
  },
  {
    id: 'clira',
    name: 'CLIRA',
    manufacturer: 'Raidon Health GmbH',
    indication: 'COPD (chronisch obstruktive Lungenerkrankung)',
    category: 'other',
    description: 'Digitale Therapiebegleitung bei COPD. Atemübungen, Tagebuchfunktion und personalisiertes Selbstmanagement zur Verbesserung der Lungenfunktion.',
    prescriptionRequired: true,
    url: 'https://diga.bfarm.de/de/verzeichnis/1206',
  },
]

// ── Filter & Search ───────────────────────────────────────────────────────────

export function filterDigas(category?: DigaCategory | 'all', query?: string): DiGA[] {
  let result = DIGAS

  if (category && category !== 'all') {
    result = result.filter(d => d.category === category)
  }

  if (query) {
    const q = query.toLowerCase()
    result = result.filter(d =>
      d.name.toLowerCase().includes(q) ||
      d.indication.toLowerCase().includes(q) ||
      d.manufacturer.toLowerCase().includes(q) ||
      d.description.toLowerCase().includes(q),
    )
  }

  return result
}

export function getDigaCategories(): DigaCategory[] {
  const used = new Set(DIGAS.map(d => d.category))
  return (Object.keys(DIGA_CATEGORIES) as DigaCategory[]).filter(c => used.has(c))
}
