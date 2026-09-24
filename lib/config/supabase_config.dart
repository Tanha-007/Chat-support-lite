/// Public client config only. Never put service_role or PAT keys here.
class SupabaseConfig {
  static const String url = 'https://hwfgytocskiovcqyxpwf.supabase.co';

  /// Legacy anon JWT (safe for client apps).
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3Zmd5dG9jc2tpb3ZjcXl4cHdmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjU2ODcsImV4cCI6MjEwNTc0MTY4N30.mZJbQ8lpk3rL6Ln28ePuZrW9VYRgjvZd8Nj1q-gSwpw';

  /// Mirrors the `messages_body_length` check constraint.
  static const int maxMessageLength = 500;

  /// Counter appears once a draft passes this length.
  static const int counterThreshold = 400;

  static const int minTopicLength = 3;
  static const int maxTopicLength = 80;
  static const int minNameLength = 2;
  static const int maxNameLength = 40;
  static const int maxHeadlineLength = 80;
  static const int maxReportNoteLength = 300;
  static const int minPasswordLength = 8;

  /// Client side cooldown. The server also caps 5 messages per 10 seconds.
  static const Duration sendCooldown = Duration(milliseconds: 700);

  static const String demoPassword = 'DemoChat123!';

  static const List<DemoAccount> demoAccounts = [
    DemoAccount(
      email: 'learner@deskline.app',
      name: 'Ava Brooks',
      role: 'learner',
    ),
    DemoAccount(email: 'mentor@deskline.app', name: 'Noah Kim', role: 'mentor'),
    DemoAccount(email: 'iris@deskline.app', name: 'Iris Chen', role: 'mentor'),
    DemoAccount(
      email: 'moderator@deskline.app',
      name: 'Sam Ortiz',
      role: 'moderator',
    ),
  ];
}

class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.name,
    required this.role,
  });

  final String email;
  final String name;
  final String role;
}
