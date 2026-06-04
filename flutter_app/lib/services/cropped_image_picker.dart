import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme/app_colors.dart';

/// Picker + ucrop in einem Schritt. Ersetzt direkte image_picker.pickImage()-
/// Aufrufe für Avatare, Cover, Profil-/Post-/Marktplatz-Fotos. Wenn der
/// User abbricht (kein Bild gewählt ODER Crop abgebrochen), gibt die
/// Methode null zurück — die Aufrufer-Logik bleibt unverändert.
///
/// Vorteil ggü. nur image_picker:
///   • Nutzer schneidet den Bildausschnitt vor Upload selbst → keine schiefen
///     Avatare/Cover mehr.
///   • Aspect-Ratio kann pro Use-Case fixiert werden (Avatar 1:1, Cover 16:9).
///   • Ein einziger Eintrittspunkt für Bild-Qualität (Quality, Max-Pixel-
///     Größe) — leicht zu tunen.
class CroppedImagePicker {
  const CroppedImagePicker._();

  static final ImagePicker _picker = ImagePicker();

  /// Avatare: quadratisch, 512x512 Output, gute Qualität.
  static Future<String?> pickAvatar(BuildContext context,
      {ImageSource source = ImageSource.gallery}) {
    return _pickAndCrop(
      context,
      source: source,
      pickMaxWidth: 1200,
      pickMaxHeight: 1200,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      lockAspect: true,
      maxOutputPx: 512,
      compressQuality: 85,
      toolbarTitleKey: 'profile.editAvatar',
    );
  }

  /// Cover: 16:9, max 1600px Breite.
  static Future<String?> pickCover(BuildContext context,
      {ImageSource source = ImageSource.gallery}) {
    return _pickAndCrop(
      context,
      source: source,
      pickMaxWidth: 2400,
      pickMaxHeight: 1350,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      lockAspect: true,
      maxOutputPx: 1600,
      compressQuality: 82,
      toolbarTitleKey: 'profile.editCover',
    );
  }

  /// Allgemeines Foto (Post, Marktplatz, Event …): freier Ausschnitt,
  /// max 1600px lange Seite.
  static Future<String?> pickFreeform(BuildContext context,
      {ImageSource source = ImageSource.gallery}) {
    return _pickAndCrop(
      context,
      source: source,
      pickMaxWidth: 2400,
      pickMaxHeight: 2400,
      aspectRatio: null,
      lockAspect: false,
      maxOutputPx: 1600,
      compressQuality: 82,
      toolbarTitleKey: 'common.crop',
    );
  }

  static Future<String?> _pickAndCrop(
    BuildContext context, {
    required ImageSource source,
    required int pickMaxWidth,
    required int pickMaxHeight,
    required CropAspectRatio? aspectRatio,
    required bool lockAspect,
    required int maxOutputPx,
    required int compressQuality,
    required String toolbarTitleKey,
  }) async {
    final raw = await _picker.pickImage(
      source: source,
      maxWidth: pickMaxWidth.toDouble(),
      maxHeight: pickMaxHeight.toDouble(),
      imageQuality: 90,
    );
    if (raw == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: raw.path,
      aspectRatio: aspectRatio,
      compressQuality: compressQuality,
      maxWidth: maxOutputPx,
      maxHeight: maxOutputPx,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: toolbarTitleKey.tr(),
          toolbarColor: AppColors.deep,
          toolbarWidgetColor: AppColors.ink,
          backgroundColor: AppColors.voidColor,
          activeControlsWidgetColor: AppColors.bronze,
          statusBarColor: AppColors.deep,
          lockAspectRatio: lockAspect,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: toolbarTitleKey.tr(),
          aspectRatioLockEnabled: lockAspect,
        ),
      ],
    );
    return cropped?.path;
  }
}
