import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/services/auth_service.dart';
import 'package:mensaena/services/profile_service.dart';
import 'package:mensaena/models/user_profile.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

// Profile service provider
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(supabaseProvider));
});

// Auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

// Current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.id;
});

// Current user profile
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.read(profileServiceProvider).getProfile(userId);
});

// Profile by user ID
final profileProvider = FutureProvider.family<UserProfile?, String>((ref, userId) async {
  return ref.read(profileServiceProvider).getProfile(userId);
});

// Profile stats
final profileStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  return ref.read(profileServiceProvider).getProfileStats(userId);
});

// User search
final userSearchProvider = FutureProvider.family<List<UserProfile>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(profileServiceProvider).searchUsers(query);
});
