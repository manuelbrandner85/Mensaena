/// SKILL: mensaena-features
///
/// International emergency numbers foundation (Phase C1).
/// Static config for 30 countries (DACH + EU + World) used by the
/// Resources screen country tabs and the crisis flow fallback.
///
/// Translations of labels live in JSON files (added in Phase C2); the
/// labels here are German fallbacks for the DACH-first UX.
library;

/// Emergency-number configuration for a single country.
class CountryEmergencyConfig {
  const CountryEmergencyConfig({
    required this.code,
    required this.flag,
    required this.label,
    required this.emergency,
    required this.police,
    required this.fire,
    this.ambulance,
    this.crisisHotline,
    this.crisisHotlineLabel,
    this.childHotline,
    this.womenHotline,
    this.poisonHotline,
  });

  /// ISO-3166-1 alpha-2 country code (uppercase).
  final String code;

  /// Unicode flag emoji (regional indicator symbols).
  final String flag;

  /// Display name (German).
  final String label;

  /// Universal emergency number (e.g. 112 in EU, 911 in US).
  final String emergency;

  /// Police direct line.
  final String police;

  /// Fire brigade direct line.
  final String fire;

  /// Ambulance / EMS direct line (if separate from `emergency`).
  final String? ambulance;

  /// Mental-health / suicide crisis hotline.
  final String? crisisHotline;

  /// Human-readable label for the crisis hotline (org name).
  final String? crisisHotlineLabel;

  /// Child-protection / abuse hotline.
  final String? childHotline;

  /// Women's helpline / domestic violence.
  final String? womenHotline;

  /// Poison-control hotline.
  final String? poisonHotline;
}

/// EU-wide single emergency number.
const String kEuEmergencyNumber = '112';

/// Note about EU 112 (German, displayed in info banners).
const String kEuEmergencyNote = 'EU-weit kostenlos, 24/7';

/// All supported country configs (30 entries).
const List<CountryEmergencyConfig> kCountryEmergencyConfigs = [
  // ── DACH ──────────────────────────────────────────────────────────────
  CountryEmergencyConfig(
    code: 'DE',
    flag: '🇩🇪',
    label: 'Deutschland',
    emergency: '112',
    police: '110',
    fire: '112',
    ambulance: '112',
    crisisHotline: '0800 111 0 111',
    crisisHotlineLabel: 'Telefonseelsorge',
    childHotline: '116 111',
    womenHotline: '08000 116 016',
    poisonHotline: '030 19240',
  ),
  CountryEmergencyConfig(
    code: 'AT',
    flag: '🇦🇹',
    label: 'Österreich',
    emergency: '112',
    police: '133',
    fire: '122',
    ambulance: '144',
    crisisHotline: '142',
    crisisHotlineLabel: 'Telefonseelsorge',
    childHotline: '147',
    womenHotline: '0800 222 555',
    poisonHotline: '01 406 43 43',
  ),
  CountryEmergencyConfig(
    code: 'CH',
    flag: '🇨🇭',
    label: 'Schweiz',
    emergency: '112',
    police: '117',
    fire: '118',
    ambulance: '144',
    crisisHotline: '143',
    crisisHotlineLabel: 'Die Dargebotene Hand',
    childHotline: '147',
    womenHotline: '0800 800 007',
    poisonHotline: '145',
  ),

  // ── EU ────────────────────────────────────────────────────────────────
  CountryEmergencyConfig(
    code: 'IT',
    flag: '🇮🇹',
    label: 'Italien',
    emergency: '112',
    police: '113',
    fire: '115',
    ambulance: '118',
    crisisHotline: '02 2327 2327',
    crisisHotlineLabel: 'Telefono Amico',
    childHotline: '114',
    womenHotline: '1522',
    poisonHotline: '06 3054343',
  ),
  CountryEmergencyConfig(
    code: 'FR',
    flag: '🇫🇷',
    label: 'Frankreich',
    emergency: '112',
    police: '17',
    fire: '18',
    ambulance: '15',
    crisisHotline: '3114',
    crisisHotlineLabel: 'Numéro national de prévention du suicide',
    childHotline: '119',
    womenHotline: '3919',
    poisonHotline: '01 40 05 48 48',
  ),
  CountryEmergencyConfig(
    code: 'ES',
    flag: '🇪🇸',
    label: 'Spanien',
    emergency: '112',
    police: '091',
    fire: '080',
    ambulance: '061',
    crisisHotline: '024',
    crisisHotlineLabel: 'Línea de atención a la conducta suicida',
    childHotline: '116 111',
    womenHotline: '016',
    poisonHotline: '91 562 04 20',
  ),
  CountryEmergencyConfig(
    code: 'NL',
    flag: '🇳🇱',
    label: 'Niederlande',
    emergency: '112',
    police: '0900 8844',
    fire: '112',
    ambulance: '112',
    crisisHotline: '0800 0113',
    crisisHotlineLabel: '113 Zelfmoordpreventie',
    childHotline: '0800 2345 678',
    womenHotline: '0800 2000',
    poisonHotline: '030 274 8888',
  ),
  CountryEmergencyConfig(
    code: 'PL',
    flag: '🇵🇱',
    label: 'Polen',
    emergency: '112',
    police: '997',
    fire: '998',
    ambulance: '999',
    crisisHotline: '116 123',
    crisisHotlineLabel: 'Kryzysowy Telefon Zaufania',
    childHotline: '116 111',
    womenHotline: '800 120 002',
    poisonHotline: '42 657 99 00',
  ),
  CountryEmergencyConfig(
    code: 'CZ',
    flag: '🇨🇿',
    label: 'Tschechien',
    emergency: '112',
    police: '158',
    fire: '150',
    ambulance: '155',
    crisisHotline: '116 123',
    crisisHotlineLabel: 'Linka první psychické pomoci',
    childHotline: '116 111',
    womenHotline: '116 006',
    poisonHotline: '224 919 293',
  ),
  CountryEmergencyConfig(
    code: 'HU',
    flag: '🇭🇺',
    label: 'Ungarn',
    emergency: '112',
    police: '107',
    fire: '105',
    ambulance: '104',
    crisisHotline: '116 123',
    crisisHotlineLabel: 'Lelki Elsősegély Telefonszolgálat',
    childHotline: '116 111',
    womenHotline: '06 80 20 55 20',
    poisonHotline: '06 80 201 199',
  ),
  CountryEmergencyConfig(
    code: 'GB',
    flag: '🇬🇧',
    label: 'Vereinigtes Königreich',
    emergency: '999',
    police: '101',
    fire: '999',
    ambulance: '999',
    crisisHotline: '116 123',
    crisisHotlineLabel: 'Samaritans',
    childHotline: '0800 1111',
    womenHotline: '0808 2000 247',
    poisonHotline: '111',
  ),
  CountryEmergencyConfig(
    code: 'SE',
    flag: '🇸🇪',
    label: 'Schweden',
    emergency: '112',
    police: '114 14',
    fire: '112',
    ambulance: '112',
    crisisHotline: '90101',
    crisisHotlineLabel: 'Jourhavande medmänniska',
    childHotline: '116 111',
    womenHotline: '020 50 50 50',
    poisonHotline: '010 456 6700',
  ),
  CountryEmergencyConfig(
    code: 'GR',
    flag: '🇬🇷',
    label: 'Griechenland',
    emergency: '112',
    police: '100',
    fire: '199',
    ambulance: '166',
    crisisHotline: '1018',
    crisisHotlineLabel: 'Klimaka Suicide Prevention',
    childHotline: '1056',
    womenHotline: '15900',
    poisonHotline: '210 7793777',
  ),
  CountryEmergencyConfig(
    code: 'PT',
    flag: '🇵🇹',
    label: 'Portugal',
    emergency: '112',
    police: '112',
    fire: '112',
    ambulance: '112',
    crisisHotline: '213 544 545',
    crisisHotlineLabel: 'SOS Voz Amiga',
    childHotline: '116 111',
    womenHotline: '800 202 148',
    poisonHotline: '800 250 250',
  ),
  CountryEmergencyConfig(
    code: 'TR',
    flag: '🇹🇷',
    label: 'Türkei',
    emergency: '112',
    police: '155',
    fire: '110',
    ambulance: '112',
    crisisHotline: '182',
    crisisHotlineLabel: 'İntihar Önleme Hattı',
    childHotline: '183',
    womenHotline: '183',
    poisonHotline: '114',
  ),
  CountryEmergencyConfig(
    code: 'RO',
    flag: '🇷🇴',
    label: 'Rumänien',
    emergency: '112',
    police: '112',
    fire: '112',
    ambulance: '112',
    crisisHotline: '0800 801 200',
    crisisHotlineLabel: 'Alianța Română de Prevenție a Suicidului',
    childHotline: '116 111',
    womenHotline: '0800 500 333',
    poisonHotline: '021 318 36 06',
  ),
  CountryEmergencyConfig(
    code: 'HR',
    flag: '🇭🇷',
    label: 'Kroatien',
    emergency: '112',
    police: '192',
    fire: '193',
    ambulance: '194',
    crisisHotline: '01 4833 888',
    crisisHotlineLabel: 'Centar za krizna stanja',
    childHotline: '116 111',
    womenHotline: '0800 5544',
    poisonHotline: '01 2348 342',
  ),
  CountryEmergencyConfig(
    code: 'BG',
    flag: '🇧🇬',
    label: 'Bulgarien',
    emergency: '112',
    police: '166',
    fire: '160',
    ambulance: '150',
    crisisHotline: '0035 9249 17 223',
    crisisHotlineLabel: 'Bulgarian Red Cross Helpline',
    childHotline: '116 111',
    womenHotline: '0800 18 676',
    poisonHotline: '02 9154 409',
  ),
  CountryEmergencyConfig(
    code: 'DK',
    flag: '🇩🇰',
    label: 'Dänemark',
    emergency: '112',
    police: '114',
    fire: '112',
    ambulance: '112',
    crisisHotline: '70 201 201',
    crisisHotlineLabel: 'Livslinien',
    childHotline: '116 111',
    womenHotline: '70 20 30 82',
    poisonHotline: '82 12 12 12',
  ),
  CountryEmergencyConfig(
    code: 'FI',
    flag: '🇫🇮',
    label: 'Finnland',
    emergency: '112',
    police: '112',
    fire: '112',
    ambulance: '112',
    crisisHotline: '09 2525 0111',
    crisisHotlineLabel: 'MIELI Kriisipuhelin',
    childHotline: '116 111',
    womenHotline: '080 005 005',
    poisonHotline: '0800 147 111',
  ),
  CountryEmergencyConfig(
    code: 'NO',
    flag: '🇳🇴',
    label: 'Norwegen',
    emergency: '112',
    police: '02800',
    fire: '110',
    ambulance: '113',
    crisisHotline: '116 123',
    crisisHotlineLabel: 'Mental Helse',
    childHotline: '116 111',
    womenHotline: '116 006',
    poisonHotline: '22 59 13 00',
  ),
  CountryEmergencyConfig(
    code: 'IE',
    flag: '🇮🇪',
    label: 'Irland',
    emergency: '112',
    police: '112',
    fire: '112',
    ambulance: '112',
    crisisHotline: '116 123',
    crisisHotlineLabel: 'Samaritans Ireland',
    childHotline: '116 111',
    womenHotline: '1800 341 900',
    poisonHotline: '01 8092166',
  ),
  CountryEmergencyConfig(
    code: 'BE',
    flag: '🇧🇪',
    label: 'Belgien',
    emergency: '112',
    police: '101',
    fire: '112',
    ambulance: '112',
    crisisHotline: '1813',
    crisisHotlineLabel: 'Centrum ter Preventie van Zelfdoding',
    childHotline: '116 111',
    womenHotline: '0800 30 030',
    poisonHotline: '070 245 245',
  ),
  CountryEmergencyConfig(
    code: 'LU',
    flag: '🇱🇺',
    label: 'Luxemburg',
    emergency: '112',
    police: '113',
    fire: '112',
    ambulance: '112',
    crisisHotline: '454545',
    crisisHotlineLabel: 'SOS Détresse',
    childHotline: '116 111',
    womenHotline: '2060 1060',
    poisonHotline: '8002 5500',
  ),

  // ── World ─────────────────────────────────────────────────────────────
  CountryEmergencyConfig(
    code: 'US',
    flag: '🇺🇸',
    label: 'Vereinigte Staaten',
    emergency: '911',
    police: '911',
    fire: '911',
    ambulance: '911',
    crisisHotline: '988',
    crisisHotlineLabel: 'Suicide & Crisis Lifeline',
    childHotline: '1-800-422-4453',
    womenHotline: '1-800-799-7233',
    poisonHotline: '1-800-222-1222',
  ),
  CountryEmergencyConfig(
    code: 'CA',
    flag: '🇨🇦',
    label: 'Kanada',
    emergency: '911',
    police: '911',
    fire: '911',
    ambulance: '911',
    crisisHotline: '988',
    crisisHotlineLabel: 'Suicide Crisis Helpline',
    childHotline: '1-800-668-6868',
    womenHotline: '1-800-799-7233',
    poisonHotline: '1-844-764-7669',
  ),
  CountryEmergencyConfig(
    code: 'AU',
    flag: '🇦🇺',
    label: 'Australien',
    emergency: '000',
    police: '000',
    fire: '000',
    ambulance: '000',
    crisisHotline: '13 11 14',
    crisisHotlineLabel: 'Lifeline Australia',
    childHotline: '1800 55 1800',
    womenHotline: '1800 737 732',
    poisonHotline: '13 11 26',
  ),
  CountryEmergencyConfig(
    code: 'BR',
    flag: '🇧🇷',
    label: 'Brasilien',
    emergency: '190',
    police: '190',
    fire: '193',
    ambulance: '192',
    crisisHotline: '188',
    crisisHotlineLabel: 'Centro de Valorização da Vida',
    childHotline: '100',
    womenHotline: '180',
    poisonHotline: '0800 722 6001',
  ),
  CountryEmergencyConfig(
    code: 'JP',
    flag: '🇯🇵',
    label: 'Japan',
    emergency: '110',
    police: '110',
    fire: '119',
    ambulance: '119',
    crisisHotline: '0570 064 556',
    crisisHotlineLabel: 'Yorisoi Hotline',
    childHotline: '0120 007 110',
    womenHotline: '0570 070 810',
    poisonHotline: '072 727 2499',
  ),
  CountryEmergencyConfig(
    code: 'IN',
    flag: '🇮🇳',
    label: 'Indien',
    emergency: '112',
    police: '100',
    fire: '101',
    ambulance: '102',
    crisisHotline: '9152987821',
    crisisHotlineLabel: 'iCall Helpline',
    childHotline: '1098',
    womenHotline: '181',
    poisonHotline: '1800 116 117',
  ),
  CountryEmergencyConfig(
    code: 'ZA',
    flag: '🇿🇦',
    label: 'Südafrika',
    emergency: '112',
    police: '10111',
    fire: '10177',
    ambulance: '10177',
    crisisHotline: '0800 567 567',
    crisisHotlineLabel: 'SADAG Suicide Crisis Line',
    childHotline: '116',
    womenHotline: '0800 150 150',
    poisonHotline: '0861 555 777',
  ),
  CountryEmergencyConfig(
    code: 'UA',
    flag: '🇺🇦',
    label: 'Ukraine',
    emergency: '112',
    police: '102',
    fire: '101',
    ambulance: '103',
    crisisHotline: '7333',
    crisisHotlineLabel: 'Lifeline Ukraine',
    childHotline: '116 111',
    womenHotline: '116 123',
    poisonHotline: '044 418 24 36',
  ),
];

/// Lookup by ISO-2 code (case-insensitive). Returns `null` if not found.
CountryEmergencyConfig? getCountryConfig(String code) {
  final upper = code.toUpperCase();
  for (final c in kCountryEmergencyConfigs) {
    if (c.code == upper) return c;
  }
  return null;
}

/// DACH-only subset (DE / AT / CH) for the primary onboarding flow.
List<CountryEmergencyConfig> get kDachCountries => kCountryEmergencyConfigs
    .where((c) => c.code == 'DE' || c.code == 'AT' || c.code == 'CH')
    .toList(growable: false);
