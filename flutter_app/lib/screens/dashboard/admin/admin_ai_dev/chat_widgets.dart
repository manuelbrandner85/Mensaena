part of '../admin_ai_dev_screen.dart';

// ── Input Bar ─────────────────────────────────────────────────────────────────

// Vollständiger Pool aller Auftrags-Vorlagen. Bei jedem Tap werden 4 zufällige
// aus diesem Pool angezeigt — so erscheinen nie zweimal dieselben Chips.
const _allTemplateKeys = [
  'i18nCheck', 'perfCheck', 'darkMode', 'a11y',
  'onboarding', 'security', 'animations', 'crashes',
  'dependencies', 'notifications', 'offline', 'emptyStates',
];

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.ctrl,
    required this.sending,
    required this.placeholder,
    required this.onSend,
    required this.images,
    required this.onAttach,
    required this.onRemoveImage,
    required this.awaitReview,
    required this.onToggleReview,
    required this.wantScreens,
    required this.onToggleScreens,
    required this.planMode,
    required this.onTogglePlan,
    required this.onTemplate,
    required this.existingInstructions,
  });
  final TextEditingController ctrl;
  final bool sending;
  final String placeholder;
  final Future<void> Function([String?]) onSend;
  final List<File> images;
  final VoidCallback onAttach;
  final void Function(int) onRemoveImage;
  final bool awaitReview;
  final void Function(bool) onToggleReview;
  final bool wantScreens;
  final void Function(bool) onToggleScreens;
  final bool planMode;
  final void Function(bool) onTogglePlan;
  final void Function(String) onTemplate;
  // Für Duplikat-Erkennung (simple Keyword-Überschneidung).
  final List<String> existingInstructions;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  late List<String> _visibleTemplates;

  // Voice-Eingabe (Speech-to-Text).
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  String _baseTextBeforeListen = '';

  // Eingabeleiste standardmäßig eingeklappt: unten nur das Eingabefeld. Tippt
  // der Admin ins Feld, klappt der volle Funktionsumfang aus (Vorlagen,
  // Schalter, Anhänge, Mikro). Manuelles Einklappen über den Chevron oben.
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _visibleTemplates = _pickTemplates();
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  // Mikrofon: Diktat starten/stoppen. Erkannter Text wird ans Eingabefeld
  // angehängt (an das, was vor dem Start drinstand).
  Future<void> _toggleListening() async {
    final localeId = context.locale.toString().replaceAll('_', '-');
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    }
    if (!_speechAvailable) {
      if (mounted) {
        AppSnackBar.info(context, 'adminDev.voice.unavailable'.tr());
      }
      return;
    }
    _baseTextBeforeListen = widget.ctrl.text;
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: localeId),
      onResult: (r) {
        final spoken = r.recognizedWords;
        final sep = _baseTextBeforeListen.isEmpty ||
                _baseTextBeforeListen.endsWith(' ')
            ? ''
            : ' ';
        widget.ctrl.text = '$_baseTextBeforeListen$sep$spoken';
        widget.ctrl.selection =
            TextSelection.collapsed(offset: widget.ctrl.text.length);
        setState(() {});
      },
    );
  }

  // Wählt 4 zufällige Templates aus dem Pool.
  List<String> _pickTemplates() {
    final pool = List<String>.from(_allTemplateKeys)..shuffle(Random());
    return pool.take(4).toList();
  }

  void _onTemplateTap(String key) {
    widget.onTemplate('adminDev.templateTexts.$key'.tr());
    // Nach jedem Tap neuen Mix anzeigen.
    setState(() => _visibleTemplates = _pickTemplates());
  }

  // Einfache Duplikat-Warnung: prüft ob der Eingabe-Text signifikante
  // Wortüberschneidung mit einem bestehenden Auftrag hat.
  String? _duplicateWarning(String text) =>
      similarInstruction(text, widget.existingInstructions);

  // Kompakte Schalter-Zeile (Icon + Label + Switch).
  Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.lightMute),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: AppTypography.body(size: 11, color: AppColors.lightMute)),
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

  @override
  Widget build(BuildContext context) {
    final inputText = widget.ctrl.text;
    final dupWarning = _duplicateWarning(inputText);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.lightLine)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapse-Handle — nur sichtbar wenn ausgeklappt. Tap klappt ein.
          if (_expanded)
            Center(
              child: InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _expanded = false);
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 24, vertical: 2),
                  child: Icon(LucideIcons.chevronDown,
                      size: 20, color: AppColors.lightMute),
                ),
              ),
            ),
          // Vorlagen-Chips (rotierender Pool — ändert sich nach jedem Tap).
          if (_expanded)
            SizedBox(
              height: 30,
              child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final k in _visibleTemplates)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('adminDev.templates.$k'.tr(),
                          style: AppTypography.body(
                              size: 11, color: AppColors.teal)),
                      backgroundColor: AppColors.teal.withValues(alpha: 0.07),
                      side: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.25)),
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.sending ? null : () => _onTemplateTap(k),
                    ),
                  ),
              ],
            ),
          ),
          // Duplikat-Warnung: nur wenn starke Überschneidung mit bestehendem Auftrag.
          if (_expanded && dupWarning != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle,
                      size: 13, color: AppColors.amberDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'adminDev.duplicateWarning'
                          .tr(namedArgs: {'task': dupWarning}),
                      style: AppTypography.body(
                          size: 10, color: AppColors.amberDeep),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Angehängte Screenshots (Vorschau + Entfernen).
          if (_expanded && widget.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(widget.images[i],
                          width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => widget.onRemoveImage(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(LucideIcons.x,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Optionen-Schalter: Review-Gate · Plan-Modus · Screenshots.
          if (_expanded)
            _toggleRow(
              icon: LucideIcons.gitPullRequest,
              label: 'adminDev.reviewBeforeMerge'.tr(),
              value: widget.awaitReview,
              onChanged: widget.sending ? null : widget.onToggleReview,
            ),
          if (_expanded)
            _toggleRow(
              icon: LucideIcons.listChecks,
              label: 'adminDev.plan.toggle'.tr(),
              value: widget.planMode,
              onChanged: widget.sending ? null : widget.onTogglePlan,
            ),
          if (_expanded)
            _toggleRow(
              icon: LucideIcons.image,
              label: 'adminDev.screens.toggle'.tr(),
              value: widget.wantScreens,
              onChanged: widget.sending ? null : widget.onToggleScreens,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_expanded)
                IconButton(
                  onPressed: widget.sending || widget.images.length >= 6
                      ? null
                      : widget.onAttach,
                  icon: const Icon(LucideIcons.imagePlus, size: 20),
                  color: AppColors.teal,
                  tooltip: 'adminDev.attachImage'.tr(),
                ),
              if (_expanded)
                IconButton(
                  onPressed: widget.sending ? null : _toggleListening,
                  icon: Icon(_listening ? LucideIcons.micOff : LucideIcons.mic,
                      size: 20),
                  color: _listening ? Colors.red.shade600 : AppColors.teal,
                  tooltip: 'adminDev.voice.tooltip'.tr(),
                ),
              Expanded(
                child: TextField(
                  controller: widget.ctrl,
                  onChanged: (_) => setState(() {}),
                  onTap: _expanded
                      ? null
                      : () => setState(() => _expanded = true),
                  enabled: !widget.sending,
                  maxLines: _expanded ? 4 : 1,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppTypography.body(
                        size: 13, color: AppColors.lightMute),
                    filled: true,
                    fillColor: AppColors.lightElevated,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: AppColors.lightLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: AppColors.lightLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: widget.sending ? null : () => widget.onSend(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: widget.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.send,
                        size: 18, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chat-Sheet (manueller Modus, Bestätigung wie bei Claude) ────────────────

class _DevChatSheet extends StatefulWidget {
  const _DevChatSheet({required this.initialText, required this.onConfirm});
  final String initialText;
  final Future<bool> Function(String) onConfirm;

  @override
  State<_DevChatSheet> createState() => _DevChatSheetState();
}

class _DevChatSheetState extends State<_DevChatSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;
  bool _ready = false;
  bool _confirming = false;
  String _instruction = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialText.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sendMessage(widget.initialText),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _ready = false;
      _ctrl.clear();
    });
    _scrollToEnd();
    final res = await AiInsightsRepository.chatDev(_messages);
    if (!mounted) return;
    final reply = (res['reply'] as String?) ?? 'adminDev.chat.error'.tr();
    setState(() {
      _messages.add({'role': 'assistant', 'content': reply});
      _ready = res['ready'] == true;
      _instruction = (res['instruction'] as String?) ?? '';
      _sending = false;
    });
    _scrollToEnd();
  }

  Future<void> _confirm() async {
    if (_instruction.isEmpty || _confirming) return;
    setState(() => _confirming = true);
    final ok = await widget.onConfirm(_instruction);
    if (!mounted) return;
    setState(() => _confirming = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('adminDev.queued'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
        duration: const Duration(milliseconds: 4000),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('adminDev.failed'.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.bot, size: 18, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'adminDev.chat.title'.tr(),
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.lightInk,
                        weight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _messages.length) return const _ChatThinking();
                  final m = _messages[i];
                  return _ChatBubble(
                    text: m['content'] ?? '',
                    isUser: m['role'] == 'user',
                  );
                },
              ),
            ),
            if (_ready)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.06),
                  border: Border(
                      top: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirming ? null : _confirm,
                        icon: _confirming
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.check, size: 15),
                        label: Text('adminDev.chat.confirmYes'.tr()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _confirming
                          ? null
                          : () => setState(() => _ready = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.lightMute,
                        side: BorderSide(color: AppColors.lightLine),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      child: Text('adminDev.chat.confirmNo'.tr()),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.lightLine)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: !_sending,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'adminDev.chat.placeholder'.tr(),
                        hintStyle: AppTypography.body(
                            size: 13, color: AppColors.lightMute),
                        filled: true,
                        fillColor: AppColors.lightElevated,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: AppColors.lightLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: AppColors.lightLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: AppColors.teal),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : () => _sendMessage(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(13),
                    ),
                    child: const Icon(LucideIcons.send,
                        size: 17, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.teal : AppColors.lightRaised,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Text(
          text,
          style: AppTypography.body(
            size: 13,
            color: isUser ? Colors.white : AppColors.lightInk,
          ),
        ),
      ),
    );
  }
}

class _ChatThinking extends StatelessWidget {
  const _ChatThinking();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.lightRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.teal),
            ),
            const SizedBox(width: 8),
            Text(
              'adminDev.chat.thinking'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.lightMute),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diff-Sheet: zeigt die geänderten Dateien (Patch) des PRs ────────────────

class _DiffSheet extends StatefulWidget {
  const _DiffSheet({required this.taskId});
  final String taskId;

  @override
  State<_DiffSheet> createState() => _DiffSheetState();
}

class _DiffSheetState extends State<_DiffSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _files = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await AiInsightsRepository.fetchDevTaskDiff(widget.taskId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['ok'] == true) {
        _files = ((res['files'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = 'adminDev.diffError'.tr();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.fileSearch,
                    size: 18, color: AppColors.teal),
                const SizedBox(width: 8),
                Text(
                  'adminDev.diffTitle'.tr(),
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.lightInk,
                      weight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: AppColors.lightMute,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: AppTypography.body(
                                size: 13, color: AppColors.lightMute)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _files.length,
                        itemBuilder: (context, i) => _DiffFileTile(file: _files[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DiffFileTile extends StatelessWidget {
  const _DiffFileTile({required this.file});
  final Map<String, dynamic> file;

  @override
  Widget build(BuildContext context) {
    final name = file['filename'] as String? ?? '';
    final additions = file['additions'] as int? ?? 0;
    final deletions = file['deletions'] as int? ?? 0;
    final patch = file['patch'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          title: Text(
            name,
            style: AppTypography.body(
                size: 12, color: AppColors.lightInk, weight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text('+$additions',
                  style: AppTypography.body(
                      size: 11, color: AppColors.leben)),
              const SizedBox(width: 8),
              Text('-$deletions',
                  style: AppTypography.body(
                      size: 11, color: Colors.red.shade600)),
            ],
          ),
          children: [
            if (patch != null && patch.isNotEmpty)
              Container(
                width: double.infinity,
                color: const Color(0xFF0D1117),
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _DiffPatch(patch: patch),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('adminDev.diffBinary'.tr(),
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightMute)),
              ),
          ],
        ),
      ),
    );
  }
}

// Färbt Diff-Zeilen (+ grün, - rot, @@ teal) im Monospace-Stil.
class _DiffPatch extends StatelessWidget {
  const _DiffPatch({required this.patch});
  final String patch;

  @override
  Widget build(BuildContext context) {
    final lines = patch.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            line.isEmpty ? ' ' : line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
              color: line.startsWith('+')
                  ? const Color(0xFF7EE787)
                  : line.startsWith('-')
                      ? const Color(0xFFFFA198)
                      : line.startsWith('@@')
                          ? const Color(0xFF79C0FF)
                          : const Color(0xFFC9D1D9),
            ),
          ),
      ],
    );
  }
}
