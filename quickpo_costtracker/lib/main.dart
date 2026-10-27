// lib/main.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart'; // DashboardScreen
import 'screens/create_pr_screen.dart'; // CreatePRScreen
import 'screens/approvals_screen.dart'; // ApprovalsScreen
import 'screens/profile_settings_screen.dart'; // ProfileSettingsScreen

// ====== Supabase Config (โปรเจกต์ QuickPO-DB) ======
const String kSupabaseUrl = 'https://rlkwsdxukaltqncqhrcb.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_ecw_l_wFB5XcAXWtfCLkOA_IjSPLC1y';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (Session ของผู้ใช้ถูกเก็บและกู้คืนอัตโนมัติ)
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  runApp(const QuickPOApp());
}

// Shortcut สำหรับเรียกใช้ Supabase client ทั่วแอพ
final supabase = Supabase.instance.client;

// ====== Global State (ใช้ร่วมกับหน้า Profile / Login) ======
final ValueNotifier<String?> globalAvatarUrl = ValueNotifier<String?>(null);
final ValueNotifier<Uint8List?> globalAvatarBytes =
    ValueNotifier<Uint8List?>(null);
final ValueNotifier<String> globalLanguage = ValueNotifier<String>('th');

// ====== Enterprise Color Palette ======
class AppColors {
  static const Color navy = Color(0xFF1F3A5F); // กรมท่าหลัก
  static const Color navyDark = Color(0xFF14263F);
  static const Color navyLight = Color(0xFF2E5384);
  static const Color background = Color(0xFFF4F6F9); // เทาอ่อน
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD9DEE5);
  static const Color textPrimary = Color(0xFF1B2433);
  static const Color textSecondary = Color(0xFF6B7788);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED8F00);
  static const Color danger = Color(0xFFC62828);

  // โทนมืด (Dark Mode)
  static const Color darkBackground = Color(0xFF0F1722);
  static const Color darkSurface = Color(0xFF1A2432);
  static const Color darkBorder = Color(0xFF2C3A4D);
}

// ====== ข้อความหลักของแอพ 2 ภาษา (ภาษาอื่นใช้ EN สำรอง) ======
const Map<String, Map<String, String>> kAppTexts = {
  'th': {
    'appTitle': 'QuickPO & Cost Tracker',
    'dashboard': 'Dashboard',
    'createPR': 'สร้างคำขอซื้อ',
    'approvals': 'รายการอนุมัติ',
    'profile': 'โปรไฟล์',
  },
  'en': {
    'appTitle': 'QuickPO & Cost Tracker',
    'dashboard': 'Dashboard',
    'createPR': 'Create PR',
    'approvals': 'Approvals',
    'profile': 'Profile',
  },
};

// ====== Root App (เก็บ State ธีม) ======
class QuickPOApp extends StatefulWidget {
  const QuickPOApp({super.key});

  @override
  State<QuickPOApp> createState() => _QuickPOAppState();
}

class _QuickPOAppState extends State<QuickPOApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickPO & Cost Tracker',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: _AuthGate(
        themeMode: _themeMode,
        onThemeChanged: _setThemeMode,
      ),
    );
  }

  // ====== Enterprise / ERP Theme (Light + Dark) ======
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.navyLight : AppColors.navy;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final textSecondary =
        isDark ? const Color(0xFF9AA7B8) : AppColors.textSecondary;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: AppColors.navyLight,
      surface: surface,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.navyDark : AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(isDark ? 0.35 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? (isDark ? Colors.white : AppColors.navy)
                : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? Colors.white : AppColors.navy)
                : textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.navyDark,
        indicatorColor: AppColors.navyLight,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: Colors.white60),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.navy,
          side: BorderSide(color: isDark ? Colors.white54 : AppColors.navy),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: bg,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

// ====== Auth Gate: Login แล้ว -> แอปหลัก / ยังไม่ Login -> หน้า Login ======
class _AuthGate extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const _AuthGate({
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  Session? _session = supabase.auth.currentSession;

  @override
  void initState() {
    super.initState();
    _sub = supabase.auth.onAuthStateChange.listen((data) {
      final s = data.session;

      // ออกจากระบบ: ล้างรูปโปรไฟล์ที่ค้างอยู่ใน Global State
      if (s == null) {
        globalAvatarUrl.value = null;
        globalAvatarBytes.value = null;
      }

      // rebuild เฉพาะเมื่อสถานะ/ผู้ใช้เปลี่ยน (ไม่ rebuild ตอน token refresh)
      final changed =
          (s == null) != (_session == null) || s?.user.id != _session?.user.id;
      if (mounted && changed) setState(() => _session = s);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const LoginScreen();

    return MainShell(
      key: ValueKey(session.user.id),
      themeMode: widget.themeMode,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}

// ====== Navigation Item Model ======
class _NavItem {
  final String labelKey; // key ใน kAppTexts
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const _NavItem({
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}

// ====== Main Shell (Responsive: BottomNav / NavigationRail) ======
class MainShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const MainShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // รายการหน้าทั้ง 3
  final List<_NavItem> _items = const [
    _NavItem(
      labelKey: 'dashboard',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      page: DashboardScreen(),
    ),
    _NavItem(
      labelKey: 'createPR',
      icon: Icons.note_add_outlined,
      selectedIcon: Icons.note_add,
      page: CreatePRScreen(),
    ),
    _NavItem(
      labelKey: 'approvals',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
      page: ApprovalsScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  String tr(String key, String lang) =>
      kAppTexts[lang]?[key] ?? kAppTexts['en']![key] ?? key;

  void _onSelect(int index) => setState(() => _currentIndex = index);

  // โหลดรูปโปรไฟล์ของผู้ใช้ที่ Login มาแสดงที่มุมขวาบน
  Future<void> _loadAvatar() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', uid)
          .maybeSingle();
      final url = res?['avatar_url'] as String?;
      if (url != null && url.isNotEmpty) {
        globalAvatarUrl.value = url;
        globalAvatarBytes.value = null;
      }
    } catch (_) {}
  }

  // เปิดหน้า Profile & Settings
  void _openProfile() {
    // เก็บ Navigator ไว้ก่อน เพราะหลัง Logout หน้านี้จะถูกแทนที่ด้วยหน้า Login
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute(
        builder: (_) => ProfileSettingsScreen(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
          onLoggedOut: () => nav.popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  Widget _buildAvatarButton(String lang) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        tooltip: tr('profile', lang),
        onPressed: _openProfile,
        icon: ValueListenableBuilder<Uint8List?>(
          valueListenable: globalAvatarBytes,
          builder: (_, bytes, __) => ValueListenableBuilder<String?>(
            valueListenable: globalAvatarUrl,
            builder: (_, url, __) {
              final ImageProvider? img = bytes != null
                  ? MemoryImage(bytes)
                  : (url != null ? NetworkImage(url) : null);
              return CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.navyLight,
                backgroundImage: img,
                child: img == null
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: globalLanguage,
      builder: (context, lang, _) {
        final isWide = MediaQuery.of(context).size.width >= 800;
        final current = _items[_currentIndex];

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.receipt_long, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(tr('appTitle', lang),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                if (isWide)
                  Text(
                    '/ ${tr(current.labelKey, lang)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
            actions: [_buildAvatarButton(lang)],
          ),
          body: Row(
            children: [
              // จอกว้าง: ใช้ NavigationRail ด้านข้าง
              if (isWide)
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onSelect,
                  labelType: NavigationRailLabelType.all,
                  destinations: _items
                      .map(
                        (e) => NavigationRailDestination(
                          icon: Icon(e.icon),
                          selectedIcon: Icon(e.selectedIcon),
                          label: Text(tr(e.labelKey, lang)),
                        ),
                      )
                      .toList(),
                ),
              // เก็บ state ของแต่ละหน้าไว้ด้วย IndexedStack
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _items.map((e) => e.page).toList(),
                ),
              ),
            ],
          ),
          // จอแคบ: ใช้ BottomNavigationBar (NavigationBar M3)
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onSelect,
                  destinations: _items
                      .map(
                        (e) => NavigationDestination(
                          icon: Icon(e.icon),
                          selectedIcon: Icon(e.selectedIcon),
                          label: tr(e.labelKey, lang),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}
