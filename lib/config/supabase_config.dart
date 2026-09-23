/// Public client config only. Never put service_role or PAT keys here.
class SupabaseConfig {
  static const String url = 'https://hwfgytocskiovcqyxpwf.supabase.co';

  /// Legacy anon JWT (safe for client apps). Prefer this with supabase_flutter.
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Zmd5dG9jc2tpb3ZjcXl4cHdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjU2ODcsImV4cCI6MjEwNTc0MTY4N30.mZJbQ8lpk3rL6Ln28ePuZrW9VYRgjvZd8Nj1q-gSwpw';

  static const int maxMessageLength = 500;
  static const Duration sendCooldown = Duration(milliseconds: 700);

  /// Learner demo account.
  static const String learnerEmail = 'learner@deskline.app';
  static const String learnerPassword = 'DemoChat123!';

  /// Mentor demo account (use in a second client).
  static const String mentorEmail = 'mentor@deskline.app';
  static const String mentorPassword = 'DemoChat123!';
}
