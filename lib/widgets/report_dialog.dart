import 'package:flutter/material.dart';
import 'package:mensaena/config/theme.dart';

/// Reusable dialog for reporting any content (posts, comments, messages, profiles).
/// Returns a [ReportResult] if the user submits, or null if cancelled.
class ReportDialog extends StatefulWidget {
  final String contentType;
  final String contentId;

  const ReportDialog({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  /// Shows the dialog and returns the result.
  static Future<ReportResult?> show(
    BuildContext context, {
    required String contentType,
    required String contentId,
  }) {
    return showDialog<ReportResult>(
      context: context,
      builder: (_) => ReportDialog(
        contentType: contentType,
        contentId: contentId,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final _detailsController = TextEditingController();

  static const List<String> _reasons = [
    'Spam',
    'Beleidigung',
    'Gewalt',
    'Betrug',
    'Falschinformation',
    'Sonstiges',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.flag_outlined, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text('Inhalt melden'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Warum moechtest du diesen Inhalt melden?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // Reason chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedReason = selected ? reason : null;
                    });
                  },
                  selectedColor: AppColors.error.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.error : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.error.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Details text field
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                hintText: 'Weitere Details (optional)...',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  Navigator.pop(
                    context,
                    ReportResult(
                      reason: _selectedReason!,
                      details: _detailsController.text.trim().isNotEmpty
                          ? _detailsController.text.trim()
                          : null,
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          child: const Text('Melden'),
        ),
      ],
    );
  }
}

class ReportResult {
  final String reason;
  final String? details;

  const ReportResult({required this.reason, this.details});
}
