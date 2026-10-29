import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'core/helpers.dart';
import 'core/models.dart';
import 'data/repositories.dart';
import 'screens/guard/guard_home_screen.dart';
import 'screens/organizer/organizer_home_screen.dart';
import 'screens/resident/resident_home_screen.dart';
import 'screens/shared/auth_screen.dart';
import 'screens/shared/setup_screen.dart';
import 'widgets/shared_widgets.dart';

// Global Theme Controller
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('dastak_theme_mode') ?? 'system';
  switch (themeStr) {
    case 'light':
      themeNotifier.value = ThemeMode.light;
      break;
    case 'dark':
      themeNotifier.value = ThemeMode.dark;
      break;
    default:
      themeNotifier.value = ThemeMode.system;
  }
}

Future<void> saveTheme(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('dastak_theme_mode', mode.name);
}

class DastakApp extends StatelessWidget {
  const DastakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          initialRoute: '/',
          routes: {
            '/': (_) => const RootGate(),
            '/auth': (_) => const AuthScreen(),
            '/setup': (_) => const SetupScreen(),
            '/resident': (_) => const ResidentHomeScreen(),
            '/organizer': (_) => const OrganizerHomeScreen(),
            '/guard': (_) => const GuardHomeScreen(),
          },
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Base Color Scheme
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      background: isDark ? const Color(0xFF121212) : AppColors.background,
      surface: isDark ? const Color(0xFF1E1E1E) : AppColors.surface,
      error: AppColors.danger,
    );

    // Typography adjustments for Dark Mode
    final textTheme = TextTheme(
      displayLarge: AppTextStyles.h1
          .copyWith(color: isDark ? Colors.white : AppColors.textPrimary),
      displayMedium: AppTextStyles.h2
          .copyWith(color: isDark ? Colors.white : AppColors.textPrimary),
      displaySmall: AppTextStyles.h3
          .copyWith(color: isDark ? Colors.white : AppColors.textPrimary),
      bodyLarge: AppTextStyles.bodyLarge
          .copyWith(color: isDark ? Colors.white : AppColors.textPrimary),
      bodyMedium: AppTextStyles.bodyMedium
          .copyWith(color: isDark ? Colors.white70 : AppColors.textPrimary),
      bodySmall: AppTextStyles.bodySmall
          .copyWith(color: isDark ? Colors.white60 : AppColors.textSecondary),
      labelLarge: AppTextStyles.label
          .copyWith(color: isDark ? Colors.white70 : AppColors.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121212) : AppColors.background,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme:
            IconThemeData(color: isDark ? Colors.white : AppColors.textPrimary),
        titleTextStyle: AppTextStyles.h3
            .copyWith(color: isDark ? Colors.white : AppColors.textPrimary),
      ),

      // Inputs (Soft squircle) — FORCED LIGHT PALETTE
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
          side: BorderSide(
              color: isDark ? Colors.white24 : AppColors.surfaceMuted,
              width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle:
              AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : AppColors.surfaceMuted,
        thickness: 1,
      ),
    );
  }
}

// ============================================================================
// ROOT GATE (Identity & Routing)
// ============================================================================

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  late Future<Profile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    // This calls the database, with a local cache fallback.
    _profileFuture = authService.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: LoadingView(),
          );
        }

        // 2. Error State (Shows actual error instead of looping)
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 64),
                    const SizedBox(height: 16),
                    Text('Error loading profile', style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      errorText(snapshot.error!),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _profileFuture = authService.loadProfile();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/auth', (route) => false);
                        }
                      },
                      child: const Text(
                        'Sign Out & Start Over',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 3. Not Signed In
        if (snapshot.data == null) {
          return const AuthScreen();
        }

        final profile = snapshot.data!;

        // 4. Revoked Account Check
        if (profile.status == ProfileStatus.revoked) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block, size: 64, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(
                      'Account Revoked',
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your access has been revoked by an administrator. Please contact support.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/auth');
                        }
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 5. Setup Incomplete
        if (!profile.isSetupComplete) {
          return const SetupScreen();
        }

        // 6. Route by Role
        switch (profile.role) {
          case UserRole.resident:
          case UserRole.admin:
            return const ResidentHomeScreen();
          case UserRole.organizer:
            return const OrganizerHomeScreen();
          case UserRole.guard:
            return const GuardHomeScreen();
          case null:
            // Fallback for corrupted state
            return const AuthScreen();
        }
      },
    );
  }
}
