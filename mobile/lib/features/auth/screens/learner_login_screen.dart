import 'package:flutter/material.dart';

import '../../../core/auth/learner_auth_service.dart';
import '../../../core/cache/memory_content_cache.dart';
import '../../../core/cache/online_content_cache_service.dart';
import '../../../core/startup/app_preload_service.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';

class LearnerLoginScreen extends StatefulWidget {
  final LearnerAuthService? authService;
  final bool refreshContentOnLogin;

  const LearnerLoginScreen({
    super.key,
    this.authService,
    this.refreshContentOnLogin = true,
  });

  @override
  State<LearnerLoginScreen> createState() => _LearnerLoginScreenState();
}

class _LearnerLoginScreenState extends State<LearnerLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final LearnerAuthService _authService;

  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? LearnerAuthService.instance;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Identifiant et mot de passe requis.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _authService.login(username, password);
      _passwordController.clear();

      if (widget.refreshContentOnLogin) {
        MemoryContentCache.instance.clear();
        await OnlineContentCacheService().clearAll();
        // Fire-and-forget preload so UI returns immediately.
        // ignore: unawaited_futures
        AppPreloadService.instance.resetAndPreloadAgain();
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on LearnerAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Connexion impossible.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion apprenant')),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Accès au parcours',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connectez-vous avec votre compte apprenant pour synchroniser vos leçons et votre progression.',
                    ),
                    if (_authService.isExpired) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Votre session a expiré. Veuillez vous reconnecter.',
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('learner-login-error'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('learner-username'),
                      controller: _usernameController,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Identifiant',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('learner-password'),
                      controller: _passwordController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _submitting ? null : _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('learner-login-submit'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Se connecter'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
