import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'data/chat_repository.dart';
import 'models/profile.dart';
import 'screens/login_screen.dart';
import 'screens/threads_screen.dart';
import 'theme/app_theme.dart';

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
  late final ChatRepository _repository;
  Session? _session;
  Profile? _profile;
  bool _loadingProfile = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository(client: Supabase.instance.client);
    _session = Supabase.instance.client.auth.currentSession;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {
        _session = data.session;
        if (data.session == null) {
          _profile = null;
          _profileError = null;
        }
      });
      if (data.session != null) {
        _loadProfile();
      }
    });
    if (_session != null) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (_loadingProfile) return;
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await _repository.fetchMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadingProfile = false;
        if (profile == null) {
          _profileError =
              'No profile row for this account. Use a seeded demo user.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = e.toString();
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    setState(() {
      _session = null;
      _profile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_session == null) {
      home = LoginScreen(onSignedIn: () {});
    } else if (_loadingProfile || (_profile == null && _profileError == null)) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (_profile == null) {
      home = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _profileError ?? 'Profile missing',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      home = ThreadsScreen(
        repository: _repository,
        profile: _profile!,
        onSignOut: _signOut,
      );
    }

    return MaterialApp(
      title: 'Deskline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home,
    );
  }
}
