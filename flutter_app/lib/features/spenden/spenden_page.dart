import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glow_button.dart';
import '../../routing/routes.dart';

/// Spenden-Page – Cinema-Variant der Web /spenden.
/// Cherry-Pick: Hero / Amount-Chips / Tiers / IBAN-Block mit Copy / Costs.
/// Bewusst weggelassen vs. Web: SEPA-QR-Code (kein qr_flutter dep),
/// Donor-Tier-Badge fuer Logged-In (Phase-2-Polish).
class SpendenPage extends StatefulWidget {
  const SpendenPage({super.key});

  @override
  State<SpendenPage> createState() => _SpendenPageState();
}

class _SpendenPageState extends State<SpendenPage> {
  int _selectedAmount = 3;
  bool _isCustom = false;
  final TextEditingController _customCtrl = TextEditingController();

  static const List<int> _presets = [1, 3, 5, 10, 25];
  static const String _iban = 'DE79 1001 0178 6303 9229 28';
  static const String _bic = 'REVODEB2';
  static const String _recipient = 'Mensaena';

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  double get _finalAmount {
    if (!_isCustom) return _selectedAmount.toDouble();
    return double.tryParse(_customCtrl.text.replaceAll(',', '.')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.app,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: MnColors.ink),
          onPressed: () => Navigator.of(context).maybePop().then((popped) {
            if (!popped && context.mounted) context.go(Routes.landing);
          }),
        ),
        title: Text('Mensaena unterstützen', style: MnTypography.appBarTitle()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroSection(),
                  const SizedBox(height: 48),
                  _AmountSection(
                    selected: _selectedAmount,
                    isCustom: _isCustom,
                    customCtrl: _customCtrl,
                    onSelect: (v) => setState(() {
                      _selectedAmount = v;
                      _isCustom = false;
                    }),
                    onCustom: () => setState(() => _isCustom = true),
                    onCustomChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 40),
                  _TiersSection(selected: _selectedAmount, isCustom: _isCustom),
                  const SizedBox(height: 40),
                  _IbanSection(amount: _finalAmount),
                  const SizedBox(height: 40),
                  const _CostsSection(),
                  const SizedBox(height: 40),
                  const _ClosingNote(),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '— Spenden',
          style: MnTypography.label(
            size: 11,
            color: MnColors.amber,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Mensaena läuft\nweil Nachbarn helfen.',
          style: MnTypography.display(
            size: 34,
            height: 1.1,
            color: MnColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Kostenlos. Werbefrei. Gemeinnützig. '
          'Jede Spende deckt direkt Server, Domain und SMS-Verifikation – '
          'damit Nachbarschaftshilfe für alle gratis bleibt.',
          style: MnTypography.body(
            size: 15,
            color: MnColors.inkSoft,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ── Amount ───────────────────────────────────────────────────────────────
class _AmountSection extends StatelessWidget {
  const _AmountSection({
    required this.selected,
    required this.isCustom,
    required this.customCtrl,
    required this.onSelect,
    required this.onCustom,
    required this.onCustomChanged,
  });

  final int selected;
  final bool isCustom;
  final TextEditingController customCtrl;
  final ValueChanged<int> onSelect;
  final VoidCallback onCustom;
  final ValueChanged<String> onCustomChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wähle deinen Beitrag',
          style: MnTypography.display(
            size: 20,
            height: 1.2,
            color: MnColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final amount in _SpendenPageState._presets)
              _AmountChip(
                amount: amount,
                active: !isCustom && selected == amount,
                onTap: () => onSelect(amount),
              ),
            _CustomChip(
              active: isCustom,
              onTap: onCustom,
            ),
          ],
        ),
        if (isCustom) ...[
          const SizedBox(height: 16),
          TextField(
            controller: customCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            onChanged: onCustomChanged,
            style: MnTypography.body(size: 16, color: MnColors.ink),
            decoration: InputDecoration(
              labelText: 'Eigener Betrag in €',
              labelStyle: MnTypography.label(size: 11),
              filled: true,
              fillColor: MnColors.deep.withValues(alpha: 0.6),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: MnColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: MnColors.amber, width: 2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.amount,
    required this.active,
    required this.onTap,
  });

  final int amount;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? MnColors.amber.withValues(alpha: 0.18)
              : MnColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: active ? MnColors.amber : MnColors.line,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$amount €',
          style: MnTypography.mono(
            size: 15,
            color: active ? MnColors.amber : MnColors.inkSoft,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CustomChip extends StatelessWidget {
  const _CustomChip({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? MnColors.amber.withValues(alpha: 0.18)
              : MnColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: active ? MnColors.amber : MnColors.line,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Eigener Betrag',
          style: MnTypography.body(
            size: 14,
            color: active ? MnColors.amber : MnColors.inkSoft,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Tiers ────────────────────────────────────────────────────────────────
class _TiersSection extends StatelessWidget {
  const _TiersSection({required this.selected, required this.isCustom});

  final int selected;
  final bool isCustom;

  static const List<_TierData> _tiers = [
    _TierData(
      icon: LucideIcons.coffee,
      amount: 1,
      label: 'Kaffee',
      impact: 'Danke! Ein symbolischer Start.',
    ),
    _TierData(
      icon: LucideIcons.heart,
      amount: 3,
      label: 'Nachbar:in',
      impact: 'Push-Benachrichtigungen für 60 Nachbar:innen einen Monat lang.',
      popular: true,
    ),
    _TierData(
      icon: LucideIcons.star,
      amount: 5,
      label: 'Held:in',
      impact: 'Ein Monat Chat-Server für die gesamte Plattform.',
    ),
    _TierData(
      icon: LucideIcons.sparkles,
      amount: 10,
      label: 'Botschafter:in',
      impact: 'Ein Monat Kartenservice für alle Nachbarschaften.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cross = c.maxWidth < 520 ? 1 : 2;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cross == 1 ? 3.5 : 1.7,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: _tiers
              .map((t) => _TierCard(
                    tier: t,
                    highlight: !isCustom && selected == t.amount,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _TierData {
  const _TierData({
    required this.icon,
    required this.amount,
    required this.label,
    required this.impact,
    this.popular = false,
  });
  final IconData icon;
  final int amount;
  final String label;
  final String impact;
  final bool popular;
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.highlight});

  final _TierData tier;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? MnColors.amber.withValues(alpha: 0.10)
            : MnColors.surface.withValues(alpha: 0.5),
        border: Border.all(
          color: highlight ? MnColors.amber : MnColors.line,
          width: highlight ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tier.icon, size: 18, color: MnColors.amber),
              const SizedBox(width: 8),
              Text(
                tier.label,
                style: MnTypography.body(
                  size: 14,
                  color: MnColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (tier.popular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MnColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Beliebt',
                    style: MnTypography.label(
                      size: 9,
                      color: MnColors.voidColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                )
              else
                Text(
                  '${tier.amount} €',
                  style: MnTypography.mono(size: 14),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tier.impact,
            style: MnTypography.body(
              size: 13,
              color: MnColors.inkSoft,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── IBAN ─────────────────────────────────────────────────────────────────
class _IbanSection extends StatefulWidget {
  const _IbanSection({required this.amount});
  final double amount;

  @override
  State<_IbanSection> createState() => _IbanSectionState();
}

class _IbanSectionState extends State<_IbanSection> {
  bool _copied = false;

  Future<void> _copyIban() async {
    await Clipboard.setData(
      const ClipboardData(
        text: 'DE79100101786303922928',
      ),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final amountStr = widget.amount > 0
        ? widget.amount.toStringAsFixed(2).replaceAll('.', ',')
        : '–';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.deep.withValues(alpha: 0.7),
        border: Border.all(color: MnColors.lineActive),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.building2,
                  size: 18, color: MnColors.amber),
              const SizedBox(width: 8),
              Text(
                'SEPA-Überweisung',
                style: MnTypography.body(
                  size: 15,
                  color: MnColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IbanRow(label: 'Empfänger', value: _SpendenPageState._recipient),
          const SizedBox(height: 10),
          _IbanRow(
            label: 'IBAN',
            value: _SpendenPageState._iban,
            trailing: IconButton(
              tooltip: _copied ? 'Kopiert' : 'IBAN kopieren',
              icon: Icon(
                _copied ? LucideIcons.check : LucideIcons.copy,
                size: 18,
                color: _copied ? MnColors.leben : MnColors.amber,
              ),
              onPressed: _copyIban,
            ),
          ),
          const SizedBox(height: 10),
          _IbanRow(label: 'BIC', value: _SpendenPageState._bic),
          const SizedBox(height: 10),
          _IbanRow(
            label: 'Verwendungszweck',
            value: 'Spende Mensaena${widget.amount > 0 ? ' – $amountStr €' : ''}',
          ),
          const SizedBox(height: 18),
          Text(
            'Öffne deine Banking-App und tippe IBAN + Betrag manuell ein, '
            'oder kopiere die IBAN. Vielen Dank!',
            style: MnTypography.caption(),
          ),
        ],
      ),
    );
  }
}

class _IbanRow extends StatelessWidget {
  const _IbanRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: MnTypography.label(size: 10),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: MnTypography.mono(
              size: 13,
              color: MnColors.ink,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Costs ────────────────────────────────────────────────────────────────
class _CostsSection extends StatelessWidget {
  const _CostsSection();

  static const List<_CostItem> _costs = [
    _CostItem(
      icon: LucideIcons.shield,
      label: 'Server & Infrastruktur',
      value: '~30 €/Monat',
    ),
    _CostItem(
      icon: LucideIcons.creditCard,
      label: 'Domain & SSL',
      value: '~15 €/Jahr',
    ),
    _CostItem(
      icon: LucideIcons.users,
      label: 'SMS-Verifikation',
      value: '~0,05 €/Nutzer:in',
    ),
    _CostItem(
      icon: LucideIcons.heart,
      label: 'Entwicklung',
      value: 'ehrenamtlich',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wofür dein Geld läuft',
          style: MnTypography.display(
            size: 20,
            height: 1.2,
            color: MnColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        for (final c in _costs) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MnColors.surface.withValues(alpha: 0.4),
              border: Border.all(color: MnColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(c.icon, size: 18, color: MnColors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.label,
                    style: MnTypography.body(
                      size: 14,
                      color: MnColors.ink,
                    ),
                  ),
                ),
                Text(
                  c.value,
                  style: MnTypography.mono(size: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CostItem {
  const _CostItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

// ── Closing ──────────────────────────────────────────────────────────────
class _ClosingNote extends StatelessWidget {
  const _ClosingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MnColors.surface.withValues(alpha: 0.3),
        border: Border.all(color: MnColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shield,
                  size: 16, color: MnColors.inkSoft),
              const SizedBox(width: 8),
              Text(
                'Hinweis',
                style: MnTypography.label(size: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Mensaena ist ein nicht-kommerzielles Projekt im Aufbau zum '
            'gemeinnützigen Verein. Spendenquittungen sind derzeit noch nicht '
            'ausstellbar. Mit deinem Beitrag deckst du laufende Kosten – '
            'transparent, ohne Gewinn.',
            style: MnTypography.body(
              size: 13,
              color: MnColors.inkSoft,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          GlowButton(
            label: 'Zurück zur Startseite',
            variant: GlowVariant.ghost,
            icon: LucideIcons.arrowRight,
            onPressed: () => context.go(Routes.landing),
          ),
        ],
      ),
    );
  }
}
