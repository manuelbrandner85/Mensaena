import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../theme/app_colors.dart';

/// Subscription-Konfig für ein Postgres-changes-Event.
class FeedRealtimeRule {
  const FeedRealtimeRule({
    required this.event,
    required this.table,
    required this.action,
    this.schema = 'public',
  });

  final PostgresChangeEvent event;
  final String table;
  final String schema;

  /// Was passieren soll, wenn das Event eintrifft.
  final FeedRealtimeAction action;
}

enum FeedRealtimeAction {
  /// Zähler hochzählen → User entscheidet via Banner-Tap, ob er nachladen will.
  bumpNewCount,

  /// Sofort `reload()` aufrufen.
  reloadImmediately,
}

/// Mixin für ListenStates, die ein Postgres-Realtime-Channel brauchen.
/// Verwendet ein Channel pro Page, ruft die übergebenen Rules sequentiell ab.
mixin RealtimeFeedMixin<T extends StatefulWidget> on State<T> {
  RealtimeChannel? _feedChannel;
  int _newItemCount = 0;

  /// Eindeutiger Channel-Name (z. B. `events-feed-realtime`).
  String get realtimeChannelName;

  /// Auf welche Tabellen/Events lauschen?
  List<FeedRealtimeRule> get realtimeRules;

  /// Wird aufgerufen, wenn die Banner-Aktion getappt wird oder ein
  /// `reloadImmediately`-Event eintrifft.
  Future<void> reloadFeed();

  /// Filter, der entscheidet ob ein INSERT-Event den Counter triggert.
  /// Default: ja, außer es ist vom eingeloggten User selbst.
  bool shouldBumpForInsert(Map<String, dynamic> row) {
    final myId = sb.auth.currentUser?.id;
    if (myId != null && row['user_id'] == myId) return false;
    return true;
  }

  int get newItemCount => _newItemCount;

  void resetNewItemCount() {
    if (_newItemCount == 0) return;
    setState(() => _newItemCount = 0);
  }

  void subscribeRealtime() {
    var channel = sb.channel(realtimeChannelName);
    for (final rule in realtimeRules) {
      channel = channel.onPostgresChanges(
        event: rule.event,
        schema: rule.schema,
        table: rule.table,
        callback: (payload) {
          if (!mounted) return;
          switch (rule.action) {
            case FeedRealtimeAction.bumpNewCount:
              final row = payload.newRecord;
              if (!shouldBumpForInsert(row)) return;
              setState(() => _newItemCount += 1);
              break;
            case FeedRealtimeAction.reloadImmediately:
              reloadFeed();
              break;
          }
        },
      );
    }
    _feedChannel = channel..subscribe();
  }

  void unsubscribeRealtime() {
    if (_feedChannel != null) {
      sb.removeChannel(_feedChannel!);
      _feedChannel = null;
    }
  }

  @override
  void dispose() {
    unsubscribeRealtime();
    super.dispose();
  }
}

/// Tappable Banner, der angezeigt wird, wenn neue Items via Realtime eingehen.
/// Tap → ruft `onTap()` auf (üblicherweise `resetNewItemCount()` + `reloadFeed()`).
class NewItemsBanner extends StatelessWidget {
  const NewItemsBanner({
    super.key,
    required this.count,
    required this.singularLabel,
    required this.pluralLabel,
    required this.onTap,
    this.icon = Icons.arrow_upward_rounded,
    this.background = AppColors.primary500,
  });

  final int count;
  final String singularLabel;
  final String pluralLabel;
  final VoidCallback onTap;
  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final word = count == 1 ? singularLabel : pluralLabel;
    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                '$count neue $word — tippen zum Aktualisieren',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
