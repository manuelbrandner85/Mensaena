import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';

final _pendingZeitbankProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  try {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('timebank_entries')
        .select('id, hours, description, status, partner_id, profiles!timebank_entries_partner_id_fkey(name)')
        .eq('user_id', userId)
        .eq('status', 'pending_confirmation')
        .order('created_at', ascending: false)
        .limit(3);
    return List<Map<String, dynamic>>.from(data);
  } catch (_) {
    return const [];
  }
});

class ZeitbankConfirmationBanner extends ConsumerWidget {
  const ZeitbankConfirmationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingZeitbankProvider);
    final entries = pending.valueOrNull ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time, size: 18, color: Color(0xFF92400E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/dashboard/timebank'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entries.length} Zeitbank-${entries.length == 1 ? 'Eintrag wartet' : 'Einträge warten'} auf deine Bestätigung',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tippe um zu prüfen →',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final client = ref.read(supabaseProvider);
              for (final entry in entries) {
                await client.from('timebank_entries').update({'status': 'confirmed'}).eq('id', entry['id']);
              }
              ref.invalidate(_pendingZeitbankProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alle Einträge bestätigt')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Bestätigen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
