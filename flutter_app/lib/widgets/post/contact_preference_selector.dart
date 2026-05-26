/// SKILL: mensaena-features + mensaena-design
/// ContactPreferenceSelector (Schritt 8): Multi-Channel-Auswahl mit
/// AnimatedSwitcher Eingabefeldern + optionale Erreichbarkeit.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post_contact_preference.dart';

class ContactPreferenceSelector extends StatefulWidget {
  const ContactPreferenceSelector({
    required this.userId,
    required this.postId,
    required this.onChanged,
    this.initial,
    super.key,
  });

  /// userId wird beim Submit als post_contact_preferences.user_id gespeichert.
  final String userId;

  /// postId zur Vorabbelegung. Beim Create kann ein placeholder verwendet werden
  /// und vor dem Upsert auf den echten Post-Insert-Id getauscht werden.
  final String postId;

  final PostContactPreference? initial;

  /// Wird bei jeder Aenderung mit dem aktuellen (validen) PostContactPreference
  /// gerufen — oder null wenn keine Methode aktiv ist (R6).
  final ValueChanged<PostContactPreference?> onChanged;

  @override
  State<ContactPreferenceSelector> createState() =>
      _ContactPreferenceSelectorState();
}

class _ContactPreferenceSelectorState
    extends State<ContactPreferenceSelector> {
  late bool _chat;
  late bool _phone;
  late bool _email;
  late bool _wa;
  late bool _meet;

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _meetCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  TimeOfDay? _from;
  TimeOfDay? _until;
  final Set<String> _days = <String>{};

  static const _weekdayKeys = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _chat = p?.allowInAppChat ?? true;
    _phone = p?.allowPhone ?? false;
    _email = p?.allowEmail ?? false;
    _wa = p?.allowWhatsapp ?? false;
    _meet = p?.allowLocationMeetup ?? false;
    if (p?.phoneNumber != null) _phoneCtrl.text = p!.phoneNumber!;
    if (p?.emailAddress != null) _emailCtrl.text = p!.emailAddress!;
    if (p?.whatsappNumber != null) _waCtrl.text = p!.whatsappNumber!;
    if (p?.meetupNote != null) _meetCtrl.text = p!.meetupNote!;
    if (p?.contactNote != null) _noteCtrl.text = p!.contactNote!;
    if (p?.availableDays != null) _days.addAll(p!.availableDays!);
    _from = _parseTime(p?.availableFrom);
    _until = _parseTime(p?.availableUntil);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _waCtrl.dispose();
    _meetCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _formatTime(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  void _emit() {
    if (!_chat && !_phone && !_email && !_wa && !_meet) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(PostContactPreference(
      id: widget.initial?.id,
      postId: widget.postId,
      userId: widget.userId,
      allowInAppChat: _chat,
      allowPhone: _phone,
      allowEmail: _email,
      allowWhatsapp: _wa,
      allowLocationMeetup: _meet,
      phoneNumber: _phone ? _phoneCtrl.text.trim() : null,
      emailAddress: _email ? _emailCtrl.text.trim() : null,
      whatsappNumber: _wa ? _waCtrl.text.trim() : null,
      meetupNote: _meet ? _meetCtrl.text.trim() : null,
      availableFrom: _formatTime(_from),
      availableUntil: _formatTime(_until),
      availableDays: _days.isEmpty ? null : _days.toList(),
      contactNote: _noteCtrl.text.trim().isEmpty
          ? null
          : _noteCtrl.text.trim(),
    ));
  }

  Widget _toggleRow({
    required IconData icon,
    required String labelKey,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.bronze),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(labelKey.tr(),
                      style: AppTypography.body(
                          size: 13, color: AppColors.ink)),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.bronze,
                ),
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SizeTransition(sizeFactor: a, child: c),
          ),
          child: child == null || !value
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(26, 4, 0, 8),
                  child: child,
                ),
        ),
      ],
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            AppTypography.body(size: 13, color: AppColors.mute),
        filled: true,
        fillColor: AppColors.elevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final atLeastOne = _chat || _phone || _email || _wa || _meet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('contact.title'.tr(),
            style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('contact.how_to_reach'.tr(),
            style: AppTypography.caption()),
        const SizedBox(height: 10),

        // In-App Chat (immer an, nicht deaktivierbar — R: contact-system Spec)
        Row(
          children: [
            const Icon(LucideIcons.messageCircle,
                size: 16, color: AppColors.bronze),
            const SizedBox(width: 10),
            Expanded(
              child: Text('contact.in_app_chat'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w600)),
            ),
            Switch(
                value: _chat,
                onChanged: null, // immer aktiviert
                activeColor: AppColors.bronze),
          ],
        ),

        _toggleRow(
          icon: LucideIcons.phone,
          labelKey: 'contact.phone',
          value: _phone,
          onChanged: (v) {
            setState(() => _phone = v);
            _emit();
          },
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) => _emit(),
            decoration: _input('+43 660 1234567'),
            style: AppTypography.body(size: 14, color: AppColors.ink),
          ),
        ),

        _toggleRow(
          icon: LucideIcons.mail,
          labelKey: 'contact.email',
          value: _email,
          onChanged: (v) {
            setState(() => _email = v);
            _emit();
          },
          child: TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => _emit(),
            decoration: _input('name@example.com'),
            style: AppTypography.body(size: 14, color: AppColors.ink),
          ),
        ),

        _toggleRow(
          icon: LucideIcons.messageSquare,
          labelKey: 'contact.whatsapp',
          value: _wa,
          onChanged: (v) {
            setState(() => _wa = v);
            _emit();
          },
          child: TextField(
            controller: _waCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) => _emit(),
            decoration: _input('+43 660 1234567'),
            style: AppTypography.body(size: 14, color: AppColors.ink),
          ),
        ),

        _toggleRow(
          icon: LucideIcons.mapPin,
          labelKey: 'contact.location_meetup',
          value: _meet,
          onChanged: (v) {
            setState(() => _meet = v);
            _emit();
          },
          child: TextField(
            controller: _meetCtrl,
            onChanged: (_) => _emit(),
            maxLines: 2,
            decoration: _input('contact.meetup_hint'.tr()),
            style: AppTypography.body(size: 14, color: AppColors.ink),
          ),
        ),

        const SizedBox(height: 10),
        // Erreichbarkeit (optional)
        Text('contact.availability'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TimePickerButton(
                label: 'contact.from'.tr(),
                value: _from,
                onPicked: (t) {
                  setState(() => _from = t);
                  _emit();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TimePickerButton(
                label: 'contact.until'.tr(),
                value: _until,
                onPicked: (t) {
                  setState(() => _until = t);
                  _emit();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final d in _weekdayKeys)
              ChoiceChip(
                label: Text(d),
                selected: _days.contains(d),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  });
                  _emit();
                },
                selectedColor: AppColors.bronze.withValues(alpha: 0.3),
                backgroundColor: AppColors.elevated,
                labelStyle: AppTypography.body(
                  size: 11,
                  color: _days.contains(d)
                      ? AppColors.ink
                      : AppColors.inkSoft,
                  weight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _days.contains(d)
                        ? AppColors.bronze
                        : AppColors.line,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          maxLength: 200,
          onChanged: (_) => _emit(),
          decoration: _input('contact.note_placeholder'.tr())
              .copyWith(labelText: 'contact.note'.tr()),
          style: AppTypography.body(size: 14, color: AppColors.ink),
        ),

        if (!atLeastOne) ...[
          const SizedBox(height: 6),
          Text('contact.at_least_one'.tr(),
              style: AppTypography.body(
                  size: 11,
                  color: AppColors.herzrotWarm,
                  weight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.label,
    required this.value,
    required this.onPicked,
  });
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onPicked;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) onPicked(picked);
      },
      onLongPress: () => onPicked(null),
      icon: const Icon(LucideIcons.clock, size: 14),
      label: Text(
        value == null
            ? label
            : '$label · ${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}',
        style: AppTypography.body(
            size: 12, color: AppColors.ink, weight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.bronze,
        side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
