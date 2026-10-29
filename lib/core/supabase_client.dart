import 'package:supabase_flutter/supabase_flutter.dart';

// FILL THESE IN AT THE END, AFTER ALL FILES ARE PASTED.
// Find these in: Supabase Dashboard -> Project Settings -> API

const String kSupabaseUrl = 'https://feernylpuhzqhggallrp.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZlZXJueWxwdWh6cWhnZ2FsbHJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyMTM3NjEsImV4cCI6MjEwODc4OTc2MX0.Qd3z9puEibFBUqHua_kEE70BsLUU_9yOi607LFWrkkU';

bool get isSupabaseConfigured =>
    kSupabaseUrl != 'PASTE_YOUR_SUPABASE_URL_HERE' &&
    kSupabaseAnonKey != 'PASTE_YOUR_SUPABASE_ANON_KEY_HERE';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
