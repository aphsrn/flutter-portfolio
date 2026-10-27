import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'services/app_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://volaxbtgnuhqsxjmpqlp.supabase.co',
    anonKey: 'sb_publishable_AyBysk_Lkc6O1BYKf-NkDQ_DXb0rSIq',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    
    return MaterialApp(
      title: 'Smart Site',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F6EF7), brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F6EF7), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
