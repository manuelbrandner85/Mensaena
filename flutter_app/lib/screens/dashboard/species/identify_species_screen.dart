/// SKILL: mensaena-features + mensaena-design
/// Foto-Bestimmung von Tieren/Pflanzen via iNaturalist Computer Vision API.
/// Erreichbar von Animals + Wissen-Modulen.
library;

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/inaturalist_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';

class IdentifySpeciesScreen extends ConsumerStatefulWidget {
  const IdentifySpeciesScreen({super.key});

  @override
  ConsumerState<IdentifySpeciesScreen> createState() =>
      _IdentifySpeciesScreenState();
}

class _IdentifySpeciesScreenState
    extends ConsumerState<IdentifySpeciesScreen> {
  File? _photo;
  bool _loading = false;
  List<INaturalistIdentificationGuess> _guesses = const [];

  Future<void> _pickAndIdentify(ImageSource source) async {
    final picker = ImagePicker();
    final pic = await picker.pickImage(
        source: source, maxWidth: 1280, imageQuality: 88);
    if (pic == null) return;
    final file = File(pic.path);
    setState(() {
      _photo = file;
      _loading = true;
      _guesses = const [];
    });
    try {
      final results = await INaturalistService.identifyFromPhoto(file);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _guesses = results;
      });
    } on IdentificationException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(e.message,
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'identify.title'.tr(),
      currentRoute: '/dashboard/identify',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            EditorialModuleHeader(
              metaIndex: '§ 25',
              metaCategory: 'identify.section'.tr(),
              title: 'identify.title'.tr(),
              subtitle: 'identify.subtitle'.tr(),
            ),
            const SizedBox(height: 20),
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_photo!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    cacheHeight: 600),
              )
            else
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.imagePlus,
                        size: 48,
                        color: AppColors.mute.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    Text('identify.noPhoto'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.mute)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: Text('identify.takePhoto'.tr()),
                    onPressed: _loading
                        ? null
                        : () => _pickAndIdentify(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.image, size: 16),
                    label: Text('identify.fromGallery'.tr()),
                    onPressed: _loading
                        ? null
                        : () => _pickAndIdentify(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.bronze),
                ),
              )
            else if (_guesses.isNotEmpty) ...[
              Text('identify.results'.tr(),
                  style: AppTypography.label(size: 10)),
              const SizedBox(height: 8),
              for (final g in _guesses) _GuessTile(guess: g),
              const SizedBox(height: 16),
              Text(
                'identify.disclaimer'.tr(),
                style: AppTypography.caption(),
              ),
            ] else if (_photo != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('identify.noResults'.tr(),
                      style: AppTypography.body(
                          size: 13, color: AppColors.mute)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuessTile extends StatelessWidget {
  const _GuessTile({required this.guess});
  final INaturalistIdentificationGuess guess;

  Future<void> _openWiki() async {
    final q = Uri.encodeComponent(guess.scientificName);
    try {
      await launchUrl(
          Uri.parse('https://www.inaturalist.org/taxa/${guess.taxonId}'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(
            Uri.parse('https://en.wikipedia.org/wiki/$q'),
            mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final scorePct = (guess.score * 100).toStringAsFixed(0);
    return InkWell(
      onTap: _openWiki,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.leben.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$scorePct%',
                  style: AppTypography.mono(
                      size: 13,
                      color: AppColors.lebenSoft,
                      weight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guess.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  if (guess.scientificName.isNotEmpty)
                    Text(guess.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                                size: 11, color: AppColors.inkSoft)
                            .copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const Icon(LucideIcons.externalLink,
                size: 14, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}
