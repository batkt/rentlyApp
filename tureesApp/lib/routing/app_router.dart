import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/agreement_model.dart';
import '../data/models/payment_model.dart';
import '../data/models/chat_model.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/org_select_screen.dart';
import '../presentation/screens/auth/reset_password_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/agreements/agreement_detail_screen.dart';
import '../presentation/screens/payment/payment_screen.dart';
import '../presentation/screens/payment/qpay_screen.dart';
import '../presentation/screens/chat/chat_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final isLoginPage = state.matchedLocation == '/login';
      final isOrgSelect = state.matchedLocation == '/org-select';
      final isResetPass = state.matchedLocation == '/reset-password';

      if (isLoading) return null;
      if (!isLoggedIn && !isLoginPage && !isOrgSelect && !isResetPass) return '/login';
      if (isLoggedIn && isLoginPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/org-select', builder: (_, __) => const OrgSelectScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/agreements/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final agreement = state.extra as AgreementModel?;
          return AgreementDetailScreen(agreementId: id, initialData: agreement);
        },
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final agreement = state.extra as AgreementModel?;
          return PaymentScreen(selectedAgreement: agreement);
        },
      ),
      GoRoute(
        path: '/qpay',
        builder: (context, state) {
          final invoice = state.extra as QpayInvoiceModel;
          return QpayScreen(invoice: invoice);
        },
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          if (id == 'loading') return const _ChatLoadingScreen();
          final conversation = state.extra as ConversationModel?;
          return ChatDetailScreen(conversationId: id, conversation: conversation);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Хуудас олдсонгүй: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Нүүр хуудас'),
            ),
          ],
        ),
      ),
    ),
  );
});

class _ChatLoadingScreen extends StatelessWidget {
  const _ChatLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
