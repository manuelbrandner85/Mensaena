import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// Pendant zu /dashboard/timebank. Zeigt den Stunden-Kontostand
/// und die letzten Buchungen.
class TimebankPage extends ConsumerStatefulWidget {
  const TimebankPage({super.key});

  @override
  ConsumerState<TimebankPage> createState() => _TimebankPageState();
}

class _TimebankPageState extends ConsumerState<TimebankPage> {
  Map<String, dynamic>? _balance;
  List<Map<String, dynamic>> _transactions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Nicht eingeloggt';
        });
        return;
      }

      Map<String, dynamic>? balanceData;
      try {
        final res = await api.get<Map<String, dynamic>>('/api/zeitbank/balance');
        balanceData = res.data;
      } catch (_) {
        balanceData = null;
      }

      final txRows = await db
          .from('timebank_transactions')
          .select(
            '*, giver:giver_id(name, avatar_url), receiver:receiver_id(name, avatar_url)',
          )
          .or('giver_id.eq.${user.id},receiver_id.eq.${user.id}')
          .order('created_at', ascending: false)
          .limit(30);

      if (!mounted) return;
      setState(() {
        _balance = balanceData;
        _transactions = List<Map<String, dynamic>>.from(txRows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Zeitbank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceCard(balance: _balance),
                  const SizedBox(height: 20),
                  const Text(
                    'Transaktionen',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.ink400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.ink400),
                      ),
                    )
                  else if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Noch keine Transaktionen',
                        style: TextStyle(color: AppColors.ink400),
                      ),
                    )
                  else
                    ..._transactions.map(
                      (tx) => _TransactionTile(
                        data: tx,
                        myUserId:
                            ref.read(supabaseProvider).auth.currentUser?.id,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final Map<String, dynamic>? balance;

  @override
  Widget build(BuildContext context) {
    final hours = (balance?['hours'] as num?)?.toDouble() ?? 0;
    final earned = (balance?['hours_earned'] as num?)?.toDouble() ?? 0;
    final spent = (balance?['hours_spent'] as num?)?.toDouble() ?? 0;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary500, AppColors.primary700],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mein Stundenkonto',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${hours.toStringAsFixed(1)} h',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stat('Erhalten', earned),
              ),
              Expanded(
                child: _stat('Geleistet', spent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${hours.toStringAsFixed(1)} h',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.data, this.myUserId});
  final Map<String, dynamic> data;
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('d. MMM yyyy', 'de').format(DateTime.parse(created))
        : '';
    final hours = (data['hours'] as num?)?.toDouble() ?? 0;
    final isReceiver = data['receiver_id'] == myUserId;
    final partnerProfile =
        isReceiver ? data['giver'] : data['receiver'];
    final partnerName = (partnerProfile is Map<String, dynamic>)
        ? partnerProfile['name'] as String? ?? 'Unbekannt'
        : 'Unbekannt';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isReceiver ? Icons.arrow_downward : Icons.arrow_upward,
            color: isReceiver ? Colors.green.shade700 : Colors.orange.shade700,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceiver
                      ? 'Erhalten von $partnerName'
                      : 'Geleistet für $partnerName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if ((data['note'] as String? ?? '').isNotEmpty)
                  Text(
                    data['note'] as String,
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.ink400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isReceiver ? '+' : '-'}${hours.toStringAsFixed(1)} h',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isReceiver ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
