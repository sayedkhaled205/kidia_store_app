import '../../../support/viewport_rotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/splash/domain/splash_config.dart';
import 'package:mobishop_store_app/features/splash/presentation/splash_screen.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

void main() {
  viewportRotationTests('Splash', (tester,size) => tester.pumpWidget(const MaterialApp(home:SplashScreen(config:SplashConfig(showLoader:false)))));
  test('unset branding starts neutral while saved colors remain exact', () {
    final fallback = SplashConfig.fromJson({});
    expect(fallback.backgroundColor, Colors.white);
    expect(fallback.backgroundColorEnd, Colors.white);
    expect(fallback.textColor, const Color(0xFF253A46));
    final saved = SplashConfig.fromJson({
      'background_color': '#123456',
      'background_color_end': '#654321',
      'text_color': '#F0EEDD',
      'loader_color': '#CC2211',
      'image_fit': 'cover',
    });
    expect(saved.backgroundColor, const Color(0xFF123456));
    expect(saved.backgroundColorEnd, const Color(0xFF654321));
    expect(saved.textColor, const Color(0xFFF0EEDD));
    expect(saved.loaderColor, const Color(0xFFCC2211));
    expect(saved.imageFit, BoxFit.cover);
  });

  testWidgets('logo only is centered without hidden title or loader gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          config: SplashConfig(
            imageUrl: 'https://store.example/logo.png',
            imageWidth: 176,
            imageHeight: 72,
            showStoreName: false,
            showLoader: false,
          ),
        ),
      ),
    );
    final image = tester.widget<AppNetworkImage>(find.byType(AppNetworkImage));
    expect(image.fit, BoxFit.contain);
    expect(image.width, 176);
    expect(image.height, 72);
    expect(find.byType(AppNetworkImageLoading), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('splash-brand-composition'))),
      const Size(176, 72),
    );
    expect(
      tester.getCenter(find.byKey(const Key('splash-brand-composition'))),
      tester.getCenter(find.byType(Scaffold)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compact loader stays separate from proportional logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          config: SplashConfig(
            imageUrl: 'https://store.example/logo.png',
            imageWidth: 176,
            imageHeight: 72,
            showStoreName: false,
            loaderColor: Color(0xFF4EA999),
          ),
        ),
      ),
    );
    final loader = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(loader.strokeWidth, 2);
    expect(loader.color, const Color(0xFF4EA999));
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size(22, 22),
    );
    expect(
      tester.getRect(find.byType(CircularProgressIndicator)).top -
          tester.getRect(find.byType(AppNetworkImage)).bottom,
      24,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'small preview scales composition without stretching or overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(240, 180));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            config: SplashConfig(
              imageUrl: 'https://store.example/logo.png',
              imageWidth: 320,
              imageHeight: 140,
              showStoreName: false,
            ),
          ),
        ),
      );
      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, BoxFit.scaleDown);
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byType(FittedBox));
      expect(box.left, greaterThanOrEqualTo(24));
      expect(box.right, lessThanOrEqualTo(216));
      expect(box.top, greaterThanOrEqualTo(24));
      expect(box.bottom, lessThanOrEqualTo(156));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

