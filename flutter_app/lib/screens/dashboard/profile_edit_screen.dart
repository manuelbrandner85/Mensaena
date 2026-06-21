import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/avatar_generator_service.dart';
import '../../services/locale_country_service.dart';
import '../../services/location_anonymizer.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Profile-Edit — vollständiger Profil-Builder mit 8 Sektionen:
/// Hero, Basis, Kontakt+Location, Skills, Toggles, Notruf-Kontakte,
/// Quiet-Hours, Privatsphäre. Alle Felder zu Supabase `profiles`-Tabelle.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  Future<Profile?>? _future;
  Profile? _profile;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  // ── Basis ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  // ── Kontakt + Location ────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _homepageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  String _country = 'DE';
  double? _lat;
  double? _lng;
  int _radiusKm = 50;

  // ── Avatar + Cover ────────────────────────────────────────────
  File? _newAvatar;
  String? _generatedAvatarUrl;
  File? _newCover;
  bool _isGeneratingAvatar = false;

  // ── Skill-Lists ───────────────────────────────────────────────
  List<String> _skills = [];
  List<String> _offerTags = [];
  List<String> _seekTags = [];
  List<String> _mentorTopics = [];
  List<String> _crisisSkills = [];
  Set<String> _preferredModules = {};

  // ── Toggles ───────────────────────────────────────────────────
  bool _isMentor = false;
  bool _isCrisisVolunteer = false;

  // ── Notruf-Kontakte ───────────────────────────────────────────
  List<_EmergencyContact> _emergency = [];

  // ── Quiet Hours ───────────────────────────────────────────────
  bool _quietEnabled = false;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;

  // ── Privatsphäre ──────────────────────────────────────────────
  String _profileVisibility = 'neighbors';
  bool _showOnlineStatus = true;
  bool _showLocation = true;
  bool _showTrustScore = true;
  bool _showActivity = true;
  bool _showPhone = false;
  bool _readReceipts = true;
  bool _allowMatching = true;

  static const List<String> _countries = [
    'DE',
    'AT',
    'CH',
    'IT',
    'ES',
    'FR',
    'TR',
    'RU',
    'GB',
    'US',
    'IE',
  ];

  static const List<String> _moduleKeys = [
    'crisis',
    'events',
    'groups',
    'jobs',
    'knowledge',
    'marketplace',
    'matching',
    'mental_support',
    'organizations',
    'supply',
    'timebank',
    'warnings',
  ];

  static const List<String> _skillSuggestions = [
    'Handwerk',
    'Garten',
    'Kochen',
    'IT',
    'Erste Hilfe',
    'Babysitten',
    'Fahrdienst',
    'Übersetzung',
    'Reparatur',
    'Einkauf',
  ];

  static const List<String> _offerSuggestions = [
    'Werkzeug',
    'Hilfe',
    'Lift',
    'Tausch',
    'Verleih',
    'Wissen',
  ];

  static const List<String> _seekSuggestions = [
    'Werkzeug',
    'Mitfahrt',
    'Lernpartner',
    'Hilfe',
    'Tausch',
  ];

  static const List<String> _mentorSuggestions = [
    'Karriere',
    'Bewerbung',
    'Sprache',
    'Studium',
    'Familie',
    'Finanzen',
  ];

  static const List<String> _crisisSuggestions = [
    'Erste Hilfe',
    'Funk',
    'Logistik',
    'Sani',
    'Pflege',
    'Kinder',
    'Tiere',
  ];

  @override
  void initState() {
    super.initState();
    _future = ProfilesRepository.getMine().then((p) {
      if (p != null) _hydrate(p);
      return p;
    });
  }

  void _hydrate(Profile p) {
    _profile = p;
    _nameCtrl.text = p.name ?? '';
    _displayNameCtrl.text = p.displayName ?? '';
    _nicknameCtrl.text = p.nickname ?? '';
    _bioCtrl.text = p.bio ?? '';
    _usernameCtrl.text = p.username ?? '';
    _emailCtrl.text = p.email ?? '';
    _phoneCtrl.text = p.phone ?? '';
    _homepageCtrl.text = p.homepage ?? '';
    _addressCtrl.text = p.address ?? '';
    _cityCtrl.text = p.homeCity ?? '';
    _postalCtrl.text = p.homePostalCode ?? '';
    _country = (p.country ?? 'DE').toUpperCase();
    _lat = p.latitude ?? p.homeLat;
    _lng = p.longitude ?? p.homeLng;
    _radiusKm = p.notificationRadiusKm ?? p.radiusKm ?? 50;
    _skills = List<String>.from(p.skills);
    _offerTags = List<String>.from(p.offerTags);
    _seekTags = List<String>.from(p.seekTags);
    _mentorTopics = List<String>.from(p.mentorTopics);
    _crisisSkills = List<String>.from(p.crisisSkills);
    _preferredModules = p.preferredModules.toSet();
    _isMentor = p.isMentor;
    _isCrisisVolunteer = p.isCrisisVolunteer;
    _emergency = _parseEmergency(p);
    _quietEnabled = p.quietHoursEnabled;
    _quietStart = _parseTime(p.quietHoursStart);
    _quietEnd = _parseTime(p.quietHoursEnd);
    _profileVisibility = p.profileVisibility ?? 'neighbors';
    _showOnlineStatus = p.showOnlineStatus;
    _showLocation = p.showLocation;
    _showTrustScore = p.showTrustScore;
    _showActivity = p.showActivity;
    _showPhone = p.showPhone;
    _readReceipts = p.readReceipts;
    _allowMatching = p.allowMatching;
  }

  List<_EmergencyContact> _parseEmergency(Profile p) {
    final list = <_EmergencyContact>[];
    final raw = p.emergencyContacts;
    if (raw['list'] is List) {
      for (final e in raw['list'] as List) {
        if (e is Map) {
          list.add(_EmergencyContact(
            name: (e['name'] as String?) ?? '',
            phone: (e['phone'] as String?) ?? '',
            relation: (e['relation'] as String?) ?? '',
          ));
        }
      }
    } else {
      // Legacy: emergency_contact_1/2_name/phone
      if ((p.emergencyContact1Name ?? '').isNotEmpty ||
          (p.emergencyContact1Phone ?? '').isNotEmpty) {
        list.add(_EmergencyContact(
          name: p.emergencyContact1Name ?? '',
          phone: p.emergencyContact1Phone ?? '',
          relation: '',
        ));
      }
      if ((p.emergencyContact2Name ?? '').isNotEmpty ||
          (p.emergencyContact2Phone ?? '').isNotEmpty) {
        list.add(_EmergencyContact(
          name: p.emergencyContact2Name ?? '',
          phone: p.emergencyContact2Phone ?? '',
          relation: '',
        ));
      }
    }
    return list;
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

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _displayNameCtrl.dispose();
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _homepageCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGeneratedAvatar(String url) async {
    setState(() {
      _generatedAvatarUrl = url;
      _newAvatar = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text('profile.avatarChosen'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  /// Versucht nacheinander DiceBear-Stile bis einer HTTP-200 zurückgibt.
  /// Zeigt einen Lade-Indikator auf dem Button und eine Snackbar bei Fehler.
  Future<void> _generateAndVerifyAvatar(String userId) async {
    if (_isGeneratingAvatar) return;
    setState(() => _isGeneratingAvatar = true);
    try {
      for (int i = 0; i < AvatarGenerator.portraitStyleCount; i++) {
        final url = AvatarGenerator.portraitFor(userId, variantIndex: i);
        try {
          final resp = await http
              .head(Uri.parse(url))
              .timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200) {
            await _useGeneratedAvatar(url);
            return;
          }
        } catch (_) {
          continue;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('profile.avatarGenerateFailed'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.ink)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAvatar = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    // R6: Avatar 400px reicht für 2x-Retina-Display, viel kleinere Upload.
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (picked == null) return;
    setState(() => _newAvatar = File(picked.path));
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _newCover = File(picked.path));
  }

  Future<String?> _uploadImage({
    required File file,
    required String bucket,
    required String prefix,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      // Bug-Fix: ext robust extrahieren — Kamera-Files haben oft keine
      // Extension, dann fällt jpg als Default ein.
      final raw = file.path.split('.').last.toLowerCase();
      final ext = (raw.length <= 4 && raw.isNotEmpty) ? raw : 'jpg';
      final contentType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      final path =
          '$uid/$prefix-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await sb.storage.from(bucket).upload(
            path,
            file,
            // contentType ist PFLICHT für Supabase-Storage (sonst wird
            // gelegentlich "octet-stream" als MIME genommen → Web zeigt
            // den Avatar nicht an).
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      return sb.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      // Fehler NICHT mehr silent — User sieht Snackbar mit Fail-Reason.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('uploads.failed'.tr(namedArgs: {'e': '$e'}),
              style: AppTypography.body(size: 12, color: AppColors.ink)),
        ));
      }
      return null;
    }
  }

  // Generierten Avatar (Identicon/KI) im eigenen Storage persistieren.
  // WICHTIG: ProfilesRepository.update akzeptiert nur Supabase-Storage-URLs
  // (Sicherheits-Filter). Externe Generator-URLs (dicebear/pollinations)
  // wurden vorher beim Speichern still verworfen → Profilbild ließ sich nicht
  // ändern. Jetzt laden wir das Bild herunter und legen es im avatars-Bucket
  // ab; gespeichert wird die Storage-URL (passiert den Filter, kein externer
  // Host-Abhängigkeit, kein Broken-Image wenn der Generator mal down ist).
  Future<String?> _uploadGeneratedAvatar(String sourceUrl) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final resp = await http
          .get(Uri.parse(sourceUrl))
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      final ct = resp.headers['content-type'] ?? '';
      final isPng = ct.contains('png') || sourceUrl.contains('dicebear');
      final ext = isPng ? 'png' : 'jpg';
      final contentType = isPng ? 'image/png' : 'image/jpeg';
      final path =
          '$uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await sb.storage.from('avatars').uploadBinary(
            path,
            resp.bodyBytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      return sb.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('uploads.failed'.tr(namedArgs: {'e': '$e'}),
              style: AppTypography.body(size: 12, color: AppColors.ink)),
        ));
      }
      return null;
    }
  }

  Future<void> _useGPS() async {
    try {
      final pos = await LocationService.getCurrentPosition(
          accuracy: LocationAccuracy.medium);
      if (!mounted) return;
      final anon = LocationAnonymizer.fuzzy(pos.latitude, pos.longitude);
      setState(() {
        _lat = anon.lat;
        _lng = anon.lng;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('profile.gpsCaptured'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('$e',
            style:
                AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
    }
  }

  Future<void> _save() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _saving = true);

    // Empty-String → null Helper. DB-Constraints (chk_profiles_phone_format,
    // chk_profiles_email_format, chk_profiles_avatar_url) lassen NULL durch,
    // werfen aber bei einem leeren String "" weil das weder NULL noch der
    // erwartete Format ist. Vorher: Speichern fehlgeschlagen sobald Telefon
    // leer war.
    String? n(String s) => s.trim().isEmpty ? null : s.trim();

    final patch = <String, dynamic>{
      'name': n(_nameCtrl.text),
      'display_name': n(_displayNameCtrl.text),
      'nickname': n(_nicknameCtrl.text),
      'bio': n(_bioCtrl.text),
      'username': n(_usernameCtrl.text),
      'phone': n(_phoneCtrl.text),
      'homepage': n(_homepageCtrl.text),
      'address': n(_addressCtrl.text),
      'home_city': n(_cityCtrl.text),
      'home_postal_code': n(_postalCtrl.text),
      'country': _country,
      if (_lat != null) 'latitude': _lat,
      if (_lng != null) 'longitude': _lng,
      if (_lat != null) 'home_lat': _lat,
      if (_lng != null) 'home_lng': _lng,
      'radius_km': _radiusKm,
      'notification_radius_km': _radiusKm,
      'skills': _skills,
      'offer_tags': _offerTags,
      'seek_tags': _seekTags,
      'mentor_topics': _mentorTopics,
      'crisis_skills': _crisisSkills,
      'preferred_modules': _preferredModules.toList(),
      'is_mentor': _isMentor,
      'is_crisis_volunteer': _isCrisisVolunteer,
      'emergency_contacts': {
        'list': _emergency
            .where((c) => c.name.trim().isNotEmpty || c.phone.trim().isNotEmpty)
            .map((c) => {
                  'name': c.name.trim(),
                  'phone': c.phone.trim(),
                  'relation': c.relation.trim(),
                })
            .toList(),
      },
      'quiet_hours_enabled': _quietEnabled,
      'quiet_hours_start': _formatTime(_quietStart),
      'quiet_hours_end': _formatTime(_quietEnd),
      'profile_visibility': _profileVisibility,
      'show_online_status': _showOnlineStatus,
      'show_location': _showLocation,
      'show_trust_score': _showTrustScore,
      'show_activity': _showActivity,
      'show_phone': _showPhone,
      'read_receipts': _readReceipts,
      'allow_matching': _allowMatching,
    };

    // Avatar
    if (_newAvatar != null) {
      final url = await _uploadImage(
          file: _newAvatar!, bucket: 'avatars', prefix: 'avatar');
      if (!mounted) return;
      if (url == null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'profile.avatarUploadFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
          ),
        ));
        return;
      }
      patch['avatar_url'] = url;
    } else if (_generatedAvatarUrl != null) {
      final url = await _uploadGeneratedAvatar(_generatedAvatarUrl!);
      if (!mounted) return;
      if (url == null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'profile.avatarUploadFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
          ),
        ));
        return;
      }
      patch['avatar_url'] = url;
    }

    // Cover
    if (_newCover != null) {
      final url = await _uploadImage(
          file: _newCover!, bucket: 'covers', prefix: 'cover');
      if (url != null) patch['cover_url'] = url;
    }

    try {
      await ProfilesRepository.update(uid, patch);
      if (!mounted) return;
      ref.invalidate(myProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('profile.profileSaved'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('profile.saveFailed'.tr(namedArgs: {'error': '$e'}),
            style:
                AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default-Country auf Locale, falls noch nicht gesetzt.
    if (_profile == null) {
      _country = LocaleCountryService.forContext(context);
    }
    return DashboardScaffold(
      title: 'profile.editProfile'.tr(),
      currentRoute: '/dashboard/profile',
      body: SafeArea(
        child: FutureBuilder<Profile?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              );
            }
            final p = _profile ?? snap.data;
            final avatarUrl = _newAvatar != null
                ? null
                : (_generatedAvatarUrl ??
                    ((p?.avatarUrl ?? '').isEmpty ? null : p!.avatarUrl));
            final coverUrl = _newCover != null
                ? null
                : ((p?.coverUrl ?? '').isEmpty ? null : p!.coverUrl);
            return Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _Hero(
                          coverFile: _newCover,
                          coverUrl: coverUrl,
                          avatarFile: _newAvatar,
                          avatarUrl: avatarUrl,
                          onPickCover: _pickCover,
                          onPickAvatar: _pickAvatar,
                          isGeneratingAvatar: _isGeneratingAvatar,
                          onIdenticon: () => _useGeneratedAvatar(
                              AvatarGenerator.defaultFor(
                                  p?.id ?? _nameCtrl.text)),
                          onAiAvatar: () => _generateAndVerifyAvatar(
                              p?.id ?? _nameCtrl.text),
                        ),
                        _section(
                          title: 'profile.sectionBasic'.tr(),
                          icon: LucideIcons.user,
                          children: [
                            _Field(
                              label: 'profile.name'.tr(),
                              controller: _nameCtrl,
                              hint: 'profile.fullName'.tr(),
                              required: true,
                              minLength: 2,
                              maxLength: 80,
                            ),
                            _Field(
                              label: 'profile.displayName'.tr(),
                              controller: _displayNameCtrl,
                              hint: 'profile.displayNameHint'.tr(),
                              maxLength: 40,
                            ),
                            _Field(
                              label: 'profile.nickname'.tr(),
                              controller: _nicknameCtrl,
                              hint: 'profile.nicknameHint'.tr(),
                              minLength: 2,
                              maxLength: 32,
                            ),
                            _Field(
                              label: 'profile.username'.tr(),
                              controller: _usernameCtrl,
                              hint: 'profile.usernameHint'.tr(),
                              maxLength: 30,
                            ),
                            _Field(
                              label: 'profile.bio'.tr(),
                              controller: _bioCtrl,
                              hint: 'profile.bioHint'.tr(),
                              multiline: true,
                              maxLength: 500,
                            ),
                          ],
                        ),
                        _section(
                          title: 'profile.sectionContact'.tr(),
                          icon: LucideIcons.mapPin,
                          children: [
                            _Field(
                              label: 'profile.email'.tr(),
                              controller: _emailCtrl,
                              hint: 'profile.emailHint'.tr(),
                              enabled: false,
                            ),
                            _Field(
                              label: 'profile.phoneOptional'.tr(),
                              controller: _phoneCtrl,
                              hint: 'profile.phoneHint'.tr(),
                              keyboardType: TextInputType.phone,
                            ),
                            _Field(
                              label: 'profile.homepageLabel'.tr(),
                              controller: _homepageCtrl,
                              hint: 'profile.homepageHint'.tr(),
                              keyboardType: TextInputType.url,
                            ),
                            _Field(
                              label: 'profile.address'.tr(),
                              controller: _addressCtrl,
                              hint: 'profile.addressHint'.tr(),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _Field(
                                    label: 'profile.homeCity'.tr(),
                                    controller: _cityCtrl,
                                    hint: 'profile.homeCityHint'.tr(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Field(
                                    label: 'profile.postalCode'.tr(),
                                    controller: _postalCtrl,
                                    hint: 'profile.postalHint'.tr(),
                                  ),
                                ),
                              ],
                            ),
                            _label('profile.country'.tr()),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _country,
                              dropdownColor: AppColors.elevated,
                              style: AppTypography.body(
                                  size: 14, color: AppColors.ink),
                              decoration: _decoration(hint: ''),
                              items: _countries
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          'profile.countries.$c'.tr(),
                                          style: AppTypography.body(
                                              size: 14,
                                              color: AppColors.ink),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _country = v ?? 'DE'),
                            ),
                            const SizedBox(height: 14),
                            _GpsRow(
                              lat: _lat,
                              lng: _lng,
                              onCapture: _useGPS,
                              onClear: () => setState(() {
                                _lat = null;
                                _lng = null;
                              }),
                            ),
                            const SizedBox(height: 14),
                            _label('profile.radiusKm'
                                .tr(namedArgs: {'km': '$_radiusKm'})),
                            Slider(
                              value: _radiusKm.toDouble(),
                              min: 5,
                              max: 150,
                              divisions: 29,
                              activeColor: AppColors.amber,
                              inactiveColor:
                                  AppColors.amber.withValues(alpha: 0.2),
                              label: '$_radiusKm km',
                              onChanged: (v) =>
                                  setState(() => _radiusKm = v.round()),
                            ),
                          ],
                        ),
                        _section(
                          title: 'profile.sectionSkills'.tr(),
                          icon: LucideIcons.sparkles,
                          children: [
                            _TagChipEditor(
                              label: 'profile.skills'.tr(),
                              hint: 'profile.skillsHint'.tr(),
                              initial: _skills,
                              suggestions: _skillSuggestions,
                              onChanged: (v) => _skills = v,
                            ),
                            const SizedBox(height: 14),
                            _TagChipEditor(
                              label: 'profile.offerTags'.tr(),
                              hint: 'profile.offerTagsHint'.tr(),
                              initial: _offerTags,
                              suggestions: _offerSuggestions,
                              onChanged: (v) => _offerTags = v,
                            ),
                            const SizedBox(height: 14),
                            _TagChipEditor(
                              label: 'profile.seekTags'.tr(),
                              hint: 'profile.seekTagsHint'.tr(),
                              initial: _seekTags,
                              suggestions: _seekSuggestions,
                              onChanged: (v) => _seekTags = v,
                            ),
                            if (_isMentor) ...[
                              const SizedBox(height: 14),
                              _TagChipEditor(
                                label: 'profile.mentorTopics'.tr(),
                                hint: 'profile.mentorTopicsHint'.tr(),
                                initial: _mentorTopics,
                                suggestions: _mentorSuggestions,
                                onChanged: (v) => _mentorTopics = v,
                              ),
                            ],
                            if (_isCrisisVolunteer) ...[
                              const SizedBox(height: 14),
                              _TagChipEditor(
                                label: 'profile.crisisSkills'.tr(),
                                hint: 'profile.crisisSkillsHint'.tr(),
                                initial: _crisisSkills,
                                suggestions: _crisisSuggestions,
                                onChanged: (v) => _crisisSkills = v,
                              ),
                            ],
                            const SizedBox(height: 14),
                            _label('profile.preferredModules'.tr()),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _moduleKeys.map((mk) {
                                final on = _preferredModules.contains(mk);
                                return FilterChip(
                                  label: Text('profile.modules.$mk'.tr()),
                                  selected: on,
                                  onSelected: (s) => setState(() {
                                    if (s) {
                                      _preferredModules.add(mk);
                                    } else {
                                      _preferredModules.remove(mk);
                                    }
                                  }),
                                  backgroundColor: AppColors.elevated,
                                  selectedColor:
                                      AppColors.amber.withValues(alpha: 0.25),
                                  checkmarkColor: AppColors.amber,
                                  labelStyle: AppTypography.label(
                                      size: 10,
                                      color: on
                                          ? AppColors.amber
                                          : AppColors.inkSoft),
                                  side: BorderSide(
                                      color: on
                                          ? AppColors.amber
                                          : AppColors.line),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        _section(
                          title: 'profile.sectionToggles'.tr(),
                          icon: LucideIcons.toggleRight,
                          children: [
                            _ToggleTile(
                              label: 'profile.isMentor'.tr(),
                              subtitle: 'profile.isMentorHint'.tr(),
                              value: _isMentor,
                              onChanged: (v) =>
                                  setState(() => _isMentor = v),
                            ),
                            _ToggleTile(
                              label: 'profile.isCrisisVolunteer'.tr(),
                              subtitle: _isCrisisVolunteer
                                  ? 'profile.crisisInfo'.tr()
                                  : 'profile.isCrisisVolunteerHint'.tr(),
                              value: _isCrisisVolunteer,
                              onChanged: (v) =>
                                  setState(() => _isCrisisVolunteer = v),
                            ),
                            const SizedBox(height: 8),
                            _VerifiedBadges(profile: p),
                          ],
                        ),
                        _section(
                          title: 'profile.sectionEmergency'.tr(),
                          icon: LucideIcons.shield,
                          children: [
                            Text('profile.emergencyHint'.tr(),
                                style: AppTypography.caption()),
                            const SizedBox(height: 10),
                            ..._emergency.asMap().entries.map(
                                  (e) => _EmergencyEditor(
                                    contact: e.value,
                                    onChanged: (c) =>
                                        setState(() => _emergency[e.key] = c),
                                    onRemove: () =>
                                        setState(() => _emergency.removeAt(e.key)),
                                  ),
                                ),
                            if (_emergency.length < 5)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => setState(() =>
                                      _emergency.add(_EmergencyContact.empty())),
                                  icon: const Icon(LucideIcons.plus, size: 14),
                                  label:
                                      Text('profile.addEmergency'.tr()),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.amber,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        _section(
                          title: 'profile.sectionQuietHours'.tr(),
                          icon: LucideIcons.moon,
                          children: [
                            _ToggleTile(
                              label: 'profile.quietHoursEnabled'.tr(),
                              subtitle: 'profile.quietHoursHint'.tr(),
                              value: _quietEnabled,
                              onChanged: (v) =>
                                  setState(() => _quietEnabled = v),
                            ),
                            if (_quietEnabled)
                              Row(
                                children: [
                                  Expanded(
                                    child: _TimePickerField(
                                      label: 'profile.quietStart'.tr(),
                                      value: _quietStart,
                                      onPick: (t) =>
                                          setState(() => _quietStart = t),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TimePickerField(
                                      label: 'profile.quietEnd'.tr(),
                                      value: _quietEnd,
                                      onPick: (t) =>
                                          setState(() => _quietEnd = t),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        _section(
                          title: 'profile.sectionPrivacy'.tr(),
                          icon: LucideIcons.lock,
                          children: [
                            _label('profile.profileVisibility'.tr()),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _profileVisibility,
                              dropdownColor: AppColors.elevated,
                              style: AppTypography.body(
                                  size: 14, color: AppColors.ink),
                              decoration: _decoration(hint: ''),
                              items: const [
                                'public',
                                'neighbors',
                                'private',
                              ]
                                  .map((v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(
                                          'profile.visibility.$v'.tr(),
                                          style: AppTypography.body(
                                              size: 14,
                                              color: AppColors.ink),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(
                                  () => _profileVisibility = v ?? 'neighbors'),
                            ),
                            const SizedBox(height: 8),
                            _ToggleTile(
                              label: 'profile.showOnlineStatus'.tr(),
                              value: _showOnlineStatus,
                              onChanged: (v) =>
                                  setState(() => _showOnlineStatus = v),
                            ),
                            _ToggleTile(
                              label: 'profile.showLocation'.tr(),
                              value: _showLocation,
                              onChanged: (v) =>
                                  setState(() => _showLocation = v),
                            ),
                            _ToggleTile(
                              label: 'profile.showTrustScore'.tr(),
                              value: _showTrustScore,
                              onChanged: (v) =>
                                  setState(() => _showTrustScore = v),
                            ),
                            _ToggleTile(
                              label: 'profile.showActivity'.tr(),
                              value: _showActivity,
                              onChanged: (v) =>
                                  setState(() => _showActivity = v),
                            ),
                            _ToggleTile(
                              label: 'profile.showPhone'.tr(),
                              value: _showPhone,
                              onChanged: (v) =>
                                  setState(() => _showPhone = v),
                            ),
                            _ToggleTile(
                              label: 'profile.readReceipts'.tr(),
                              value: _readReceipts,
                              onChanged: (v) =>
                                  setState(() => _readReceipts = v),
                            ),
                            _ToggleTile(
                              label: 'profile.allowMatching'.tr(),
                              value: _allowMatching,
                              onChanged: (v) =>
                                  setState(() => _allowMatching = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                  _StickyFooter(
                    saving: _saving,
                    onCancel: _saving ? null : () => context.pop(),
                    onSave: _saving ? null : _save,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(title.toUpperCase(),
                  style: AppTypography.label(
                      size: 10, color: AppColors.amber)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text.toUpperCase(),
        style: AppTypography.label(size: 9, color: AppColors.mute),
      );

  InputDecoration _decoration({required String hint}) => InputDecoration(
        filled: true,
        fillColor: AppColors.elevated,
        hintText: hint,
        hintStyle: AppTypography.body(size: 13, color: AppColors.mute),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.bronze),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
// Hero (Cover + Avatar)
// ─────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({
    required this.coverFile,
    required this.coverUrl,
    required this.avatarFile,
    required this.avatarUrl,
    required this.onPickCover,
    required this.onPickAvatar,
    required this.onIdenticon,
    required this.onAiAvatar,
    this.isGeneratingAvatar = false,
  });

  final File? coverFile;
  final String? coverUrl;
  final File? avatarFile;
  final String? avatarUrl;
  final VoidCallback onPickCover;
  final VoidCallback onPickAvatar;
  final VoidCallback onIdenticon;
  final VoidCallback onAiAvatar;
  final bool isGeneratingAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          // Höhe = Cover (220) + Avatar-Überhang (44). Damit liegt der GESAMTE
          // Avatar innerhalb der Stack-Grenzen und ist voll antippbar. Vorher
          // hing er per bottom:-44 heraus → der untere Teil inkl. Kamera-Badge
          // war nicht klickbar (Flutter macht kein Hit-Test außerhalb der
          // Parent-Bounds, auch bei Clip.none).
          height: 264,
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onPickCover,
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: AppColors.elevated),
                    if (coverFile != null)
                      Image.file(coverFile!,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          cacheHeight: 400)
                    else if (coverUrl != null)
                      CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fadeInDuration: const Duration(milliseconds: 200),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.elevated,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.elevated,
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.imageOff,
                              size: 20, color: AppColors.mute),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.image,
                                size: 32, color: AppColors.mute),
                            const SizedBox(height: 6),
                            Text('profile.tapForCover'.tr(),
                                style: AppTypography.label(
                                    size: 10, color: AppColors.mute)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _RoundIconButton(
                icon: LucideIcons.camera,
                tooltip: 'identify.takePhoto'.tr(),
                onTap: onPickCover,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              // bottom:0 → Avatar sitzt am unteren Stack-Rand (innerhalb der
              // 264px), überlappt das Cover und bleibt vollständig antippbar.
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onPickAvatar,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          border: Border.all(
                              color: AppColors.voidColor, width: 3),
                          shape: BoxShape.circle,
                          image: avatarFile != null
                              ? DecorationImage(
                                  image: FileImage(avatarFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: avatarFile != null
                            ? null
                            : avatarUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: avatarUrl!,
                                      fadeInDuration: const Duration(
                                          milliseconds: 200),
                                      fit: BoxFit.cover,
                                      width: 88,
                                      height: 88,
                                      placeholder: (_, __) => Container(
                                        color: AppColors.elevated,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.elevated,
                                        alignment: Alignment.center,
                                        child: const Icon(LucideIcons.user,
                                            size: 36,
                                            color: AppColors.mute),
                                      ),
                                    ),
                                  )
                                : const Icon(LucideIcons.user,
                                    size: 36, color: AppColors.mute),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.bronze,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.voidColor, width: 2),
                          ),
                          child: const Icon(LucideIcons.camera,
                              size: 12, color: AppColors.voidColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onIdenticon,
                  icon: const Icon(LucideIcons.shapes, size: 14),
                  label: Text('profile.identicon'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tealSoft,
                    side: BorderSide(
                        color:
                            AppColors.tealSoft.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isGeneratingAvatar ? null : onAiAvatar,
                  icon: isGeneratingAvatar
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.amber,
                          ),
                        )
                      : const Icon(LucideIcons.sparkles, size: 14),
                  label: Text('profile.aiAvatar'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: BorderSide(
                        color: AppColors.amber.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  // a11y: Screenreader-Label + Long-Press-Tooltip für das sonst nackte Icon.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: AppColors.voidColor.withValues(alpha: 0.7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 14, color: AppColors.ink),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(
      message: tooltip!,
      child: Semantics(button: true, label: tooltip, child: btn),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Tag Chip Editor (wiederverwendbar)
// ─────────────────────────────────────────────────────────────────
class _TagChipEditor extends StatefulWidget {
  const _TagChipEditor({
    required this.label,
    required this.initial,
    required this.suggestions,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final List<String> initial;
  final List<String> suggestions;
  final String? hint;
  final void Function(List<String>) onChanged;

  @override
  State<_TagChipEditor> createState() => _TagChipEditorState();
}

class _TagChipEditorState extends State<_TagChipEditor> {
  late List<String> _tags;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return;
    if (_tags.contains(s)) return;
    setState(() {
      _tags.add(s);
      _ctrl.clear();
    });
    widget.onChanged(_tags);
  }

  void _remove(String t) {
    setState(() => _tags.remove(t));
    widget.onChanged(_tags);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.suggestions.where((s) => !_tags.contains(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(),
            style: AppTypography.label(size: 9, color: AppColors.mute)),
        const SizedBox(height: 6),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags
                  .map((t) => Chip(
                        label: Text(t,
                            style: AppTypography.label(
                                size: 10, color: AppColors.ink)),
                        backgroundColor:
                            AppColors.amber.withValues(alpha: 0.18),
                        side: BorderSide(
                            color: AppColors.amber.withValues(alpha: 0.4)),
                        deleteIcon:
                            const Icon(LucideIcons.x, size: 12),
                        deleteIconColor: AppColors.inkSoft,
                        onDeleted: () => _remove(t),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                onSubmitted: _add,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.elevated,
                  hintText: widget.hint ?? 'profile.addTagHint'.tr(),
                  hintStyle:
                      AppTypography.body(size: 13, color: AppColors.mute),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.bronze),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'common.add'.tr(),
              onPressed: () => _add(_ctrl.text),
              icon: const Icon(LucideIcons.plus,
                  size: 18, color: AppColors.amber),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.elevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: remaining
                .map((s) => ActionChip(
                      label: Text('+ $s',
                          style: AppTypography.label(
                              size: 9, color: AppColors.inkSoft)),
                      backgroundColor: AppColors.elevated,
                      side: const BorderSide(color: AppColors.line),
                      onPressed: () => _add(s),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// GPS Row
// ─────────────────────────────────────────────────────────────────
class _GpsRow extends StatelessWidget {
  const _GpsRow({
    required this.lat,
    required this.lng,
    required this.onCapture,
    required this.onClear,
  });

  final double? lat;
  final double? lng;
  final VoidCallback onCapture;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final has = lat != null && lng != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.locateFixed,
              size: 16, color: AppColors.tealSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              has
                  ? 'profile.gpsCoord'.tr(namedArgs: {
                      'lat': lat!.toStringAsFixed(4),
                      'lng': lng!.toStringAsFixed(4),
                    })
                  : 'profile.noGps'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.inkSoft),
            ),
          ),
          if (has)
            IconButton(
              tooltip: 'common.close'.tr(),
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(LucideIcons.x,
                  size: 14, color: AppColors.mute),
            ),
          TextButton.icon(
            onPressed: onCapture,
            icon: const Icon(LucideIcons.mapPin, size: 14),
            label: Text(has
                ? 'profile.refreshGps'.tr()
                : 'profile.captureGps'.tr()),
            style: TextButton.styleFrom(foregroundColor: AppColors.amber),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Emergency Contact
// ─────────────────────────────────────────────────────────────────
class _EmergencyContact {
  _EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });
  factory _EmergencyContact.empty() =>
      _EmergencyContact(name: '', phone: '', relation: '');
  String name;
  String phone;
  String relation;
}

class _EmergencyEditor extends StatefulWidget {
  const _EmergencyEditor({
    required this.contact,
    required this.onChanged,
    required this.onRemove,
  });
  final _EmergencyContact contact;
  final void Function(_EmergencyContact) onChanged;
  final VoidCallback onRemove;

  @override
  State<_EmergencyEditor> createState() => _EmergencyEditorState();
}

class _EmergencyEditorState extends State<_EmergencyEditor> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _rel;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.contact.name);
    _phone = TextEditingController(text: widget.contact.phone);
    _rel = TextEditingController(text: widget.contact.relation);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rel.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_EmergencyContact(
      name: _name.text,
      phone: _phone.text,
      relation: _rel.text,
    ));
  }

  InputDecoration _dec(String hint) => InputDecoration(
        filled: true,
        fillColor: AppColors.elevated,
        hintText: hint,
        hintStyle: AppTypography.body(size: 12, color: AppColors.mute),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.bronze),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.deep,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  onChanged: (_) => _emit(),
                  style:
                      AppTypography.body(size: 13, color: AppColors.ink),
                  decoration: _dec('profile.emergencyName'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'common.delete'.tr(),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(LucideIcons.trash2,
                    size: 16, color: AppColors.herzrotWarm),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _phone,
                  onChanged: (_) => _emit(),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-()]')),
                  ],
                  style:
                      AppTypography.body(size: 13, color: AppColors.ink),
                  decoration: _dec('profile.emergencyPhone'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rel,
                  onChanged: (_) => _emit(),
                  style:
                      AppTypography.body(size: 13, color: AppColors.ink),
                  decoration: _dec('profile.emergencyRelation'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Time Picker Field
// ─────────────────────────────────────────────────────────────────
class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onPick,
  });
  final String label;
  final TimeOfDay? value;
  final void Function(TimeOfDay) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(label.toUpperCase(),
            style: AppTypography.label(size: 9, color: AppColors.mute)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value ?? const TimeOfDay(hour: 22, minute: 0),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.clock,
                    size: 14, color: AppColors.mute),
                const SizedBox(width: 8),
                Text(
                  value == null
                      ? '--:--'
                      : '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Toggle Tile
// ─────────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: AppTypography.caption()),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.amber,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Verified Badges (readonly)
// ─────────────────────────────────────────────────────────────────
class _VerifiedBadges extends StatelessWidget {
  const _VerifiedBadges({required this.profile});
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _badge('profile.verifiedEmail'.tr(), p.verifiedEmail),
        _badge('profile.verifiedPhone'.tr(), p.verifiedPhone),
        _badge('profile.verifiedCommunity'.tr(), p.verifiedCommunity),
        _badge('profile.donorTier'.tr(namedArgs: {'tier': '${p.donorTier}'}),
            p.donorTier > 0),
      ],
    );
  }

  Widget _badge(String label, bool on) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: on
            ? AppColors.leben.withValues(alpha: 0.15)
            : AppColors.elevated,
        border: Border.all(
            color: on
                ? AppColors.leben.withValues(alpha: 0.5)
                : AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? LucideIcons.badgeCheck : LucideIcons.circle,
              size: 10,
              color: on ? AppColors.lebenSoft : AppColors.mute),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.label(
                  size: 9,
                  color: on ? AppColors.lebenSoft : AppColors.mute)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Sticky Footer
// ─────────────────────────────────────────────────────────────────
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });
  final bool saving;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.deep,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    side: const BorderSide(color: AppColors.line),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('common.cancel'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.voidColor),
                        )
                      : const Icon(LucideIcons.save, size: 16),
                  label: Text(saving
                      ? 'profile.saving'.tr()
                      : 'common.save'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Field (Validation)
// ─────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.multiline = false,
    this.keyboardType,
    this.required = false,
    this.minLength,
    this.maxLength,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool multiline;
  final TextInputType? keyboardType;
  final bool required;
  final int? minLength;
  final int? maxLength;
  final bool enabled;

  String? _defaultValidator(String? v) {
    final s = v?.trim() ?? '';
    if (required && s.isEmpty) {
      return 'profile.fieldRequired'.tr(namedArgs: {'field': label});
    }
    if (minLength != null && s.isNotEmpty && s.length < minLength!) {
      return 'profile.minChars'.tr(namedArgs: {'n': '$minLength'});
    }
    if (maxLength != null && s.length > maxLength!) {
      return 'profile.maxChars'.tr(namedArgs: {'n': '$maxLength'});
    }
    if (keyboardType == TextInputType.url &&
        s.isNotEmpty &&
        !RegExp(r'^https?://').hasMatch(s)) {
      return 'profile.urlMustStart'.tr();
    }
    // Telefon-Format: nur prüfen wenn gefüllt (Feld ist optional).
    if (keyboardType == TextInputType.phone && s.isNotEmpty) {
      final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 5 || !RegExp(r'^[+0-9 ()/\-]{5,}$').hasMatch(s)) {
        return 'validate.phone'.tr();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label.toUpperCase(),
                  style: AppTypography.label(size: 9, color: AppColors.mute)),
              if (required) ...[
                const SizedBox(width: 4),
                Text('*',
                    style: AppTypography.label(
                        size: 9, color: AppColors.herzrotWarm)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: multiline ? 5 : 1,
            minLines: multiline ? 3 : 1,
            keyboardType: keyboardType,
            enabled: enabled,
            validator: _defaultValidator,
            style: AppTypography.body(
                size: 14,
                color: enabled ? AppColors.ink : AppColors.mute),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.elevated,
              hintText: hint,
              hintStyle:
                  AppTypography.body(size: 13, color: AppColors.mute),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.bronze),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.herzrot),
              ),
              errorStyle: AppTypography.label(
                  size: 10, color: AppColors.herzrotWarm),
            ),
          ),
        ],
      ),
    );
  }
}
