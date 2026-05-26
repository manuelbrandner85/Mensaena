/// SKILL: mensaena-features
/// PostIntent (Mega-Contact-System): bestimmt CTA-Logik pro Post.
/// 10 Werte, mit Smart-Defaults aus posts.type.
library;

enum PostIntent {
  helpNeeded('help_needed'),
  helpOffered('help_offered'),
  itemOffered('item_offered'),
  itemWanted('item_wanted'),
  eventInvite('event_invite'),
  infoShare('info_share'),
  warning('warning'),
  lostFound('lost_found'),
  social('social'),
  general('general');

  const PostIntent(this.value);
  final String value;

  /// i18n-Key fuer den primaeren CTA-Button.
  String get primaryCtaKey {
    switch (this) {
      case PostIntent.helpNeeded:
        return 'contact.cta.offer_help';
      case PostIntent.helpOffered:
        return 'contact.cta.request_help';
      case PostIntent.itemOffered:
        return 'contact.cta.contact_seller';
      case PostIntent.itemWanted:
        return 'contact.cta.offer_item';
      case PostIntent.eventInvite:
        return 'contact.cta.join_event';
      case PostIntent.infoShare:
        return 'contact.cta.thanks';
      case PostIntent.warning:
        return 'contact.cta.report_update';
      case PostIntent.lostFound:
        return 'contact.cta.i_found_it';
      case PostIntent.social:
        return 'contact.cta.connect';
      case PostIntent.general:
        return 'contact.cta.contact';
    }
  }

  /// true fuer alle ausser info_share und warning.
  bool get requiresContact =>
      this != PostIntent.infoShare && this != PostIntent.warning;

  bool get isHelpRelated =>
      this == PostIntent.helpNeeded || this == PostIntent.helpOffered;

  bool get isItemRelated =>
      this == PostIntent.itemOffered || this == PostIntent.itemWanted;

  /// Lucide-Icon-Name (Lucide-Icons-Package nutzt CamelCase, hier nur fuer
  /// CTA-Mapping; das eigentliche IconData wird im Widget aufgeloest).
  String get ctaIconName {
    switch (this) {
      case PostIntent.helpNeeded:
      case PostIntent.helpOffered:
        return 'hand_helping';
      case PostIntent.itemOffered:
      case PostIntent.itemWanted:
        return 'package';
      case PostIntent.eventInvite:
        return 'calendar_check';
      case PostIntent.lostFound:
        return 'search';
      case PostIntent.warning:
        return 'alert_triangle';
      case PostIntent.infoShare:
        return 'info';
      case PostIntent.social:
        return 'users';
      default:
        return 'message_circle';
    }
  }

  /// Semantische Farb-Klasse — Widget mapped auf AppColors.
  String get ctaColorKey {
    switch (this) {
      case PostIntent.helpNeeded:
        return 'error';
      case PostIntent.helpOffered:
        return 'success';
      case PostIntent.lostFound:
        return 'warning';
      default:
        return 'primary';
    }
  }

  String get emoji {
    switch (this) {
      case PostIntent.helpNeeded:
        return '🤝';
      case PostIntent.helpOffered:
        return '💪';
      case PostIntent.itemOffered:
        return '📦';
      case PostIntent.itemWanted:
        return '🔍';
      case PostIntent.eventInvite:
        return '🎉';
      case PostIntent.infoShare:
        return 'ℹ️';
      case PostIntent.warning:
        return '⚠️';
      case PostIntent.lostFound:
        return '🐾';
      case PostIntent.social:
        return '👋';
      case PostIntent.general:
        return '📝';
    }
  }

  /// i18n-Key fuer den Intent-Picker-Tile-Text.
  String get labelKey => 'post_intent.$value';

  static PostIntent fromString(String? raw) {
    if (raw == null) return PostIntent.general;
    for (final i in PostIntent.values) {
      if (i.value == raw) return i;
    }
    return PostIntent.general;
  }

  /// Smart-Default aus existierendem posts.type-Feld.
  static PostIntent fromPostType(String? type) {
    switch (type) {
      case 'help_request':
        return PostIntent.helpNeeded;
      case 'help_offer':
      case 'help_offered':
        return PostIntent.helpOffered;
      case 'marketplace':
      case 'sharing':
        return PostIntent.itemOffered;
      case 'event':
        return PostIntent.eventInvite;
      case 'warning':
      case 'crisis':
        return PostIntent.warning;
      case 'lost_pet':
      case 'animal':
        return PostIntent.lostFound;
      case 'info':
      case 'community':
        return PostIntent.infoShare;
      default:
        return PostIntent.general;
    }
  }
}
