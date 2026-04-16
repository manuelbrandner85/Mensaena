import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/organization_service.dart';
import 'package:mensaena/models/organization.dart';

final organizationServiceProvider = Provider<OrganizationService>((ref) {
  return OrganizationService(ref.watch(supabaseProvider));
});

final organizationsProvider = FutureProvider.family<List<Organization>, Map<String, String?>>((ref, params) async {
  return ref.read(organizationServiceProvider).getOrganizations(
    category: params['category'],
    search: params['search'],
    country: params['country'],
  );
});

final organizationDetailProvider = FutureProvider.family<Organization?, String>((ref, orgId) async {
  return ref.read(organizationServiceProvider).getOrganization(orgId);
});

final organizationReviewsProvider = FutureProvider.family<List<OrganizationReview>, String>((ref, orgId) async {
  return ref.read(organizationServiceProvider).getReviews(orgId);
});

final orgCategoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  return ref.read(organizationServiceProvider).getCategoryCounts();
});
