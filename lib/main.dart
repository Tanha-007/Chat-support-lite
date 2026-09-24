import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'data/chat_repository.dart';
import 'data/errors.dart';
import 'data/moderation_repository.dart';
import 'models/profile.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/empty_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const DesklineApp());
}

class DesklineApp extends StatefulWidget {
  const DesklineApp({super.key});

  @override
  State<DesklineApp> createState() => _DesklineAppState();
}

class _DesklineAppState extends State<DesklineApp> {
  final _client = Supabase.instance.client;
  late final ChatRepository _chat = ChatRepository(client: _client);
  late final ModerationRepository _moderation = ModerationRepository(
    client: _client,
  );
  StreamSubscription<AuthState>? _authSub;

  Session? _session;
  Profile? _profile;
  bool _loadingProfile = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _session = _client.auth.currentSession;
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final previousUser = _session?.user.id;
      setState(() {
        _session = data.session;
        if (data.session == null) {
          _profile = null;
          _profileError = null;
        }
      });
      if (data.session != null && data.session!.user.id != previousUser) {
        _loadProfile();
      }
    });
    if (_session != null) _loadProfile();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_loadingProfile) return;
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await _chat.fetchMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadingProfile = false;
        if (profile == null) {
          _profileError =
              'Your profile is still being set up. Try again in a moment.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = friendlyError(e);
      });
    }
  }

  Future<void> _signOut() async {
    await _client.removeAllChannels();
    await _client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_session == null) {
      home = const LoginScreen();
    } else if (_profile != null) {
      home = HomeShell(
        key: ValueKey(_profile!.id),
        chat: _chat,
        moderation: _moderation,
        profile: _profile!,
        onProfileChanged: (p) => setState(() => _profile = p),
        onSignOut: _signOut,
      );
    } else if (_profileError != null) {
      home = Scaffold(
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Could not load your profile',
          subtitle: _profileError!,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: _signOut,
                child: const Text('Sign out'),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else {
      home = const Scaffold(
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Deskline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: home,
      ),
    );
  }
}
