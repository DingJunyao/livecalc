import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/widgets/app_back_button.dart';

void main() {
  testWidgets(
      'Arabic AppBackButton localizes and mirrors without reversing pop',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/pushed',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/pushed',
          builder: (_, __) => Scaffold(
            appBar: AppBar(leading: const AppBackButton()),
            body: const Text('pushed'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    expect(find.text('pushed'), findsOneWidget);
    expect(find.byTooltip('رجوع'), findsOneWidget);
    expect(find.byTooltip('返回'), findsNothing);

    final mirror = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AppBackButton),
        matching: find.byType(Transform),
      ),
    );
    expect(mirror.transform.storage[0], lessThan(0));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('pushed'), findsNothing);
  });
}
