/// SKILL: mensaena-features
/// Riverpod-Provider rund um post_contact_preferences + post_contact_requests.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_contact_preference.dart';
import '../models/post_contact_request.dart';
import '../repositories/post_contact_repository.dart';

final postContactRepositoryProvider = Provider<PostContactRepository>((ref) {
  return const PostContactRepository();
});

// Nicht-sensible Kontakt-Metadaten (allow_*-Flags, Verfügbarkeit) für die
// CTA-Darstellung. Sensible Felder (Telefon/E-Mail/WhatsApp) NICHT enthalten —
// die liefert ausschließlich [revealedContactInfoProvider].
final postContactPreferenceProvider =
    FutureProvider.family.autoDispose<PostContactPreference?, String>(
        (ref, postId) async {
  return ref.read(postContactRepositoryProvider).getContactMeta(postId);
});

final myIncomingContactRequestsProvider =
    FutureProvider.autoDispose<List<PostContactRequest>>((ref) async {
  return ref.read(postContactRepositoryProvider).getMyIncomingRequests();
});

final myOutgoingContactRequestsProvider =
    FutureProvider.autoDispose<List<PostContactRequest>>((ref) async {
  return ref.read(postContactRepositoryProvider).getMyOutgoingRequests();
});

final postContactRequestsProvider =
    FutureProvider.family.autoDispose<List<PostContactRequest>, String>(
        (ref, postId) async {
  return ref.read(postContactRepositoryProvider).getRequestsForPost(postId);
});

final helperCountProvider =
    FutureProvider.family.autoDispose<int, String>((ref, postId) async {
  return ref.read(postContactRepositoryProvider).getHelperCountForPost(postId);
});

final myRequestForPostProvider =
    FutureProvider.family.autoDispose<PostContactRequest?, String>(
        (ref, postId) async {
  return ref.read(postContactRepositoryProvider).getMyRequestForPost(postId);
});

final revealedContactInfoProvider =
    FutureProvider.family.autoDispose<PostContactPreference?, String>(
        (ref, postId) async {
  return ref.read(postContactRepositoryProvider).getRevealedContactInfo(postId);
});
