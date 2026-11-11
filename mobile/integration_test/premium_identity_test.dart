import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/monetization/premium_controller.dart';
import 'package:mobile/core/monetization/offline_entitlements.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/premium/screens/premium_screen.dart';
import 'package:mobile/core/widgets/bk_option_card.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const selectedPhase = String.fromEnvironment('BK_QA_PHASE', defaultValue: 'initial');
  testWidgets('physical isolated premium identity', (tester) async {
    final documents=await getApplicationDocumentsDirectory();
    final phaseFile=File('${documents.path}/qa_phase.txt');
    final phase=selectedPhase=='dynamic' ? (await phaseFile.readAsString()).trim() : selectedPhase;
    // This marker contains only the scenario name, never credentials or cookies.
    debugPrint('BK_QA_SCENARIO:$phase');
    expect(const bool.fromEnvironment('BK_IDENTITY_QA'), isTrue);
    final controller = PremiumController.create();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'bk_qa_learning_preserved',
      'synthetic-learning-sentinel',
    );
    await controller.initialize();
    var converted=false;
    Future<void> screen({bool dark = true}) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('qa-capture'),
          child: MaterialApp(
            locale: const Locale('fr'),
            supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
            home: PremiumScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if(!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted=true;
        await tester.pumpAndSettle();
      }
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('qa-capture')),
      );
      final image = await render.toImage(pixelRatio: 1.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getApplicationDocumentsDirectory();
      await File(
        '${dir.path}/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    }

    if (phase == 'initial') {
      await screen();
      await capture('premium_guest_dark');
      // Login through the real visible fields, not an injected identity.
      await tester.ensureVisible(find.byKey(const Key('premium-username')));
      await tester.enterText(
        find.byKey(const Key('premium-username')),
        'qa64c-a',
      );
      await tester.enterText(
        find.byKey(const Key('premium-password')),
        'synthetic-session-password',
      );
      await tester.tap(find.byKey(const Key('premium-login')));
      await tester.runAsync(() async {
        while (controller.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pumpAndSettle();
      expect(controller.subject, isNotNull, reason: controller.sync);
      expect(
        controller.access.canUse('simulation.badge'),
        isTrue,
        reason: controller.sync,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      await capture('premium_a_dark');
      await screen(dark: false);
      await capture('premium_a_light');
    } else if (phase == 'switch') {
      await controller.login('qa64c-a', 'synthetic-session-password');
      expect(controller.access.canUse('simulation.badge'), isTrue);
      await controller.logout();
      expect(controller.access.canUse('simulation.badge'), isFalse);
      await controller.login('qa64c-b', 'synthetic-session-password');
      expect(controller.subject, isNotNull);
      expect(controller.access.canUse('simulation.badge'), isFalse);
      await screen();
      await capture('premium_b_free');
    } else if (phase == 'offline' || phase == 'restart') {
      await controller.checkLocal();
      expect(controller.subject, isNotNull);
      expect(controller.access.canUse('simulation.badge'), isTrue);
      await screen();
      await capture('premium_offline');
    } else if (phase == 'b-restart') {
      expect(controller.subject, isNotNull);
      expect(controller.access.canUse('simulation.badge'), isFalse);
    } else if (phase == 'guest-offline') {
      await controller.logout();
      expect(controller.subject, isNull);
      final second = PremiumController.create();
      await second.initialize();
      expect(second.subject, isNull);
      expect(second.access.canUse('simulation.badge'), isFalse);
      second.dispose();
    } else if (phase == 'reboot') {
      expect(controller.access.status, CommerceStatus.verificationRequired);
      expect(controller.access.canUse('audio'), isTrue);
    } else if (phase == 'revalidate') {
      await controller.refresh();
      expect(controller.access.canUse('simulation.badge'), isFalse);
      await screen();
      await capture('premium_server_refused');
    } else if (phase == 'login-a') {
      await controller.login('qa64c-a', 'synthetic-session-password');
      expect(
        controller.access.canUse('simulation.badge'),
        isTrue,
        reason: controller.sync,
      );
    } else if(phase=='erfe') {
      for(final dark in [true,false]) {
        await tester.pumpWidget(RepaintBoundary(key:const Key('qa-capture'),child:MaterialApp(
          theme:dark?AppTheme.darkTheme():AppTheme.lightTheme(),home:Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
            const Text('Erfe · contrôle typographique',style:TextStyle(fontSize:24)),
            Text(String.fromCharCodes([...List.generate(25,(i)=>0x16ea0+i),...List.generate(25,(i)=>0x16ebb+i)]),style:const TextStyle(fontSize:28)),
            const BkOptionCard(label:'Beřiya العربية 𖺢',erfeText:'𖺠̄'),
            const Text('𖺠̄ 𖺣̄ 𖺧̄ 𖺯̄ 𖺶̄',style:TextStyle(fontSize:28)),
          ]))))));
        await tester.pumpAndSettle();
        if(!converted) {await binding.convertFlutterSurfaceToImage();converted=true;await tester.pumpAndSettle();}
        await capture(dark?'erfe_dark':'erfe_light');
      }
    }
    expect(controller.access.canUse('alphabet'), isTrue);
    expect(controller.access.canUse('srs'), isTrue);
    expect(
      preferences.getString('bk_qa_learning_preserved'),
      'synthetic-learning-sentinel',
    );
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
