/// SKILL: mensaena-features
/// Zentrale, wiederverwendbare Formular-Validatoren für alle Create/Edit-Screens.
/// Ersetzt das bisherige Boolean-Flag-Anti-Pattern durch echte, i18n-fähige
/// TextFormField-Validatoren. Alle geben `null` zurück wenn gültig, sonst eine
/// übersetzte Fehlermeldung (Keys unter `validate.*` in allen 7 Sprachen).
library;

import 'package:easy_localization/easy_localization.dart';

class FormValidators {
  FormValidators._();

  /// Pflichtfeld — nicht leer nach trim.
  static String? required(String? v) {
    if (v == null || v.trim().isEmpty) return 'validate.required'.tr();
    return null;
  }

  /// Pflichtfeld mit Mindest-/Maximallänge.
  static String? Function(String?) lengthBetween(int min, int max,
      {bool requiredField = true}) {
    return (String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return requiredField ? 'validate.required'.tr() : null;
      if (t.length < min) {
        return 'validate.tooShort'.tr(namedArgs: {'n': '$min'});
      }
      if (t.length > max) {
        return 'validate.tooLong'.tr(namedArgs: {'n': '$max'});
      }
      return null;
    };
  }

  /// E-Mail — optional (leer ok), aber falls gefüllt muss Format stimmen.
  static String? emailOptional(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final re = RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');
    return re.hasMatch(t) ? null : 'validate.email'.tr();
  }

  /// Telefon/WhatsApp — optional, erlaubt +, Ziffern, Leerzeichen, (), -, /.
  static String? phoneOptional(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 5) return 'validate.phone'.tr();
    final re = RegExp(r'^[+0-9 ()/\-]{5,}$');
    return re.hasMatch(t) ? null : 'validate.phone'.tr();
  }

  /// URL — optional, http(s) oder bloße Domain.
  static String? urlOptional(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final re = RegExp(r'^(https?://)?([\w-]+\.)+[\w-]{2,}(/\S*)?$');
    return re.hasMatch(t) ? null : 'validate.url'.tr();
  }

  /// Positive Zahl — optional.
  static String? positiveNumberOptional(String? v) {
    final t = (v ?? '').replaceAll(',', '.').trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null) return 'validate.number'.tr();
    if (n < 0) return 'validate.positive'.tr();
    return null;
  }
}
