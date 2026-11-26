import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';
import '../widgets/calculate_expense_sheet.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<ExpenseGroup> _groups = [];
  List<GroupRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.fetchGroups();
      if (mounted) {
        setState(() {
          _groups = res.groups;
          _requests = res.pendingRequests;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGroupDialog() async {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    UserLookup? foundUser;
    String? lookupError;
    bool searching = false;
    bool creating = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Create Group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. Roommates, Trip',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Invite User (optional)',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Login username',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: searching
                          ? null
                          : () async {
                              final q = userCtrl.text.trim();
                              if (q.isEmpty) return;
                              setS(() {
                                searching = true;
                                lookupError = null;
                                foundUser = null;
                              });
                              try {
                                final u = await ApiClient.instance.lookupUser(q);
                                setS(() => foundUser = u);
                              } catch (e) {
                                setS(() => lookupError = e.toString());
                              } finally {
                                setS(() => searching = false);
                              }
                            },
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: const Color(0xFF032318),
                      ),
                      icon: searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
                if (lookupError != null) ...[
                  const SizedBox(height: 8),
                  Text(lookupError!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                ],
                if (foundUser != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Username: ${foundUser!.username}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          foundUser!.phoneNumber.isNotEmpty
                              ? 'Contact: ${foundUser!.phoneNumber}'
                              : 'Contact: Not set',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: creating
                  ? null
                  : () async {
                      final gName = nameCtrl.text.trim();
                      if (gName.isEmpty) return;
                      setS(() => creating = true);
                      try {
                        await ApiClient.instance.createGroup(
                          name: gName,
                          inviteUsername: foundUser?.username,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      } catch (e) {
                        setS(() {
                          creating = false;
                          lookupError = e.toString();
                        });
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF032318),
              ),
              child: Text(
                foundUser != null ? 'Create & Send Request' : 'Create Group',
              ),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    userCtrl.dispose();
  }

  Future<void> _respond(GroupRequest req, String action) async {
    try {
      await ApiClient.instance.respondToGroupRequest(
        memberId: req.memberId,
        action: action,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'ACCEPT'
                  ? 'Joined "${req.groupName}"!'
                  : 'Declined "${req.groupName}".',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            tooltip: 'Calculate Group Expense',
            icon: const Icon(Icons.calculate_rounded, color: AppTheme.accent),
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.card,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const CalculateExpenseSheet(initialGroupMode: true),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: [
            const Tab(text: 'My Groups'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Notifications'),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_requests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroupDialog,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    RefreshIndicator(
                      color: AppTheme.accent,
                      onRefresh: _load,
                      child: _groups.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'No groups yet. Tap Create Group to start.',
                                    style: TextStyle(color: AppTheme.textMuted),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                              itemCount: _groups.length,
                              itemBuilder: (ctx, i) {
                                final g = _groups[i];
                                final acceptedCount = g.members
                                    .where((m) => m.status == 'ACCEPTED')
                                    .length;
                                return Card(
                                  color: AppTheme.card,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: const BorderSide(color: AppTheme.border),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppTheme.surface,
                                      child: Icon(Icons.groups_rounded, color: AppTheme.accent),
                                    ),
                                    title: Text(
                                      g.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(
                                      '$acceptedCount member${acceptedCount == 1 ? '' : 's'}',
                                      style: const TextStyle(color: AppTheme.textMuted),
                                    ),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GroupDetailScreen(group: g),
                                        ),
                                      );
                                      _load();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    RefreshIndicator(
                      color: AppTheme.accent,
                      onRefresh: _load,
                      child: _requests.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    'No pending group requests.',
                                    style: TextStyle(color: AppTheme.textMuted),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                              itemCount: _requests.length,
                              itemBuilder: (ctx, i) {
                                final r = _requests[i];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.groupName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Invited by @${r.invitedByUsername}',
                                        style: const TextStyle(color: AppTheme.textMuted),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _respond(r, 'DENY'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.danger,
                                                side: const BorderSide(color: AppTheme.danger),
                                              ),
                                              child: const Text('Deny'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: () => _respond(r, 'ACCEPT'),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: AppTheme.accent,
                                                foregroundColor: const Color(0xFF032318),
                                              ),
                                              child: const Text('Accept'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
