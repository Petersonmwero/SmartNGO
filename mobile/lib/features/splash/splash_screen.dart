import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../../core/constants/app_theme_data.dart';
import '../../core/theme.dart';

/// Animated splash screen shown at app launch while auth state is resolving.
///
/// Shows the app logo with a fade-in animation, then navigates automatically
/// once [AuthProvider.status] is no longer [AuthStatus.unknown].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
    _waitThenNavigate();
  }

  Future<void> _waitThenNavigate() async {
    // Minimum splash duration so the animation can complete.
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();

    // Wait until bootstrap finishes if still loading.
    while (auth.status == AuthStatus.unknown) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (!mounted) return;
    if (auth.status == AuthStatus.authenticated) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppThemeData.headerGradient),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.eco_rounded,
                              size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Smart NGO',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontSize: 36,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'M&E Platform',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Amber loading strip anchored to the bottom of the screen.
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.accent,
              backgroundColor: Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
