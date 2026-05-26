/// SKILL: mensaena-features
/// Smart-Reply-Service: generiert 3 passende Vorschlags-Nachrichten zur
/// Kontaktaufnahme aus einem Post — je nach PostIntent + Titel.
/// Vollstaendig on-device, kein LLM-Call.
library;

import 'package:easy_localization/easy_localization.dart';

import '../models/post.dart';
import '../models/post_intent.dart';

class SmartReplyService {
  const SmartReplyService._();

  /// Liefert 3 i18n-Vorschlaege passend zum Post. Erster Vorschlag ist immer
  /// der spezifischste, dritter ist eine sichere Standard-Variante.
  static List<String> suggestionsFor(Post post) {
    final title = post.title.trim();
    final ti = (title.length > 60 ? '${title.substring(0, 60)}…' : title);
    final args = {'title': ti};
    switch (post.postIntent) {
      case PostIntent.helpNeeded:
        return [
          'smartReply.helpNeeded.1'.tr(namedArgs: args),
          'smartReply.helpNeeded.2'.tr(namedArgs: args),
          'smartReply.helpNeeded.3'.tr(),
        ];
      case PostIntent.helpOffered:
        return [
          'smartReply.helpOffered.1'.tr(namedArgs: args),
          'smartReply.helpOffered.2'.tr(namedArgs: args),
          'smartReply.helpOffered.3'.tr(),
        ];
      case PostIntent.itemOffered:
        return [
          'smartReply.itemOffered.1'.tr(namedArgs: args),
          'smartReply.itemOffered.2'.tr(namedArgs: args),
          'smartReply.itemOffered.3'.tr(),
        ];
      case PostIntent.itemWanted:
        return [
          'smartReply.itemWanted.1'.tr(namedArgs: args),
          'smartReply.itemWanted.2'.tr(namedArgs: args),
          'smartReply.itemWanted.3'.tr(),
        ];
      case PostIntent.eventInvite:
        return [
          'smartReply.eventInvite.1'.tr(namedArgs: args),
          'smartReply.eventInvite.2'.tr(namedArgs: args),
          'smartReply.eventInvite.3'.tr(),
        ];
      case PostIntent.lostFound:
        return [
          'smartReply.lostFound.1'.tr(namedArgs: args),
          'smartReply.lostFound.2'.tr(namedArgs: args),
          'smartReply.lostFound.3'.tr(),
        ];
      case PostIntent.social:
        return [
          'smartReply.social.1'.tr(namedArgs: args),
          'smartReply.social.2'.tr(),
          'smartReply.social.3'.tr(),
        ];
      case PostIntent.infoShare:
      case PostIntent.warning:
      case PostIntent.general:
        return [
          'smartReply.general.1'.tr(namedArgs: args),
          'smartReply.general.2'.tr(),
          'smartReply.general.3'.tr(),
        ];
    }
  }
}
