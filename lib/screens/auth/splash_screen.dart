import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      final role = authProvider.user!['role'];
      if (role == 'engineer') {
        context.go('/engineer');
      } else {
        context.go('/customer');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: isLandscape
              ? _buildLandscape()
              : _buildPortrait(),
        ),
      ),
    );
  }

  // ── Portrait ─────────────────────────────────────────────────────────────
  Widget _buildPortrait() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        _buildLogo(size: 110),
        const SizedBox(height: 28),
        _buildTitle(),
        const Spacer(flex: 3),
        _buildProgressBar(),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Landscape ────────────────────────────────────────────────────────────
  Widget _buildLandscape() {
    return Row(
      children: [
        // Left: Logo
        Expanded(
          child: Center(child: _buildLogo(size: 90)),
        ),
        // Right: Title + progress
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(crossAxisAlignment: CrossAxisAlignment.start),
              const SizedBox(height: 40),
              _buildProgressBar(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared components ─────────────────────────────────────────────────────
  Widget _buildLogo({required double size}) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withOpacity(0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 4,
              )
            ],
          ),
          child: Icon(
            Icons.support_agent_rounded,
            size: size * 0.54,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle({
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'INNOVEN SUPPORT',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Service Lifecycle Management',
              style: TextStyle(
                  fontSize: 13, color: Colors.white70, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressAnim.value,
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Loading...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
