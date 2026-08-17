import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/features/profile/models/user_place.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/profile_provider.dart';
import 'package:com_a4ding_livecalc/features/profile/repositories/profile_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/user_place_form_screen.dart';

class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class _FakeProfileRepository extends ProfileRepository {
  Map<String, dynamic>? lastBody;

  @override
  Future<List<UserPlace>> getPlaces() async => const [_place];

  @override
  Future<UserPlace> updatePlace(int id, Map<String, dynamic> body) async {
    lastBody = body;
    return _place;
  }
}

const _place = UserPlace(
  id: 3,
  name: '公司',
  latitude: 31.25,
  longitude: 121.5,
  kind: 'work',
  viewRadiusKm: 10,
);

void main() {
  testWidgets('user place maintenance is a full page and saves all fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeProfileRepository();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/edit'),
                child: const Text('打开编辑'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, __) => UserPlaceFormScreen(
            place: _place,
            mapTileProvider: _MemoryTileProvider(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        placeListProvider.overrideWith((ref) => PlaceListNotifier(repository)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('打开编辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(UserPlaceFormScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '编辑地点'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '名称（如：家、公司）'),
      '附近公司',
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(repository.lastBody, {
      'name': '附近公司',
      'kind': 'work',
      'address': null,
      'latitude': 31.25,
      'longitude': 121.5,
      'view_radius_km': 10,
    });
    expect(find.text('打开编辑'), findsOneWidget);
  });
}
