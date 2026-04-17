String formatError(dynamic error) {
  final msg = error.toString();
  if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('NetworkException')) {
    return 'Keine Internetverbindung. Bitte pruefen und erneut versuchen.';
  }
  if (msg.contains('AuthException') || msg.contains('Invalid login')) {
    return 'Anmeldung fehlgeschlagen. Bitte Zugangsdaten pruefen.';
  }
  if (msg.contains('permission denied') || msg.contains('RLS') || msg.contains('policy')) {
    return 'Keine Berechtigung für diese Aktion.';
  }
  if (msg.contains('duplicate') || msg.contains('unique') || msg.contains('23505')) {
    return 'Dieser Eintrag existiert bereits.';
  }
  if (msg.contains('not found') || msg.contains('404')) {
    return 'Inhalt nicht gefunden.';
  }
  if (msg.contains('timeout') || msg.contains('Timeout')) {
    return 'Zeitueberschreitung. Bitte erneut versuchen.';
  }
  if (msg.contains('check constraint') || msg.contains('violates')) {
    return 'Ungueltige Eingabe. Bitte Felder pruefen.';
  }
  return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';
}
