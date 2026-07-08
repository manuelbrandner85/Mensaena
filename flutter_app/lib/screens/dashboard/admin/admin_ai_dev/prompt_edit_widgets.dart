part of '../admin_ai_dev_screen.dart';

// Ergebnis des Edit-Sheets: der (bearbeitete) Prompt + die gewählten Optionen.
class _PromptEditResult {
  const _PromptEditResult({
    required this.instruction,
    required this.awaitReview,
    required this.planMode,
    required this.wantScreens,
    required this.model,
    this.epicId,
  });
  final String instruction;
  final bool awaitReview;
  final bool planMode;
  final bool wantScreens;
  final String model; // 'standard' (Sonnet 5) | 'thorough' (Opus 4.8)
  final String? epicId; // optionale Roadmap-Zuordnung
}

// Wiederverwendbares Sheet zum Bearbeiten eines Prompts vor dem Absenden.
// Genutzt für: Vorschlag annehmen (bearbeitbar), mehrere Vorschläge bündeln,
// und fehlgeschlagene Aufträge mit angepasstem Prompt neu starten. Bietet
// dieselben Optionen wie das freie Eingabefeld (Review-Gate, Plan, Screenshots).
class _PromptEditSheet extends StatefulWidget {
  const _PromptEditSheet({
    required this.title,
    required this.confirmLabel,
    required this.initialText,
    this.hint,
    this.epics = const [],
    this.initialEpicId,
  });
  final String title;
  final String confirmLabel;
  final String initialText;
  final String? hint;
  final List<Map<String, dynamic>> epics;
  final String? initialEpicId;

  @override
  State<_PromptEditSheet> createState() => _PromptEditSheetState();
}

class _PromptEditSheetState extends State<_PromptEditSheet> {
  late final TextEditingController _ctrl;
  bool _awaitReview = false;
  bool _planMode = false;
  bool _wantScreens = false;
  String _model = 'standard'; // standard (Sonnet 5) | thorough (Opus 4.8)
  String? _epicId;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _epicId = widget.initialEpicId;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('adminDev.edit.emptyPrompt'.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    Navigator.of(context).pop(_PromptEditResult(
      instruction: text,
      awaitReview: _awaitReview,
      planMode: _planMode,
      wantScreens: _wantScreens,
      model: _model,
      epicId: _epicId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.pencil, size: 18, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.lightInk,
                          weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: AppColors.lightMute,
                  ),
                ],
              ),
              if (widget.hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.hint!,
                  style:
                      AppTypography.body(size: 12, color: AppColors.lightMute),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 12,
                minLines: 4,
                style: AppTypography.body(size: 13, color: AppColors.lightInk),
                decoration: InputDecoration(
                  labelText: 'adminDev.edit.promptLabel'.tr(),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppColors.lightElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MiniToggle(
                label: 'adminDev.reviewBeforeMerge'.tr(),
                value: _awaitReview,
                onChanged: (v) => setState(() => _awaitReview = v),
              ),
              _MiniToggle(
                label: 'adminDev.plan.toggle'.tr(),
                value: _planMode,
                onChanged: (v) => setState(() => _planMode = v),
              ),
              _MiniToggle(
                label: 'adminDev.screens.toggle'.tr(),
                value: _wantScreens,
                onChanged: (v) => setState(() => _wantScreens = v),
              ),
              const SizedBox(height: 10),
              Text('adminDev.model.label'.tr().toUpperCase(),
                  style: AppTypography.label(
                      size: 9, color: AppColors.lightMute)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final m in const ['standard', 'thorough'])
                    ChoiceChip(
                      label: Text('adminDev.model.$m'.tr(),
                          style: AppTypography.label(size: 10)),
                      selected: _model == m,
                      onSelected: (_) => setState(() => _model = m),
                      selectedColor: AppColors.teal.withValues(alpha: 0.25),
                      backgroundColor: AppColors.lightRaised,
                    ),
                ],
              ),
              if (widget.epics.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('adminDev.roadmap.assignLabel'.tr().toUpperCase(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.lightMute)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text('adminDev.roadmap.noEpic'.tr(),
                          style: AppTypography.label(size: 10)),
                      selected: _epicId == null,
                      onSelected: (_) => setState(() => _epicId = null),
                      selectedColor: AppColors.teal.withValues(alpha: 0.25),
                      backgroundColor: AppColors.lightRaised,
                    ),
                    for (final e in widget.epics)
                      ChoiceChip(
                        label: Text(e['title'] as String? ?? '',
                            style: AppTypography.label(size: 10)),
                        selected: _epicId == e['id'],
                        onSelected: (_) =>
                            setState(() => _epicId = e['id'] as String?),
                        selectedColor: AppColors.teal.withValues(alpha: 0.25),
                        backgroundColor: AppColors.lightRaised,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: Text(widget.confirmLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.body(size: 12, color: AppColors.lightMute)),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.teal,
          ),
        ),
      ],
    );
  }
}
