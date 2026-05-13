import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/engineer/engineer_dashboard.dart';
import 'screens/engineer/barcode_scanner_screen.dart';
import 'screens/engineer/otp_verify_screen.dart';
import 'screens/engineer/upload_proof_screen.dart';
import 'screens/customer/customer_dashboard.dart';
import 'screens/customer/request_service_screen.dart';

// ---------------------------------------------------------------------------
// Auth state notifier — GoRouter listens to this for redirect refreshes
// ---------------------------------------------------------------------------
final _authStateNotifier = ValueNotifier<bool>(false);

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final authProvider = AuthProvider();
          ApiService.onUnauthenticated = () => authProvider.logout();

          // Keep the notifier in sync with auth changes so GoRouter refreshes
          authProvider.addListener(() {
            _authStateNotifier.value = authProvider.isAuthenticated;
          });
          return authProvider;
        }),
      ],
      child: const MyApp(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Router is created ONCE — never rebuilt when auth changes
// ---------------------------------------------------------------------------
final GoRouter _router = GoRouter(
  initialLocation: '/',
  refreshListenable: _authStateNotifier,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/engineer',
      builder: (context, state) => const EngineerDashboard(),
      routes: [
        GoRoute(
          path: 'scan/:ticketId',
          builder: (context, state) => BarcodeScannerScreen(
            ticketId: state.pathParameters['ticketId']!,
          ),
        ),
        GoRoute(
          path: 'otp/:ticketId',
          builder: (context, state) => OtpVerifyScreen(
            ticketId: state.pathParameters['ticketId']!,
            maskedEmail: state.extra as String?,
          ),
        ),
        GoRoute(
          path: 'proof/:ticketId',
          builder: (context, state) => UploadProofScreen(
            ticketId: state.pathParameters['ticketId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const CustomerDashboard(),
      routes: [
        GoRoute(
          path: 'request',
          builder: (context, state) => const RequestServiceScreen(),
        ),
      ],
    ),
  ],
  // Redirect only protects routes — SplashScreen handles its own navigation
  redirect: (context, state) {
    final currentPath = state.matchedLocation;

    // Splash handles its own routing; never redirect away from it here
    if (currentPath == '/') return null;

    final isAuthenticated = _authStateNotifier.value;
    final loggingIn = currentPath == '/login';

    if (!isAuthenticated && !loggingIn) return '/login';
    if (isAuthenticated && loggingIn) return null; // login screen handles redirect
    return null;
  },
);

// ---------------------------------------------------------------------------
// MyApp is a pure StatelessWidget — router is never re-created
// ---------------------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Innoven Support',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: _router,
    );
  }
}
