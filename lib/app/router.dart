import 'package:go_router/go_router.dart';

import '../features/chat/chat_screen.dart';
import '../features/models/models_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ChatScreen(conversationId: null),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) =>
          ChatScreen(conversationId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/models',
      builder: (context, state) => const ModelsScreen(),
    ),
  ],
);
