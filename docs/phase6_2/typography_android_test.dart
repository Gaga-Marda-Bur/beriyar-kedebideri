import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/widgets/bk_learning_node.dart';
import 'package:mobile/core/widgets/bk_option_card.dart';
import 'package:mobile/features/editor/models/beriya_draft.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment('QA_STAGE', defaultValue:'before');
  testWidgets('native typography fixture, production themes and widgets', (tester) async {
    final root = await getApplicationDocumentsDirectory();
    final glyphs = String.fromCharCodes([
      ...List.generate(25, (i)=>0x16ea0+i), ...List.generate(25,(i)=>0x16ebb+i)]);
    for (final dark in [false,true]) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(theme:dark?AppTheme.darkTheme():AppTheme.lightTheme(),
        home:RepaintBoundary(key:key, child:Scaffold(body:SafeArea(child:ListView(
          padding:const EdgeInsets.all(16), children:[
          const Text('QA typographique — composants réels',style:TextStyle(fontSize:16)),
          const BkLearningNode(title:'Unité 2 : La consonne Te (𖺵) et le mot "ta"'),
          const BkLearningNode(title:'Unité 3 : La consonne De (𖺢) et le mot "de"'),
          const Text('Beřiya — العربية — 𖺵̄ 𖺢',style:AppTextStyles.latinHeading),
          const BkOptionCard(label:'Beřiya 𖺵',erfeText:'𖺵̄',state:BkOptionCardState.correct),
          Text(glyphs, style:const TextStyle(fontSize:26)),
          const Text('𖺠̄ 𖺣̄ 𖺧̄ 𖺯̄ 𖺶̄', style:TextStyle(fontSize:28)),
          const Directionality(textDirection:TextDirection.rtl,
            child:Text('العربية (𖺵̄) Beřiya',style:TextStyle(fontSize:22))),
        ]))))));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds:500));
      await tester.pump();
      expect(tester.takeException(),isNull);
      final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image=await boundary.toImage(pixelRatio:1.5);
      final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
      await File('${root.path}/phase62_${stage}_${dark?'dark':'light'}.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }
    final pdf=await BeriyaPdfService.generatePdfBytes(BeriyaDraft(
      id:'qa-only', title:'Beřiya 𖺵',content:'𖺠̄ 𖺣̄ 𖺧̄ 𖺯̄ 𖺶̄\n$glyphs',updatedAt:DateTime(2026,11,10)));
    expect(pdf.length,greaterThan(1000));
    await File('${root.path}/phase62_$stage.pdf').writeAsBytes(pdf);
  });
}
