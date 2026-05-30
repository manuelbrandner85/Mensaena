# Geräte-Test-Leitfaden vor dem Pflicht-Update

**Stand 2026-05.** Diese Liste deckt die hochriskanten Änderungen ab, die ich
nicht runtime-testen konnte (kein Android-SDK/Gerät in meiner Umgebung). Vor
einem **[mandatory]**-Commit auf jedem Punkt einmal grünes Häkchen setzen.

---

## 🔴 KRITISCH — vor Pflicht-Update zwingend prüfen

### 1. DM-Call — eingehend (Telegram/WhatsApp-Style)
- [ ] App im Hintergrund / Bildschirm aus → Anruf eingeht → Vollbild-CallKit-UI
      (nicht nur Heads-Up-Notification)
- [ ] Annehmen vom Lock-Screen → landet direkt im Call-Raum (NICHT erst App
      komplett laden)
- [ ] Cold-Start aus Killed-State → CallEventBus.recoverColdStart greift

### 2. DM-Call — Minimieren / „PiP"
- [ ] Im Call → Zurück-Geste → Mini-Player erscheint, **Audio läuft weiter**
- [ ] In Posts / Chat / Settings navigieren → Audio bleibt
- [ ] Mini-Player antippen → zurück im Call-Screen OHNE Neu-Verbindung
- [ ] Echtes Auflegen über Mini-Player-X → Audio aus, Mini-Player weg

### 3. Livestream — Minimieren / „PiP" (Telegram-Modell, NEU)
- [ ] Im Stream → Zurück → Stream-Mini-Player erscheint, **Audio läuft weiter**
- [ ] Navigation in der App → man hört weiter alle Teilnehmer
- [ ] Mini-Player-Tap → zurück im Stream OHNE Reconnect
- [ ] X im Mini-Player → wirklich verlassen
- [ ] **Host minimiert** → Stream läuft weiter für alle (NICHT beenden)

### 4. Hintergrund-Audio (nativer Foreground-Service)
- [ ] Im Stream / DM-Call → Home-Taste → Notification „Live-Audio aktiv"
      erscheint im Status-Bar (Foreground-Service)
- [ ] Bildschirm aus → Audio läuft weiter
- [ ] Notification antippen → App zurück zum Call/Stream

### 5. Eingehender Call während aktiv (Busy-State)
- [ ] Im DM-Call → 2. Anruf kommt → wird **automatisch** als „besetzt"
      abgelehnt, kein Rauswurf
- [ ] Im Livestream → eingehender Anruf → ebenfalls automatisch besetzt

### 6. Standort auf der Karte
- [ ] Standort-Einstellung aktiv, GPS gewährt → eigener Punkt erscheint
- [ ] GPS verweigert / kein Fix → Profil-Heimat-Standort wird genutzt
- [ ] Kein Profil-Standort → SnackBar „Standort nicht verfügbar" (nicht
      stumm leer)

### 7. Crisis-Standort-Filter
- [ ] Profil-Standort gesetzt → nur Krisen im 150km-Radius
- [ ] **Krise ohne Koordinaten** → wird IMMER gezeigt (Sicherheits-Fallback)
- [ ] Profil ohne Standort → alle Krisen (kein versteckter Notfall)

### 8. Bild-Upload (Event-Foto, war kaputt)
- [ ] Event → Foto hochladen → erscheint in der Galerie + lädt als Bild
      (nicht als octet-stream)

---

## 🟡 WICHTIG — beim Test mitprüfen

### 9. Friends-Suche + Anfragen
- [ ] Friends-Screen → FAB „Anfragen" → User-Picker öffnet
- [ ] 1 Zeichen eingeben → Treffer erscheinen (nicht erst ab 2)
- [ ] Anfrage senden → Snackbar „Anfrage an X gesendet"

### 10. Livestream / Call — JEDEN einladen
- [ ] Im Stream → „+" Teilnehmer → User-Picker mit ALLEN Usern (nicht nur
      Freunde) → Tippen → Empfänger bekommt Notification → Tap → landet
      direkt im Stream

### 11. Rollen-Vergabe (Admin)
- [ ] Admin → User → Rolle ändern → **Name bleibt erhalten** (war Bug)

### 12. Alle User in Admin-Liste
- [ ] Admin → Users → Pagination zeigt **alle** User (nicht nur erste 100)
- [ ] Suche findet User auf Seite 2+

### 13. Empty-States atmen
- [ ] Leere Liste irgendwo → Icon mit sanftem Glow-Puls (nicht statisch)

### 14. Cinema-Refresh
- [ ] Pull-to-Refresh auf einem Screen → Bronze-Spinner (nicht Amber/Material)

### 15. Beitrag erfolgreich erstellt
- [ ] Beitrag posten → kurzes Konfetti-Burst (außer Reduce-Motion aktiv)

### 16. Inline-Validierung
- [ ] Create-Screen (Post/Event/Gruppe/Marktplatz/Crisis/Board) → Submit
      mit leerem Pflichtfeld → **rotes Fehler-Label am Feld** (nicht nur
      Snackbar) + verschwindet beim Tippen

### 17. Sheet-Glass
- [ ] Irgendein Bottom-Sheet öffnen → dunkler Glass-Look (durchscheinend),
      nicht opak Surface

### 18. Floating Nav-Pill
- [ ] Nav schwebt mit 14px-Rand, Bronze-FAB als zentrales Quadrat → kontrast-
      stark + lesbar; Tab-Wechsel cross-fadet sanft

---

## 🟢 NICE — wenn Zeit

### 19. Staggered Entrance
- [ ] Posts/Events/Marktplatz/Gruppen/Board/Organizations/Jobs/Supply/
      Saved-Posts/Interactions: Items fließen gestaffelt herein

### 20. Press-Animationen
- [ ] PostCard antippen → leichter Scale-Down

### 21. Optimistic Vote/Save
- [ ] Vote-Up/Save auf Post → sofort visuell (nicht erst nach Server-Roundtrip)

### 22. Gruppe Join/Leave Snackbar
- [ ] Snackbar „Gruppe beigetreten/verlassen" erscheint

### 23. Notrufnummern pro Land
- [ ] Notruf-Modul → Liste passt zum aktuellen Country-Code

### 24. Sound-Settings
- [ ] Settings → Anruf-Ton & Lautstärke → Slider funktioniert, Vibration-
      Toggle wirkt

---

## ⚠️ Bekannte „nicht in dieser Umgebung testbar"-Risiken

- **Nativer Kotlin-Foreground-Service** (`LiveAudioService.kt`): folgt dem
  funktionierenden flutter_callkit-Muster + defensive try/catch — bei
  Compile-Fehler bricht der CI-APK-Build (kein kaputter APK an User), aber
  Runtime-Verhalten (Notification-Channel-Permissions auf Android 13+)
  bitte 1× verifizieren.

- **LiveKit-Reattach** (Stream + Call Mini-Player → zurück): Dart-Logik
  sauber (StreamRoomHolder/CallRoomHolder), aber LiveKit-Verhalten beim
  Wieder-Anhängen ist gerätespezifisch.

- **Glass-Performance**: Blur ist NUR auf der schwebenden Nav-Pill + dem
  Create-Picker-Sheet aktiv. Falls auf älteren Geräten ruckelig → in
  `dashboard_scaffold.dart` Nav-Pill `BackdropFilter sigma` von 10 auf 6
  reduzieren.

---

## Reihenfolge fürs Pflicht-Update

1. Punkte 1–8 durchgehen (kritisch). Bei Fail: melden, ich fixe gezielt.
2. Punkte 9–18 stichprobenartig (10 Min reichen).
3. Wenn alles grün → Commit mit `[mandatory]` im Subject.
4. `flutter.yml` baut APK + `app_releases`-Row mit `mandatory=true`.
5. `UpdateGate` zwingt User auf neue Version beim nächsten App-Start.
