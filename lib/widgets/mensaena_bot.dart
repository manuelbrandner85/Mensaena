import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';

class MensaenaBot extends ConsumerWidget {
  const MensaenaBot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: FloatingActionButton(
        heroTag: 'mensaena_bot',
        mini: true,
        backgroundColor: const Color(0xFF8B5CF6),
        onPressed: () => _openBotSheet(context, ref),
        child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
      ),
    );
  }

  void _openBotSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scroll) => _BotSheet(scrollController: scroll),
      ),
    );
  }
}

class _BotSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const _BotSheet({required this.scrollController});

  @override
  ConsumerState<_BotSheet> createState() => _BotSheetState();
}

class _BotSheetState extends ConsumerState<_BotSheet> {
  List<Map<String, dynamic>> _tips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    try {
      final client = ref.read(supabaseProvider);
      final data = await client
          .from('bot_scheduled_messages')
          .select('id, content, message_type, created_at')
          .order('created_at', ascending: false)
          .limit(5);
      if (mounted) setState(() => _tips = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.smart_toy, color: Color(0xFF6D28D9), size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mensaena-Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Dein digitaler Nachbarschaftshelfer', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _tips.isEmpty
                  ? const Center(child: Text('Noch keine Tipps verfügbar.', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _tips.length,
                      itemBuilder: (_, i) {
                        final tip = _tips[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28, height: 28, margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFF6D28D9)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    tip['content'] as String? ?? '',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF4C1D95), height: 1.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Frage stellen... (bald verfügbar)',
              prefixIcon: const Icon(Icons.chat_outlined, size: 18, color: AppColors.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              filled: true, fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
