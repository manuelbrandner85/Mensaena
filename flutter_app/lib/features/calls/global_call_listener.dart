import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calls_repository.dart';
import 'incoming_call_page.dart';
import 'models.dart';

/// Globaler Realtime-Listener für eingehende DM-Calls.
/// Pendant zu `src/components/chat/GlobalCallListener.tsx` – muss einmal in
/// die Dashboard-Hülle (AppShell) eingehängt werden.
class GlobalCallListener extends ConsumerStatefulWidget {
  const GlobalCallListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener> {
  bool _isShowing = false;
  String? _lastShownCallId;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DmCall>>(incomingCallsProvider, (_, next) {
      next.whenData(_show);
    });
    return widget.child;
  }

  Future<void> _show(DmCall call) async {
    if (_isShowing) return;
    if (_lastShownCallId == call.id) return; // Doppel-Push verhindern
    _lastShownCallId = call.id;
    _isShowing = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    await navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => IncomingCallPage(call: call),
      ),
    );
    _isShowing = false;
  }
}
