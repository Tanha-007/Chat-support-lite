import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/errors.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/tag.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _signUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _busyDemo;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  GoTrueClient get _auth => Supabase.instance.client.auth;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signUp) {
        final res = await _auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'display_name': _name.text.trim()},
        );
        if (res.session == null && mounted) {
          setState(() {
            _signUp = false;
            _error =
                'Account created. Check your inbox to confirm, then sign in.';
          });
        }
      } else {
        await _auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _demo(DemoAccount account) async {
    setState(() {
      _busyDemo = account.email;
      _error = null;
    });
    try {
      await _auth.signInWithPassword(
        email: account.email,
        password: SupabaseConfig.demoPassword,
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busyDemo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _buildForm();
    final demos = _buildDemos();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 980 : 440),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildIntro(large: true)),
                        const SizedBox(width: 56),
                        SizedBox(
                          width: 420,
                          child: Column(
                            children: [form, const SizedBox(height: 28), demos],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIntro(large: false),
                        const SizedBox(height: 28),
                        form,
                        const SizedBox(height: 28),
                        demos,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro({required bool large}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.signal,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text('Deskline', style: AppType.heading(18)),
          ],
        ),
        SizedBox(height: large ? 56 : 28),
        Text(
          'Stuck on something?\nAsk a mentor.',
          style: AppType.display(large ? 58 : 40),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Learners open a conversation with a mentor and get answers in real time. '
            'History stays put, and only the two of you can read it.',
            style: AppType.body(16, color: AppColors.muted),
          ),
        ),
        if (large) ...[const SizedBox(height: 40), const _Facts()],
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _signUp ? 'Create a learner account' : 'Sign in',
                style: AppType.heading(22),
              ),
              const SizedBox(height: 4),
              Text(
                _signUp
                    ? 'Mentors join by invitation. Everyone else starts here.'
                    : 'Welcome back.',
                style: AppType.body(14, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              if (_signUp) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length < SupabaseConfig.minNameLength) {
                      return 'Enter at least ${SupabaseConfig.minNameLength} characters.';
                    }
                    if (t.length > SupabaseConfig.maxNameLength) {
                      return 'Keep it under ${SupabaseConfig.maxNameLength} characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return 'Enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: [
                  _signUp ? AutofillHints.newPassword : AutofillHints.password,
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _signUp
                      ? 'At least ${SupabaseConfig.minPasswordLength} characters'
                      : null,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (v) {
                  final t = v ?? '';
                  if (t.isEmpty) return 'Enter your password.';
                  if (_signUp && t.length < SupabaseConfig.minPasswordLength) {
                    return 'Use at least ${SupabaseConfig.minPasswordLength} characters.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: AppType.body(13, color: AppColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.card,
                        ),
                      )
                    : Text(_signUp ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _signUp = !_signUp;
                        _error = null;
                      }),
                child: Text(
                  _signUp
                      ? 'Already have an account? Sign in'
                      : 'New learner? Create an account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DEMO ACCOUNTS  ·  ONE TAP SIGN IN',
          style: AppType.mono(11, spacing: 1.2, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < SupabaseConfig.demoAccounts.length; i++) ...[
                if (i > 0) const Divider(),
                _DemoRow(
                  account: SupabaseConfig.demoAccounts[i],
                  busy: _busyDemo == SupabaseConfig.demoAccounts[i].email,
                  enabled: _busyDemo == null && !_busy,
                  onTap: () => _demo(SupabaseConfig.demoAccounts[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Password for all demo accounts: ${SupabaseConfig.demoPassword}',
          style: AppType.mono(11),
        ),
      ],
    );
  }
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({
    required this.account,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final DemoAccount account;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Avatar(name: account.name, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: AppType.body(15, weight: FontWeight.w600),
                  ),
                  Text(account.email, style: AppType.mono(11)),
                ],
              ),
            ),
            Tag.role(account.role),
            const SizedBox(width: 10),
            SizedBox(
              width: 18,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts();

  @override
  Widget build(BuildContext context) {
    final facts = [
      ('Live', 'Messages and typing appear on the other screen instantly.'),
      (
        'Private',
        'Row level security keeps each conversation between its two members.',
      ),
      (
        'Looked after',
        'Anyone can report a message. Moderators review every one.',
      ),
    ];
    return Column(
      children: [
        for (final f in facts)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    f.$1.toUpperCase(),
                    style: AppType.mono(
                      11,
                      color: AppColors.ink,
                      spacing: 1.2,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    f.$2,
                    style: AppType.body(14, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
