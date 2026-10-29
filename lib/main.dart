import 'package:flutter/material.dart';

import 'app.dart';
import 'core/constants.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Check if Supabase is configured (prevents crash on first run)
  if (!isSupabaseConfigured) {
    runApp(const _ConfigMissingApp());
    return;
  }

  // 2. Initialize Database Connection
  await initSupabase();

  // 3. Load User Preferences (Theme)
  await loadSavedTheme();

  // 4. Launch App
  runApp(const DastakApp());
}

// ============================================================================
// FALLBACK APP (If Supabase keys are missing)
// ============================================================================

class _ConfigMissingApp extends StatelessWidget {
  const _ConfigMissingApp();

  @override
  Widget build(BuildContext context) {
    // We can't use the main theme here safely without initializing things,
    // so we build a clean, standalone fallback UI.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: kAppName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Supabase Not Linked',
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open lib/core/supabase_client.dart and replace the two '
                    'PASTE_YOUR... placeholders with your Project URL and anon key, '
                    'then restart the app.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'dastak/lib/core/supabase_client.dart',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
