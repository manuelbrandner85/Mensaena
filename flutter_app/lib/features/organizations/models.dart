import 'package:flutter/material.dart';

class OrganizationCategory {
  const OrganizationCategory({required this.value, required this.label, required this.emoji});
  final String value;
  final String label;
  final String emoji;

  static const all = <OrganizationCategory>[
    OrganizationCategory(value: 'tierheim', label: 'Tierheim', emoji: '🐕'),
    OrganizationCategory(value: 'tierschutz', label: 'Tierschutz', emoji: '🐾'),
    OrganizationCategory(value: 'suppenkueche', label: 'Suppenküche', emoji: '🍲'),
    OrganizationCategory(value: 'obdachlosenhilfe', label: 'Obdachlosenhilfe', emoji: '🏠'),
    OrganizationCategory(value: 'tafel', label: 'Tafel', emoji: '🥖'),
    OrganizationCategory(value: 'kleiderkammer', label: 'Kleiderkammer', emoji: '👕'),
    OrganizationCategory(value: 'sozialkaufhaus', label: 'Sozialkaufhaus', emoji: '🛍️'),
    OrganizationCategory(value: 'krisentelefon', label: 'Krisentelefon', emoji: '📞'),
    OrganizationCategory(value: 'notschlafstelle', label: 'Notschlafstelle', emoji: '🛌'),
    OrganizationCategory(value: 'jugend', label: 'Jugend', emoji: '🧒'),
    OrganizationCategory(value: 'senioren', label: 'Senioren', emoji: '👵'),
    OrganizationCategory(value: 'behinderung', label: 'Behinderung', emoji: '♿'),
    OrganizationCategory(value: 'sucht', label: 'Sucht', emoji: '💊'),
    OrganizationCategory(value: 'fluechtlingshilfe', label: 'Flüchtlingshilfe', emoji: '🤝'),
    OrganizationCategory(value: 'allgemein', label: 'Allgemein', emoji: '🏛️'),
  ];

  static OrganizationCategory? forValue(String? value) {
    if (value == null) return null;
    for (final c in all) {
      if (c.value == value) return c;
    }
    return null;
  }

  static const fallback = OrganizationCategory(
    value: 'allgemein',
    label: 'Allgemein',
    emoji: '🏛️',
  );
}

class Organization {
  const Organization({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    required this.city,
    required this.country,
    required this.isVerified,
    required this.isActive,
    required this.isEmergency,
    required this.ratingAvg,
    required this.ratingCount,
    required this.services,
    required this.targetGroups,
    required this.languages,
    required this.tags,
    required this.createdAt,
    this.shortDescription,
    this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.address,
    this.zipCode,
    this.state,
    this.latitude,
    this.longitude,
    this.phone,
    this.email,
    this.website,
    this.openingHoursText,
    this.distanceKm,
  });

  final String id;
  final String slug;
  final String name;
  final String category;
  final String city;
  final String country;
  final bool isVerified;
  final bool isActive;
  final bool isEmergency;
  final double ratingAvg;
  final int ratingCount;
  final List<String> services;
  final List<String> targetGroups;
  final List<String> languages;
  final List<String> tags;
  final DateTime createdAt;
  final String? shortDescription;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? address;
  final String? zipCode;
  final String? state;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? email;
  final String? website;
  final String? openingHoursText;
  final double? distanceKm;

  OrganizationCategory get categoryConfig =>
      OrganizationCategory.forValue(category) ?? OrganizationCategory.fallback;

  factory Organization.fromJson(Map<String, dynamic> j) {
    List<String> stringList(Object? v) {
      if (v is List) return v.whereType<String>().toList();
      return const [];
    }

    double? parseDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Organization(
      id: j['id'] as String,
      slug: j['slug'] as String? ?? '',
      name: j['name'] as String? ?? '',
      category: j['category'] as String? ?? 'allgemein',
      city: j['city'] as String? ?? '',
      country: j['country'] as String? ?? 'Österreich',
      isVerified: j['is_verified'] as bool? ?? false,
      isActive: j['is_active'] as bool? ?? true,
      isEmergency: j['is_emergency'] as bool? ?? false,
      ratingAvg: parseDouble(j['rating_avg']) ?? 0,
      ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
      services: stringList(j['services']),
      targetGroups: stringList(j['target_groups']),
      languages: stringList(j['languages']),
      tags: stringList(j['tags']),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      shortDescription: j['short_description'] as String?,
      description: j['description'] as String?,
      logoUrl: j['logo_url'] as String?,
      coverImageUrl: j['cover_image_url'] as String?,
      address: j['address'] as String?,
      zipCode: j['zip_code'] as String?,
      state: j['state'] as String?,
      latitude: parseDouble(j['latitude']),
      longitude: parseDouble(j['longitude']),
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      website: j['website'] as String?,
      openingHoursText: j['opening_hours_text'] as String?,
      distanceKm: parseDouble(j['distance_km']),
    );
  }
}

extension OrganizationCategoryColor on OrganizationCategory {
  Color get accentColor {
    switch (value) {
      case 'tierheim':
      case 'tierschutz':
        return const Color(0xFFBE185D);
      case 'suppenkueche':
      case 'tafel':
        return const Color(0xFFA16207);
      case 'obdachlosenhilfe':
      case 'notschlafstelle':
        return const Color(0xFF1D4ED8);
      case 'kleiderkammer':
      case 'sozialkaufhaus':
        return const Color(0xFF0F766E);
      case 'krisentelefon':
        return const Color(0xFFB91C1C);
      case 'fluechtlingshilfe':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF374151);
    }
  }
}
