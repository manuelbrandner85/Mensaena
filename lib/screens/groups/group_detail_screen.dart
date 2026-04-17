import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/group_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/group.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/section_header.dart';
import 'package:mensaena/widgets/badge_widget.dart';

/// Kategorie-Konfiguration fuer Gruppen.
class _GroupCategoryConfig {
  final String label;
  final String emoji;
  final Color color;

  const _GroupCategoryConfig(this.label, this.emoji, this.color);

  static const Map<String, _GroupCategoryConfig> categories = {
    'nachbarschaft': _GroupCategoryConfig('Nachbarschaft', '🏘️', Color(0xFF3B82F6)),
    'hobby': _GroupCategoryConfig('Hobby & Freizeit', '🎨', Color(0xFFEC4899)),
    'sport': _GroupCategoryConfig('Sport & Fitness', '⚽', Color(0xFFF97316)),
    'eltern': _GroupCategoryConfig('Eltern & Familie', '👶', Color(0xFFF59E0B)),
    'senioren': _GroupCategoryConfig('Senioren', '🧓', Color(0xFF8B5CF6)),
    'umwelt': _GroupCategoryConfig('Umwelt & Nachhaltigkeit', '🌿', Color(0xFF10B981)),
    'bildung': _GroupCategoryConfig('Bildung & Lernen', '📚', Color(0xFF6366F1)),
    'tiere': _GroupCategoryConfig('Tiere', '🐾', Color(0xFFD97706)),
    'handwerk': _GroupCategoryConfig('Handwerk & DIY', '🔧', Color(0xFF64748B)),
    'sonstiges': _GroupCategoryConfig('Sonstiges', '💬', AppColors.primary500),
  };

  static _GroupCategoryConfig fromString(String? value) {
    return categories[value] ?? categories['sonstiges']!;
  }
}

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  bool _joinLoading = false;
  bool _isMember = false;
  bool _membershipChecked = false;
  String _myRole = 'member'; // Wird beim Beitreten/Membership-Check gesetzt

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  Future<void> _checkMembership() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _membershipChecked = true);
      return;
    }
    try {
      final service = ref.read(groupServiceProvider);
      final isMember = await service.isMember(widget.groupId, userId);
      if (mounted) {
        setState(() {
          _isMember = isMember;
          _membershipChecked = true;
        });
      }
      // Check role from members list
      if (isMember) {
        final members = await service.getMembers(widget.groupId);
        final me = members.where((m) => m.userId == userId).firstOrNull;
        if (me != null && mounted) {
          setState(() => _myRole = me.role);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _membershipChecked = true);
    }
  }

  Future<void> _joinGroup() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte zuerst anmelden')),
        );
      }
      return;
    }

    setState(() => _joinLoading = true);
    try {
      final service = ref.read(groupServiceProvider);
      await service.joinGroup(widget.groupId, userId);
      setState(() {
        _isMember = true;
        _myRole = 'member';
      });
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(groupMembersProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gruppe beigetreten!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Beitreten: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joinLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Bestaetigung
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gruppe verlassen'),
        content: const Text('Moechtest du diese Gruppe wirklich verlassen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Verlassen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _joinLoading = true);
    try {
      final service = ref.read(groupServiceProvider);
      await service.leaveGroup(widget.groupId, userId);
      setState(() => _isMember = false);
      ref.invalidate(groupDetailProvider(widget.groupId));
      ref.invalidate(groupMembersProvider(widget.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gruppe verlassen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joinLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Fehler: $e', style: const TextStyle(
                  fontSize: 14, color: AppColors.textMuted,
                )),
              ],
            ),
          ),
        ),
        data: (group) {
          if (group == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_off, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('Gruppe nicht gefunden',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }

          final catConfig = _GroupCategoryConfig.fromString(group.category);
          final isCreator = (currentUserId != null && currentUserId == group.creatorId);
          final isAdmin = _myRole == 'admin' || isCreator;
          final dateFormat = DateFormat('d. MMMM yyyy', 'de_DE');

          return CustomScrollView(
            slivers: [
              // -- Hero-Banner --
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          catConfig.color,
                          catConfig.color.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Hintergrund-Emoji
                        Positioned(
                          right: 20,
                          bottom: 30,
                          child: Text(
                            catConfig.emoji,
                            style: TextStyle(
                              fontSize: 80,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        // Inhalt
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Badges
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${catConfig.emoji} ${catConfig.label}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          group.isPrivate
                                              ? Icons.lock
                                              : Icons.public,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          group.isPrivate
                                              ? 'Privat'
                                              : 'Öffentlich',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_membershipChecked && _isMember) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '✓ Mitglied',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // -- Content --
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gruppenname
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Beschreibung
                      if (group.description != null &&
                          group.description!.isNotEmpty) ...[
                        Text(
                          group.description!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        const Text(
                          'Keine Beschreibung vorhanden.',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Statistiken
                      membersAsync.when(
                        data: (members) => _StatsRow(
                          memberCount: members.length,
                          createdAt: group.createdAt,
                          dateFormat: dateFormat,
                        ),
                        loading: () => _StatsRow(
                          memberCount: group.memberCount,
                          createdAt: group.createdAt,
                          dateFormat: dateFormat,
                        ),
                        error: (_, __) => _StatsRow(
                          memberCount: group.memberCount,
                          createdAt: group.createdAt,
                          dateFormat: dateFormat,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Beitreten / Verlassen Button
                      if (_membershipChecked) ...[
                        _isMember
                            ? SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: (isCreator || (isAdmin && group.memberCount <= 1))
                                      ? null
                                      : _joinLoading
                                          ? null
                                          : _leaveGroup,
                                  icon: _joinLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.logout, size: 18),
                                  label: Text(
                                    isCreator
                                        ? 'Du bist der Ersteller'
                                        : _joinLoading
                                            ? 'Wird verlassen...'
                                            : 'Gruppe verlassen',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isCreator
                                        ? AppColors.textMuted
                                        : AppColors.error,
                                    side: BorderSide(
                                      color: isCreator
                                          ? AppColors.border
                                          : AppColors.error.withValues(alpha: 0.5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _joinLoading ? null : _joinGroup,
                                  icon: _joinLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.group_add, size: 20),
                                  label: Text(
                                    _joinLoading
                                        ? 'Beitreten...'
                                        : 'Gruppe beitreten',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: catConfig.color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 24),
                      ],

                      // -- Mitglieder-Liste --
                      membersAsync.when(
                        data: (members) => _MembersSection(
                          members: members,
                          creatorId: group.creatorId,
                          catColor: catConfig.color,
                        ),
                        loading: () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                              title: 'Mitglieder',
                              icon: Icons.people_outline,
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              3,
                              (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        error: (e, _) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber,
                                  color: AppColors.warning),
                              const SizedBox(width: 12),
                              Text('Mitglieder konnten nicht geladen werden: $e',
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // -- Gruppen-Infos --
                      const SectionHeader(
                        title: 'Ueber diese Gruppe',
                        icon: Icons.info_outline,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _GroupInfoRow(
                              icon: Icons.category_outlined,
                              label: 'Kategorie',
                              value: '${catConfig.emoji} ${catConfig.label}',
                            ),
                            const Divider(height: 20),
                            _GroupInfoRow(
                              icon: group.isPrivate
                                  ? Icons.lock_outline
                                  : Icons.public,
                              label: 'Sichtbarkeit',
                              value: group.isPrivate
                                  ? 'Privat (nur auf Einladung)'
                                  : 'Öffentlich (jeder kann beitreten)',
                            ),
                            const Divider(height: 20),
                            _GroupInfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Erstellt am',
                              value: dateFormat.format(group.createdAt),
                            ),
                            const Divider(height: 20),
                            _GroupInfoRow(
                              icon: Icons.update,
                              label: 'Aktivitaet',
                              value:
                                  'Erstellt ${timeago.format(group.createdAt, locale: 'de')}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -- Statistik-Zeile --
class _StatsRow extends StatelessWidget {
  final int memberCount;
  final DateTime createdAt;
  final DateFormat dateFormat;

  const _StatsRow({
    required this.memberCount,
    required this.createdAt,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.people_outline,
          value: '$memberCount',
          label: memberCount == 1 ? 'Mitglied' : 'Mitglieder',
          color: AppColors.primary500,
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.calendar_today_outlined,
          value: 'Seit',
          label: dateFormat.format(createdAt),
          color: AppColors.trust,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Mitglieder-Section --
class _MembersSection extends StatelessWidget {
  final List<GroupMember> members;
  final String creatorId;
  final Color catColor;

  const _MembersSection({
    required this.members,
    required this.creatorId,
    required this.catColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Mitglieder (${members.length})',
          icon: Icons.people_outline,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 64),
            itemBuilder: (context, index) {
              final member = members[index];
              final name = member.profile?['name'] as String? ??
                  member.profile?['nickname'] as String? ??
                  'Unbekannt';
              final avatar =
                  member.profile?['avatar_url'] as String?;
              final isCreator = member.userId == creatorId;
              final isAdmin =
                  member.role == 'admin' || isCreator;
              final isMod = member.role == 'moderator';

              return ListTile(
                leading: AvatarWidget(
                  imageUrl: avatar,
                  name: name,
                  size: 40,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFED7AA),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star,
                                size: 10, color: Color(0xFFD97706)),
                            SizedBox(width: 2),
                            Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isMod) ...[
                      const SizedBox(width: 6),
                      AppBadge(
                        label: 'Moderator',
                        color: AppColors.info,
                        small: true,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  'Beigetreten ${timeago.format(member.joinedAt, locale: 'de')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
              );
            },
          ),
        ),
      ],
    );
  }
}

// -- Gruppen-Info Zeile --
class _GroupInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GroupInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}