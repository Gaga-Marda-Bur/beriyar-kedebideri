// QA-only overlay on exact RC1 application libraries. No linguistic fixture is created.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/monetization/offline_entitlements.dart';
import 'package:mobile/core/storage/app_directories.dart';
import 'package:mobile/features/offline_packs/models/lesson_pack_model.dart';
import 'package:mobile/features/offline_packs/services/offline_pack_download_service.dart';
import 'package:mobile/features/offline_packs/services/local_pack_reader_service.dart';
import 'package:mobile/features/progress/models/unit_progress_local_model.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual downloaded pack and pedagogical persistence',(tester) async {
    expect(const bool.fromEnvironment('BK_IDENTITY_QA'),isTrue);
    final docs=await getApplicationDocumentsDirectory();
    final phase=(await File('${docs.path}/qa_phase.txt').readAsString()).trim();
    // ignore: avoid_print
    print('BK_QA_SCENARIO:$phase');
    final storage=UnitProgressLocalStorage();
    final expected=File('${docs.path}/qa_learning_expected.json');
    const slug='premiers-5-caracteres';
    if(phase=='learning-seed') {
      final list=await ApiClient().getList('/offline-packs/');
      expect(list,isNotEmpty);
      final pack=LessonPackModel.fromJson(Map<String,dynamic>.from(list.first));
      await OfflinePackDownloadService().downloadAndExtract(pack);
      final progress=UnitProgressLocalModel.started(unitSlug:slug,totalSteps:3).copyWith(currentStep:1,bestScorePercent:60,lastStage:'quiz');
      await storage.saveProgress(progress);
      final saved=await storage.getProgress(slug);
      final zip=await AppDirectories.getDownloadedZipFile(slug:pack.slug,version:pack.version);
      await expected.writeAsString(jsonEncode({'progress':saved!.toJson(),'pack_slug':pack.slug,'pack_version':pack.version,'zip_sha256':sha256.convert(await zip.readAsBytes()).toString()}));
    }
    final reference=jsonDecode(await expected.readAsString()) as Map<String,dynamic>;
    expect((await storage.getProgress(slug))!.toJson(),reference['progress']);
    final pack=await LocalPackReaderService().readPack(slug:reference['pack_slug'],version:reference['pack_version']);
    final zip=await AppDirectories.getDownloadedZipFile(slug:reference['pack_slug'],version:reference['pack_version']);
    expect(sha256.convert(await zip.readAsBytes()).toString(),reference['zip_sha256']);
    final directory=await AppDirectories.getExtractedPackDirectory(slug:reference['pack_slug'],version:reference['pack_version']);
    final audios=directory.listSync(recursive:true).whereType<File>().where((f)=>RegExp(r'\.(mp3|wav|m4a)$').hasMatch(f.path)).toList();
    expect(audios,isNotEmpty);
    for(final audio in audios) {expect(await audio.length(),greaterThan(0));}
    await AndroidCommerceVault().resetSession();
    expect((await storage.getProgress(slug))!.toJson(),reference['progress']);
    expect(await zip.exists(),isTrue);
    await File('${docs.path}/qa_learning_result.json').writeAsString(jsonEncode({'phase':phase,'progress_preserved':true,'pack_integrity':true,'audio_files_present':audios.length,'zip_sha256':reference['zip_sha256'],'pack_read_succeeded':pack.slug.isNotEmpty,'commerce_key_erasure_preserves_learning':true,'audio_human_audibility':'not_checked'}));
  });
}
