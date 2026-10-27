import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🚀 Provider สำหรับเก็บค่า โหมดมืด (Dark Mode)
final isDarkModeProvider = StateProvider<bool>((ref) => false);

// 🚀 Provider สำหรับเก็บค่า ภาษา (Language)
final languageProvider = StateProvider<String>((ref) => 'ไทย');