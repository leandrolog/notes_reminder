import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/note_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initializeNotifications();

  runApp(const NotesReminderApp());
}

class NotesReminderApp extends StatelessWidget {
  const NotesReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NoteProvider()..loadNotes(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BCD4)),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF29B6F6),
            secondary: Color(0xFF26C6DA),
            tertiary: Color(0xFFFFB74D),
            surface: Color(0xFF161B2F),
            error: Color(0xFFEF5350),
          ),
          scaffoldBackgroundColor: const Color(0xFF0B1020),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Color(0xFF161B2F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFFEAF2FF),
            centerTitle: false,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF26C6DA),
            foregroundColor: Color(0xFF041022),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF131A30),
            hintStyle: const TextStyle(color: Color(0xFF8A96B8)),
            labelStyle: const TextStyle(color: Color(0xFFAFC7FF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2A3556)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2A3556)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF26C6DA), width: 1.4),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
