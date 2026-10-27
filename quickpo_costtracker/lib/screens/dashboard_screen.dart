// lib/screens/dashboard_screen.dart
// Real-time: ฟัง Stream จากตาราง purchase_requests / pr_items / departments
// (ต้องรัน supabase/upgrade_v2.sql เพื่อเปิด Realtime) แล้ว re-fetch View อัตโนมัติ
// หมายเหตุ: View ใช้ .stream() ตรงๆ ไม่ได้ จึงฟังตารางต้นทางแทน
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart'; // supabase, AppColors

// ====== Helpers ======
double _n(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

List<Map<String, dynamic>> _asList(dynamic res) =>
    List<Map<String, dynamic>>.from(res as List);

String _short(double v) {
  if (v.abs() >= 1000000) return '฿${(v / 1000000).toStringAsFixed(2)}M';
  if (v.abs() >= 1000) return '฿${(v / 1000).toStringAsFixed(1)}K';
  return '฿${v.toStringAsFixed(0)}';
}

// สีของ Pie Chart (โทน Enterprise)
const List<Color> _pieColors = [
  Color(0xFF1F4E79),
  Color(0xFF2E75B6),
  Color(0xFFED8F00),
  Color(0xFF2E7D32),
  Color(0xFF7B1FA2),
  Color(0xFF00897B),
  Color(0xFFC62828),
  Color(0xFF6B7788),
];

// ====== Model ข้อมูลทั้งหน้า ======
class _DashData {
  final List<Map<String, dynamic>> depts; // vw_department_budget_bi
  final List<Map<String, dynamic>> categories; // vw_category_spend
  final int pendingCount;
  final double pendingTotal;

  const _DashData({
    required this.depts,
    required this.categories,
    required this.pendingCount,
    required this.pendingTotal,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);

  final StreamController<_DashData> _ctrl =
      StreamController<_DashData>.broadcast();
  final List<StreamSubscription> _subs = [];
  Timer? _debounce;

  _DashData? _last; // ข้อมูลล่าสุด (กันจอ error ทับข้อมูลเดิมเมื่อเน็ตสะดุด)
  bool _live = false; // สถานะ Realtime
  bool _showLineTrend = true; // สวิตช์เปิด/ปิดเส้นกราฟ
  int _touchedIndex = -1; // ชิ้นที่แตะบน Pie

  @override
  void initState() {
    super.initState();
    _startRealtime();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _ctrl.close();
    super.dispose();
  }

  // ====== Realtime ======
  void _startRealtime() {
    for (final table in ['purchase_requests', 'pr_items', 'departments']) {
      _subs.add(
        supabase.from(table).stream(primaryKey: ['id']).listen(
          (_) {
            _setLive(true);
            _scheduleReload();
          },
          onError: (_) => _setLive(false),
        ),
      );
    }
  }

  void _setLive(bool v) {
    if (_live != v && mounted) setState(() => _live = v);
  }

  // รวมหลาย event ให้โหลดครั้งเดียว
  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    try {
      final d = await _fetchAll();
      _last = d;
      if (!_ctrl.isClosed) _ctrl.add(d);
    } catch (e, st) {
      if (!_ctrl.isClosed) _ctrl.addError(e, st);
    }
  }

  Future<_DashData> _fetchAll() async {
    final depts = _asList(await supabase
        .from('vw_department_budget_bi')
        .select()
        .order('department_name', ascending: true));

    // ส่วนเสริม: ถ้ายังไม่ได้รัน SQL อัปเกรด ให้ข้ามโดยไม่ทำให้หน้าพัง
    List<Map<String, dynamic>> cats = [];
    try {
      cats = _asList(await supabase
          .from('vw_category_spend')
          .select()
          .order('total_spent', ascending: false));
    } catch (_) {}

    int pendingCount = 0;
    double pendingTotal = 0;
    try {
      final p = _asList(await supabase
          .from('purchase_requests')
          .select('total_amount')
          .eq('status', 'pending'));
      pendingCount = p.length;
      pendingTotal = p.fold<double>(0, (s, e) => s + _n(e['total_amount']));
    } catch (_) {}

    return _DashData(
      depts: depts,
      categories: cats,
      pendingCount: pendingCount,
      pendingTotal: pendingTotal,
    );
  }

  // ====== Build ======
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // SafeArea ช่วยป้องกันเนื้อหาแอพไปชนขอบรอยบาก (Notch) บนจอมือถือ
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: StreamBuilder<_DashData>(
            stream: _ctrl.stream,
            builder: (context, snapshot) {
              final data = snapshot.data ?? _last;

              if (data == null) {
                if (snapshot.hasError) return _buildError(snapshot.error);
                return const Center(child: CircularProgressIndicator());
              }
              if (data.depts.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Center(child: Text('ไม่พบข้อมูลงบประมาณ')),
                  ],
                );
              }
              return _buildContent(data, isDark);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(Object? err) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('เกิดข้อผิดพลาด: $err', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(
                  onPressed: _reload, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(_DashData d, bool isDark) {
    final data = d.depts;

    double totalBudget = 0, totalSpent = 0;
    for (var item in data) {
      totalBudget += _n(item['allocated_budget']);
      totalSpent += _n(item['actual_spent']);
    }
    final double remaining = totalBudget - totalSpent;

    // MediaQuery เช็คขนาดหน้าจอ (ถ้ากว้างน้อยกว่า 600 ถือว่าเป็น Mobile)
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Insight Summary (ใหม่)
          _buildInsightHeader(d, totalBudget, totalSpent),
          const SizedBox(height: 20),

          // 1. KPI Cards (มือถือเรียงแนวตั้ง / จอใหญ่เรียงแนวนอน)
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            children: [
              _buildKpiCard(
                title: 'Total Budget',
                amount: _fmt.format(totalBudget),
                icon: Icons.account_balance_wallet_outlined,
                iconColor: Colors.blueAccent,
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 12 : 0),
              _buildKpiCard(
                title: 'Actual Spent',
                amount: _fmt.format(totalSpent),
                icon: Icons.payments_outlined,
                iconColor: Colors.orangeAccent,
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 12 : 0),
              _buildKpiCard(
                title: 'Remaining',
                amount: _fmt.format(remaining),
                icon: Icons.savings_outlined,
                iconColor: Colors.greenAccent,
                isMobile: isMobile,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Budget vs Actual (Bar + Trend)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Budget vs Actual',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('รายแผนก',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                          Row(
                            children: [
                              const Text('แสดงเส้นแนวโน้ม',
                                  style: TextStyle(fontSize: 12)),
                              Switch(
                                value: _showLineTrend,
                                onChanged: (v) =>
                                    setState(() => _showLineTrend = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildLegend(
                          color: const Color(0xFF1F4E79), text: 'Budget'),
                      _buildLegend(
                          color: Colors.amber.shade700, text: 'Actual'),
                      if (_showLineTrend)
                        _buildLegend(
                            color: Colors.cyanAccent,
                            text: 'Trend',
                            isLine: true),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        BarChart(_buildBarChartData(data, isDark)),
                        if (_showLineTrend)
                          LineChart(_buildLineChartData(data)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Pie Chart สัดส่วนค่าใช้จ่ายตามหมวดหมู่ (ใหม่)
          _buildPieCard(d.categories),

          const SizedBox(height: 20),

          // 4. Utilization Rate
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Utilization Rate',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'สีแดง = ใช้เงินเกิน 80%',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...data.map((dept) => _buildUtilRow(dept, isDark)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40), // เผื่อพื้นที่ด้านล่างสุด
        ],
      ),
    );
  }

  // ====== Insight Summary Header ======
  Widget _buildInsightHeader(
      _DashData d, double totalBudget, double totalSpent) {
    final overall = totalBudget > 0 ? totalSpent / totalBudget : 0.0;

    final overs = <String>[];
    String topName = '-';
    double topSpent = 0;
    for (final x in d.depts) {
      final b = _n(x['allocated_budget']);
      final s = _n(x['actual_spent']);
      final name = '${x['department_name'] ?? '-'}';
      if (b > 0 && s / b >= 0.8) overs.add(name);
      if (s > topSpent) {
        topSpent = s;
        topName = name;
      }
    }

    final catTotal =
        d.categories.fold<double>(0, (s, e) => s + _n(e['total_spent']));
    String topCat = '-';
    String topCatSub = 'ยังไม่มีข้อมูล';
    if (d.categories.isNotEmpty && catTotal > 0) {
      final top = d.categories.reduce(
          (a, b) => _n(a['total_spent']) >= _n(b['total_spent']) ? a : b);
      topCat = '${top['category']}';
      topCatSub =
          '${(_n(top['total_spent']) / catTotal * 100).toStringAsFixed(1)}% ของค่าใช้จ่าย';
    }

    final tiles = [
      _InsightTile(
        icon: overs.isEmpty
            ? Icons.verified_outlined
            : Icons.warning_amber_rounded,
        label: 'แผนกใช้งบเกิน 80%',
        value: '${overs.length} แผนก',
        sub: overs.isEmpty ? 'ปกติทุกแผนก' : overs.join(', '),
        warn: overs.isNotEmpty,
      ),
      _InsightTile(
        icon: Icons.trending_up,
        label: 'ใช้จ่ายสูงสุด',
        value: topName,
        sub: topSpent > 0 ? _fmt.format(topSpent) : '-',
      ),
      _InsightTile(
        icon: Icons.hourglass_top,
        label: 'รออนุมัติ',
        value: '${d.pendingCount} รายการ',
        sub: _fmt.format(d.pendingTotal),
      ),
      _InsightTile(
        icon: Icons.category_outlined,
        label: 'หมวดหมู่สูงสุด',
        value: topCat,
        sub: topCatSub,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Insight Summary',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              _buildLiveChip(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'ใช้งบไปแล้ว ${(overall * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: overall >= 0.8 ? const Color(0xFFFF8A80) : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('จากงบรวม ${_fmt.format(totalBudget)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: overall.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                overall >= 0.8 ? const Color(0xFFFF8A80) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 4 : 2;
            const gap = 10.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLiveChip() {
    final color = _live ? const Color(0xFF69F0AE) : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(_live ? 'LIVE' : 'MANUAL',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ====== Pie Chart: สัดส่วนค่าใช้จ่ายตามหมวดหมู่ ======
  Widget _buildPieCard(List<Map<String, dynamic>> cats) {
    final total = cats.fold<double>(0, (s, e) => s + _n(e['total_spent']));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สัดส่วนค่าใช้จ่ายตามหมวดหมู่',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('เฉพาะคำขอซื้อที่อนุมัติแล้ว',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            if (total <= 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('ยังไม่มีข้อมูลค่าใช้จ่ายตามหมวดหมู่',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 560;

                final pie = SizedBox(
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          borderData: FlBorderData(show: false),
                          pieTouchData: PieTouchData(
                            touchCallback: (event, resp) {
                              final idx = (!event.isInterestedForInteractions ||
                                      resp?.touchedSection == null)
                                  ? -1
                                  : resp!.touchedSection!.touchedSectionIndex;
                              if (idx != _touchedIndex) {
                                setState(() => _touchedIndex = idx);
                              }
                            },
                          ),
                          sections: List.generate(cats.length, (i) {
                            final v = _n(cats[i]['total_spent']);
                            final pct = v / total * 100;
                            final touched = i == _touchedIndex;
                            return PieChartSectionData(
                              value: v,
                              color: _pieColors[i % _pieColors.length],
                              radius: touched ? 70 : 60,
                              title:
                                  pct >= 6 ? '${pct.toStringAsFixed(0)}%' : '',
                              titleStyle: TextStyle(
                                fontSize: touched ? 14 : 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
                      ),
                      // ยอดรวมกลางวงกลม
                      IgnorePointer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('รวม',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text(_short(total),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                final legend = Column(
                  children: [
                    for (int i = 0; i < cats.length; i++)
                      _buildPieLegendRow(i, cats[i], total),
                  ],
                );

                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 5, child: pie),
                          const SizedBox(width: 16),
                          Expanded(flex: 6, child: legend),
                        ],
                      )
                    : Column(children: [
                        pie,
                        const SizedBox(height: 12),
                        legend,
                      ]);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPieLegendRow(int i, Map<String, dynamic> cat, double total) {
    final v = _n(cat['total_spent']);
    final color = _pieColors[i % _pieColors.length];
    final touched = i == _touchedIndex;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: touched ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${cat['category']}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(_short(v),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text('${(v / total * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ====== Utilization Row ======
  Widget _buildUtilRow(Map<String, dynamic> dept, bool isDark) {
    final budget = _n(dept['allocated_budget']);
    final spent = _n(dept['actual_spent']);
    final double pct = budget > 0 ? (spent / budget) : 0.0;
    final bool isOver = pct >= 0.8;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isOver
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 18,
                      color: isOver ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dept['department_name'] ?? 'ไม่ระบุ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isOver
                      ? Colors.red.withOpacity(0.15)
                      : Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOver ? Colors.red : Colors.green,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? Colors.red : const Color(0xFF1F4E79),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Wrap ป้องกันตัวหนังสือชนกันบนจอเล็ก
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text('ใช้ไป ${_fmt.format(spent)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text('เหลือ ${_fmt.format(budget - spent)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // ====== Data Configuration: Bar Chart ======
  BarChartData _buildBarChartData(
      List<Map<String, dynamic>> data, bool isDark) {
    double maxVal = 100000;
    for (var d in data) {
      final b = _n(d['allocated_budget']);
      final s = _n(d['actual_spent']);
      if (b > maxVal) maxVal = b;
      if (s > maxVal) maxVal = s;
    }

    return BarChartData(
      maxY: maxVal * 1.25,
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 55,
            getTitlesWidget: (val, meta) {
              if (val == 0) {
                return const Text('฿0',
                    style: TextStyle(fontSize: 11, color: Colors.grey));
              }
              return Text('฿${(val / 1000).toInt()}K',
                  style: const TextStyle(fontSize: 10, color: Colors.grey));
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (val, meta) {
              final idx = val.toInt();
              if (idx >= 0 && idx < data.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    data[idx]['department_name'] ?? '',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (val) => FlLine(
          color: isDark ? Colors.white12 : Colors.black12,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(data.length, (i) {
        final budget = _n(data[i]['allocated_budget']);
        final spent = _n(data[i]['actual_spent']);

        return BarChartGroupData(
          x: i,
          barsSpace: 6,
          barRods: [
            // แท่ง Budget
            BarChartRodData(
              toY: budget,
              color: const Color(0xFF1F4E79),
              width: 18,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            // แท่ง Actual Spent
            BarChartRodData(
              toY: spent,
              color: Colors.amber.shade700,
              width: 18,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }),
    );
  }

  // ====== Data Configuration: Line Chart Overlay ======
  LineChartData _buildLineChartData(List<Map<String, dynamic>> data) {
    double maxVal = 100000;
    for (var d in data) {
      final b = _n(d['allocated_budget']);
      final s = _n(d['actual_spent']);
      if (b > maxVal) maxVal = b;
      if (s > maxVal) maxVal = s;
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), _n(data[i]['actual_spent'])));
    }

    return LineChartData(
      minX: 0,
      maxX: data.length > 1 ? (data.length - 1).toDouble() : 1,
      minY: 0,
      maxY: maxVal * 1.25,
      lineTouchData: const LineTouchData(enabled: false),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: Colors.cyanAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: Colors.cyanAccent,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.cyanAccent.withOpacity(0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required bool isMobile,
  }) {
    Widget cardContent = Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(amount,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return isMobile ? cardContent : Expanded(child: cardContent);
  }

  Widget _buildLegend(
      {required Color color, required String text, bool isLine = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(width: 16, height: 3, color: color)
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// ====== Tile ย่อยใน Insight Summary ======
class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final bool warn;

  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = warn ? const Color(0xFFFF8A80) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warn ? const Color(0xFFFF8A80) : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: accent, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}