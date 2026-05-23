import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/geocoding_service.dart';

/// SKILL: mensaena-design + mensaena-features
/// Autocomplete-Field gegen Nominatim. Liefert ausgewaehlte Adresse +
/// Koordinaten via [onSelected]. Debounce 500ms — respektiert Nominatim-Limit.
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    required this.controller,
    required this.onSelected,
    this.label = 'Adresse',
    this.hint = 'Strasse, PLZ oder Ort',
    super.key,
  });

  final TextEditingController controller;
  final void Function(AddressSuggestion) onSelected;
  final String label;
  final String hint;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState
    extends State<AddressAutocompleteField> {
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = const [];
  bool _loading = false;
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Sheet schliessen nach kurzem Delay (damit Tap-on-Suggestion durchgeht)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showSuggestions = false);
      });
    } else {
      setState(() => _showSuggestions = true);
    }
  }

  void _onTextChanged() {
    final q = widget.controller.text;
    _debounce?.cancel();
    if (q.trim().length < 3) {
      if (mounted) setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final results = await GeocodingService.search(query: q);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon:
                const Icon(LucideIcons.mapPin, size: 16, color: AppColors.mute),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.amber,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (final s in _suggestions)
                  InkWell(
                    onTap: () {
                      widget.controller.text = s.shortLabel;
                      widget.onSelected(s);
                      FocusScope.of(context).unfocus();
                      setState(() => _showSuggestions = false);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.mapPin,
                              size: 12, color: AppColors.mute),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(s.shortLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                        size: 13,
                                        color: AppColors.ink,
                                        weight: FontWeight.w600)),
                                Text(
                                  s.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    '© OpenStreetMap Nominatim',
                    style: AppTypography.label(size: 7, color: AppColors.mute),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
