import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/board/board_screen.dart';
import '../features/formations/formations_screen.dart';
import '../features/players/players_screen.dart';
import '../features/shared/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/board',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/board',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BoardScreen()),
          ),
          GoRoute(
            path: '/players',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PlayersScreen()),
          ),
          GoRoute(
            path: '/formations',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FormationsScreen()),
          ),
        ],
      ),
    ],
  );
});
