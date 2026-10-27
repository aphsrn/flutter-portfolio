import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/boq_item.dart';
import '../models/material_request.dart';
import '../services/app_settings_provider.dart';
import '../services/supabase_providers.dart';
import '../screens/boq_items_screen.dart';
import '../screens/requests_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import 'team_view.dart';
import 'pm_schedule_screen.dart';

final _approvingIdProvider = StateProvider<String?>((ref) => null);

class ApprovalService {
  final supabase = Supabase.instance.client;
  Future<String?> approveRequest(String requestId) async {
    try {
      await supabase
          .from('material_requests')
          .update({'status': 'approved'})
          .eq('id', requestId);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }
}

final approvalServiceProvider = Provider<ApprovalService>(
  (_) => ApprovalService(),
);

enum DashboardTab {
  dashboard,
  boqItems,
  requests,
  reports,
  schedule,
  team,
  settings,
}

final _dashboardTabProvider = StateProvider<DashboardTab>(
  (ref) => DashboardTab.dashboard,
);

String _getTabTitle(DashboardTab tab) {
  switch (tab) {
    case DashboardTab.dashboard:
      return 'P&L Dashboard';
    case DashboardTab.boqItems:
      return 'BOQ Items';
    case DashboardTab.requests:
      return 'Requests';
    case DashboardTab.reports:
      return 'Reports';
    case DashboardTab.schedule:
      return 'Schedule Management';
    case DashboardTab.team:
      return 'Team';
    case DashboardTab.settings:
      return 'Settings';
  }
}

// ── Dashboard Screen ─────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  final String projectId;
  const DashboardScreen({super.key, required this.projectId});
  static const _bg = Color(0xFFF4F6FB);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_dashboardTabProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final bgColor = isDarkMode ? const Color(0xFF121212) : _bg;

    final isDesktop = MediaQuery.of(context).size.width >= 850;

    Widget mainContent;
    switch (selectedTab) {
      case DashboardTab.dashboard:
        mainContent = _DashboardContentView(projectId: projectId);
        break;
      case DashboardTab.boqItems:
        mainContent = BoqItemsScreen(projectId: projectId);
        break;
      case DashboardTab.requests:
        mainContent = RequestsScreen(projectId: projectId);
        break;
      case DashboardTab.reports:
        mainContent = ReportsScreen(projectId: projectId);
        break;
      case DashboardTab.schedule:
        mainContent = PmScheduleScreen(projectId: projectId);
        break;
      case DashboardTab.team:
        mainContent = const TeamView();
        break;
      case DashboardTab.settings:
        mainContent = const SettingsScreen();
        break;
    }

    return Scaffold(
      backgroundColor: bgColor,
      drawer: isDesktop ? null : Drawer(child: const _Sidebar()),
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(
                _getTabTitle(selectedTab),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    ref.invalidate(boqItemsProvider(projectId));
                    ref.invalidate(materialRequestsProvider(projectId));
                  },
                ),
              ],
            ),
      body: Row(
        children: [
          if (isDesktop) const _Sidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  _TopBar(projectId: projectId, selectedTab: selectedTab),
                Expanded(child: mainContent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContentView extends ConsumerWidget {
  final String projectId;
  const _DashboardContentView({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boqAsync = ref.watch(boqItemsProvider(projectId));
    final requestsAsync = ref.watch(materialRequestsProvider(projectId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          boqAsync.when(
            loading: () => const _TableShimmer(),
            error: (e, _) => _InlineError(message: e.toString()),
            data: (items) => _SummaryCards(items: items),
          ),
          const SizedBox(height: 32),
          requestsAsync.when(
            loading: () => const _TableShimmer(),
            error: (e, _) => _InlineError(message: e.toString()),
            data: (requests) => boqAsync.maybeWhen(
              data: (items) => _RequestsTable(
                requests: requests,
                boqItems: items,
                projectId: projectId,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();
  static const _bg = Color(0xFF1A1D23);
  static const _accent = Color(0xFF4F6EF7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_dashboardTabProvider);
    return Container(
      width: 220,
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Smart Site',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            active: selectedTab == DashboardTab.dashboard,
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.dashboard;
              _closeDrawer(context);
            },
          ),
          _NavItem(
            icon: Icons.list_alt_rounded,
            label: 'BOQ Items',
            active: selectedTab == DashboardTab.boqItems,
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.boqItems;
              _closeDrawer(context);
            },
          ),
          _NavItem(
            icon: Icons.inbox_rounded,
            label: 'Requests',
            active: selectedTab == DashboardTab.requests,
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.requests;
              _closeDrawer(context);
            },
          ),
          _NavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            active: selectedTab == DashboardTab.reports,
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.reports;
              _closeDrawer(context);
            },
          ),
          _NavItem(
            icon: Icons.calendar_month_rounded,
            label: 'Schedule',
            active: selectedTab == DashboardTab.schedule,
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.schedule;
              _closeDrawer(context);
            },
          ),
          _NavItem(
            icon: Icons.people_outline_rounded,
            label: 'Team',
            active: selectedTab == DashboardTab.team,
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.team;
              _closeDrawer(context);
            },
          ),
          const Spacer(),
          const Divider(color: Color(0xFF2C3140), height: 1),
          const SizedBox(height: 16),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            active: selectedTab == DashboardTab.settings,
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.settings;
              _closeDrawer(context);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _closeDrawer(BuildContext context) {
    if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
      Navigator.pop(context);
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4F6EF7).withOpacity(0.15) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Icon(
          icon,
          size: 19,
          color: active ? const Color(0xFF4F6EF7) : const Color(0xFF555B6A),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF555B6A),
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Top Bar (แก้ไขโครงสร้าง State ให้สมบูรณ์ ป้องกัน Error) ────────────────
class _TopBar extends ConsumerStatefulWidget {
  final String projectId;
  final DashboardTab selectedTab;
  const _TopBar({required this.projectId, required this.selectedTab});

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  final _supabase = Supabase.instance.client;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('users')
            .select('avatar_url')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _avatarUrl = data['avatar_url'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching avatar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECEFF4))),
      ),
      child: Row(
        children: [
          Text(
            _getTabTitle(widget.selectedTab),
            style: const TextStyle(
              color: Color(0xFF1A1D23),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF8A93A4),
              size: 20,
            ),
            onPressed: () {
              ref.invalidate(boqItemsProvider(widget.projectId));
              ref.invalidate(materialRequestsProvider(widget.projectId));
              _fetchAvatar();
            },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              ref.read(_dashboardTabProvider.notifier).state =
                  DashboardTab.settings;
            },
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFEEF1FE),
              backgroundImage: _avatarUrl != null
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: _avatarUrl == null
                  ? const Text(
                      'PM',
                      style: TextStyle(
                        color: Color(0xFF4F6EF7),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final List<BOQItem> items;
  const _SummaryCards({required this.items});

  @override
  Widget build(BuildContext context) {
    final totalBudget = items.fold(0.0, (s, i) => s + i.budgetAmount);
    final actualCost = items.fold(0.0, (s, i) => s + i.actualCost);
    final remaining = totalBudget - actualCost;
    final pct = totalBudget == 0
        ? 0.0
        : (actualCost / totalBudget).clamp(0.0, 1.0);
    final isOver = actualCost > totalBudget;

    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    final cards = [
      _MetricCard(
        label: 'Total Budget',
        value: _fmt(totalBudget),
        icon: Icons.account_balance_wallet_rounded,
        iconBg: const Color(0xFFEEF1FE),
        iconColor: const Color(0xFF4F6EF7),
        sub: '${items.length} BOQ items',
      ),
      _MetricCard(
        label: 'Actual Cost',
        value: _fmt(actualCost),
        icon: Icons.payments_rounded,
        iconBg: isOver ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
        iconColor: isOver ? const Color(0xFFEF5350) : const Color(0xFF00C896),
        sub: '${(pct * 100).toStringAsFixed(1)}% of budget used',
        highlight: isOver,
      ),
      _MetricCard(
        label: isOver ? 'Over Budget' : 'Remaining',
        value: _fmt(remaining.abs()),
        icon: isOver ? Icons.warning_amber_rounded : Icons.savings_rounded,
        iconBg: isOver ? const Color(0xFFFFF8E1) : const Color(0xFFF3E5F5),
        iconColor: isOver ? const Color(0xFFFFB547) : const Color(0xFF9C27B0),
        sub: isOver ? '⚠️ Exceeds total budget' : 'Available to spend',
        highlight: isOver,
      ),
      _BurnCard(pct: pct, isOver: isOver),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Budget Overview',
          style: TextStyle(
            color: Color(0xFF1A1D23),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        isDesktop
            ? Row(
                children: cards
                    .map(
                      (c) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: c == cards.last ? 0 : 16,
                          ),
                          child: c,
                        ),
                      ),
                    )
                    .toList(),
              )
            : Column(
                children: cards
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: c,
                      ),
                    )
                    .toList(),
              ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '฿${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '฿${(v / 1000).toStringAsFixed(1)}K';
    return '฿${v.toStringAsFixed(2)}';
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color iconBg, iconColor;
  final bool highlight;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.sub,
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              if (highlight)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    '!',
                    style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF1A1D23),
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A93A4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF8A93A4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BurnCard extends StatelessWidget {
  final double pct;
  final bool isOver;
  const _BurnCard({required this.pct, required this.isOver});
  @override
  Widget build(BuildContext context) {
    final barColor = isOver
        ? const Color(0xFFEF5350)
        : pct > 0.8
        ? const Color(0xFFFFB547)
        : const Color(0xFF4F6EF7);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Burn Rate',
                style: TextStyle(
                  color: Color(0xFF8A93A4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: barColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0%', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('50%', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(
                '100%',
                style: TextStyle(fontSize: 10, color: Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestsTable extends ConsumerWidget {
  final List<MaterialRequest> requests;
  final List<BOQItem> boqItems;
  final String projectId;
  const _RequestsTable({
    required this.requests,
    required this.boqItems,
    required this.projectId,
  });

  String _boqName(String? boqId, String itemName) {
    if (boqId == null) return itemName;
    return boqItems
        .firstWhere(
          (b) => b.id == boqId,
          orElse: () => BOQItem(
            id: '',
            projectId: '',
            name: itemName,
            category: null,
            budgetAmount: 0.0,
            actualCost: 0.0,
            progressPercent: 0.0,
          ),
        )
        .name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvingId = ref.watch(_approvingIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Requests',
              style: TextStyle(
                color: Color(0xFF1A1D23),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${requests.length} total',
              style: const TextStyle(color: Color(0xFF8A93A4), fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: requests.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No requests yet',
                      style: TextStyle(
                        color: Color(0xFF1A1D23),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8F9FC),
                      ),
                      columns: const [
                        DataColumn(label: Text('BOQ Item')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: requests.map((req) {
                        final isPending = req.status == RequestStatus.pending;
                        final isApproving = approvingId == req.id;
                        return DataRow(
                          cells: [
                            DataCell(Text(_boqName(req.boqId, req.itemName))),
                            DataCell(Text(req.requestedQty.toStringAsFixed(0))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: req.status == RequestStatus.pending
                                      ? Colors.orange.shade50
                                      : req.status == RequestStatus.approved
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  req.status.name,
                                  style: TextStyle(
                                    color: req.status == RequestStatus.pending
                                        ? Colors.orange
                                        : req.status == RequestStatus.approved
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              isPending
                                  ? ElevatedButton(
                                      onPressed: isApproving
                                          ? null
                                          : () async {
                                              ref
                                                      .read(
                                                        _approvingIdProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  req.id;
                                              await ref
                                                  .read(approvalServiceProvider)
                                                  .approveRequest(req.id);
                                              ref
                                                      .read(
                                                        _approvingIdProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  null;
                                              ref.invalidate(
                                                materialRequestsProvider(
                                                  projectId,
                                                ),
                                              );
                                              ref.invalidate(
                                                boqItemsProvider(projectId),
                                              );
                                            },
                                      child: isApproving
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Approve'),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TableShimmer extends StatelessWidget {
  const _TableShimmer();
  @override
  Widget build(BuildContext context) =>
      Container(height: 200, color: Colors.grey.shade200);
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});
  @override
  Widget build(BuildContext context) =>
      Text(message, style: const TextStyle(color: Colors.red));
}
