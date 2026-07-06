import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/models/post_contact_preference.dart';

void main() {
  // Sicherheits-Kontrakt: die Meta-RPC (get_post_contact_meta) liefert für
  // Fremde bewusst KEINE sensiblen Klartextfelder. Der Client darf aus so einer
  // reduzierten Zeile trotzdem korrekt die erlaubten Kontaktwege ableiten,
  // ohne dass Telefon/E-Mail/WhatsApp „aus Versehen" befüllt werden.
  group('PostContactPreference.fromJson – Meta-Zeile (ohne sensible Felder)', () {
    final meta = PostContactPreference.fromJson(<String, dynamic>{
      'id': 'pcp-1',
      'post_id': 'post-1',
      'user_id': 'owner-1',
      'allow_in_app_chat': true,
      'allow_phone': true,
      'allow_email': true,
      'allow_whatsapp': false,
      'allow_location_meetup': true,
      'meetup_note': 'Am Gemeindezentrum',
      'available_from': '09:00:00',
      'available_until': '17:00:00',
      'available_days': ['Mo', 'Di'],
      'contact_note': 'Bitte vormittags',
    });

    test('sensible Felder bleiben null', () {
      expect(meta.phoneNumber, isNull);
      expect(meta.emailAddress, isNull);
      expect(meta.whatsappNumber, isNull);
    });

    test('nicht-sensible Metadaten werden übernommen', () {
      expect(meta.meetupNote, 'Am Gemeindezentrum');
      expect(meta.contactNote, 'Bitte vormittags');
      expect(meta.hasAvailability, isTrue);
      expect(meta.availableDays, ['Mo', 'Di']);
    });

    test('enabledMethods spiegelt die allow_*-Flags', () {
      expect(meta.enabledMethods,
          ['in_app_chat', 'phone', 'email', 'location_meetup']);
    });
  });

  // Reveal-RPC (get_revealed_contact_info) liefert für Owner/accepted die
  // vollständige Zeile inkl. sensibler Felder.
  group('PostContactPreference.fromJson – Reveal-Zeile (vollständig)', () {
    test('sensible Felder werden korrekt gemappt', () {
      final full = PostContactPreference.fromJson(<String, dynamic>{
        'id': 'pcp-1',
        'post_id': 'post-1',
        'user_id': 'owner-1',
        'allow_in_app_chat': true,
        'allow_phone': true,
        'allow_email': true,
        'allow_whatsapp': true,
        'allow_location_meetup': false,
        'phone_number': '+491234567',
        'email_address': 'hilfe@example.org',
        'whatsapp_number': '+491234567',
        'meetup_note': null,
        'available_from': null,
        'available_until': null,
        'available_days': null,
        'contact_note': null,
      });

      expect(full.phoneNumber, '+491234567');
      expect(full.emailAddress, 'hilfe@example.org');
      expect(full.whatsappNumber, '+491234567');
      expect(full.hasAvailability, isFalse);
    });
  });
}
