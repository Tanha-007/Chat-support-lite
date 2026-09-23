import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController(text: SupabaseConfig.learnerEmail);
  final _password = TextEditingController(text: SupabaseConfig.learnerPassword);
  bool _loading = false;
  bool _isSignUp = false;
  String? _error;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fillDemo(bool mentor) {
    setState(() {
      _email.text =
          mentor ? SupabaseConfig.mentorEmail : SupabaseConfig.learnerEmail;
      _password.text = mentor
          ? SupabaseConfig.mentorPassword
          : SupabaseConfig.learnerPassword;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (Supabase.instance.client.auth.currentSession == null) {
          setState(() {
            _error =
                'Account created. If email confirmation is on, confirm then sign in.';
            _isSignUp = false;
          });
          return;
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      widget.onSignedIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD9E6F2),
              AppColors.mist,
              Color(0xFFD5E8E2),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deskline',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Learner and mentor chat with live delivery. Open two clients to trade messages.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: Text(
                                _loading
                                    ? 'Working...'
                                    : (_isSignUp
                                        ? 'Create account'
                                        : 'Sign in'),
                              ),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () =>
                                      setState(() => _isSignUp = !_isSignUp),
                              child: Text(
                                _isSignUp
                                    ? 'Have an account? Sign in'
                                    : 'New here? Create an account',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed:
                                      _loading ? null : () => _fillDemo(false),
                                  child: const Text('Fill learner'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      _loading ? null : () => _fillDemo(true),
                                  child: const Text('Fill mentor'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
