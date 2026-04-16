import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/event_service.dart';
import 'package:mensaena/models/event.dart';

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(ref.watch(supabaseProvider));
});

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  return ref.read(eventServiceProvider).getEvents();
});

final upcomingEventsProvider = FutureProvider<List<Event>>((ref) async {
  return ref.read(eventServiceProvider).getUpcomingEvents();
});

final eventDetailProvider = FutureProvider.family<Event?, String>((ref, eventId) async {
  return ref.read(eventServiceProvider).getEvent(eventId);
});
