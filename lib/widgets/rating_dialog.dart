import 'package:flutter/material.dart';
import 'package:mensaena/config/theme.dart';

class RatingDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final void Function(int rating, String? comment) onSubmit;

  const RatingDialog({
    super.key,
    this.title = 'Bewertung abgeben',
    this.subtitle,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required void Function(int rating, String? comment) onSubmit,
  }) {
    return showDialog(
      context: context,
      builder: (_) => RatingDialog(title: title, subtitle: subtitle, onSubmit: onSubmit),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  static const _labels = ['', 'Mangelhaft', 'Ausreichend', 'Gut', 'Sehr gut', 'Hervorragend'];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(widget.subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: AppColors.warning,
                  size: 40,
                ),
              ),
            )),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 4),
            Text(_labels[_rating], style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: [Colors.transparent, AppColors.error, AppColors.warning, AppColors.primary500, AppColors.success, AppColors.success][_rating],
            )),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Dein Kommentar (optional)...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _rating == 0 || _submitting ? null : () async {
            setState(() => _submitting = true);
            widget.onSubmit(_rating, _commentCtrl.text.trim().isNotEmpty ? _commentCtrl.text.trim() : null);
            Navigator.pop(context);
          },
          child: _submitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Bewerten'),
        ),
      ],
    );
  }
}
