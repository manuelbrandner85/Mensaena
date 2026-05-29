/// SKILL: mensaena-features
/// Globaler Busy-Status für Call/Stream.
///
/// Wenn der User gerade in einem DM-Call ODER einem Livestream ist, sollen
/// eingehende DM-Anrufe ihn NICHT aus dem laufenden Call/Stream werfen
/// (User-Report 2026-05, Punkt 4). Stattdessen wird der eingehende Anruf
/// als "besetzt" behandelt — analog zu WhatsApp.
///
/// Bewusst KEIN Riverpod-Provider, damit IncomingCallListener + CallEventBus
/// den Status synchron ohne `ref` prüfen können.
class CallBusyState {
  CallBusyState._();

  /// Aktiv während ein DM-Call connected ist (call_screen).
  static bool inCall = false;

  /// Aktiv während ein Livestream-Raum connected ist (live_room_screen).
  static bool inStream = false;

  /// True wenn der User gerade beschäftigt ist (Call oder Stream).
  static bool get busy => inCall || inStream;
}
