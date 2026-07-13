import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../core/services/supabase_bootstrap.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class FieldPilotApp extends ConsumerStatefulWidget {
  const FieldPilotApp({super.key});

  @override
  ConsumerState<FieldPilotApp> createState() => _FieldPilotAppState();
}

class _FieldPilotAppState extends ConsumerState<FieldPilotApp>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _locked = false;
  bool _unlocking = false;
  String? _lockError;

  bool get _signedIn =>
      SupabaseBootstrap.configured &&
      SupabaseBootstrap.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_signedIn) {
        setState(() => _locked = true);
        _unlock();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_signedIn && !_unlocking) {
        setState(() {
          _locked = true;
          _lockError = null;
        });
      }
      return;
    }

    if (state == AppLifecycleState.resumed && _signedIn && _locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_unlocking || !_signedIn) return;
    setState(() {
      _unlocking = true;
      _lockError = null;
    });

    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) {
        setState(() {
          _lockError = 'No biometric unlock is available on this device.';
        });
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock FieldPilot with face or fingerprint',
        biometricOnly: true,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _locked = false;
          _lockError = null;
        });
      } else {
        setState(() => _lockError = 'Fingerprint unlock was cancelled.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _lockError = 'Fingerprint unlock failed: $error');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    if (SupabaseBootstrap.configured) {
      await SupabaseBootstrap.client.auth.signOut();
    }
    if (!mounted) return;
    setState(() {
      _locked = false;
      _lockError = null;
    });
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FieldPilot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (_signedIn && _locked)
              _AppLockScreen(
                unlocking: _unlocking,
                error: _lockError,
                onUnlock: _unlock,
                onSignOut: () => _signOut(context),
              ),
          ],
        );
      },
    );
  }
}

class _AppLockScreen extends StatelessWidget {
  const _AppLockScreen({
    required this.unlocking,
    required this.onUnlock,
    required this.onSignOut,
    this.error,
  });

  final bool unlocking;
  final String? error;
  final VoidCallback onUnlock;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'FieldPilot locked',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock with face recognition or fingerprint to continue.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: unlocking ? null : onUnlock,
                    icon: unlocking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    label: Text(unlocking ? 'Unlocking...' : 'Unlock'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: unlocking ? null : onSignOut,
                    child: const Text('Sign out'),
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
