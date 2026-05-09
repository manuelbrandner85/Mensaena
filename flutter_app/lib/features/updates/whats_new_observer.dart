import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_service.dart';
import 'whats_new_sheet.dart';

/// Wrapper das beim Mounten einmalig prüft, ob es seit dem letzten
/// Login ungesehene Releases gibt – falls ja, wird automatisch der
/// Was-ist-Neu-Sheet geöffnet. Idempotent dank `_triggered`.
class WhatsNewObserver extends ConsumerStatefulWidget {
  const WhatsNewObserver({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WhatsNewObserver> createState() => _WhatsNewObserverState();
}

class _WhatsNewObserverState extends ConsumerState<WhatsNewObserver> {
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_triggered || !mounted) return;
    _triggered = true;
    try {
      final service = ref.read(updateServiceProvider);
      final unseen = await service.consumeUnseenReleases();
      if (!mounted || unseen.isEmpty) return;
      await WhatsNewSheet.show(context, releases: unseen);
    } catch (_) {
      // best effort – wenn Supabase nicht erreichbar oder Auth-Issue,
      // verlieren wir nichts; beim nächsten Launch nochmal versuchen.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
