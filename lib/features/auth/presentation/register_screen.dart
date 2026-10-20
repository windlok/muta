import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final launched = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle();
      if (!launched) {
        setState(() => _error = l.googleStartFailed);
      }
    } catch (e) {
      if (mounted) setState(() => _error = l.googleRegisterFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final l = AppLocalizations.of(context);
    if (!isValidEmail(_email.text)) {
      setState(() => _error = l.invalidEmail);
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = l.passwordMin6);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .signUp(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      if (response.session == null) {
        // E-posta onayı açıksa oturum oluşmaz; kullanıcıya bilgi ver.
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.confirmationSent)));
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.accountCreated)));
        context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = l.registerFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.session != null && mounted) {
        context.go('/');
      } else if (next.hasError && mounted) {
        setState(() => _error = next.error.toString());
      }
    });
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.registerTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.emailLabel,
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: l.passwordMin6Hint,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(l.createAccount),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: Text(l.googleContinue),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l.haveAccountSignIn),
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
