import 'package:flutter_test/flutter_test.dart';

import 'package:chat_support_lite/config/supabase_config.dart';

void main() {
  test('message length cap matches assignment guard', () {
    expect(SupabaseConfig.maxMessageLength, 500);
    expect(SupabaseConfig.learnerEmail.contains('@'), isTrue);
    expect(SupabaseConfig.mentorEmail.contains('@'), isTrue);
  });
}
