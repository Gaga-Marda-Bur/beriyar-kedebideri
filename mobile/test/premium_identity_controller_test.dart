import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/monetization/offline_entitlements.dart';
import 'package:mobile/core/monetization/premium_controller.dart';
import 'package:mobile/core/monetization/session_transport.dart';
import 'commerce_offline_test.dart' show FakeVault;

class Vault extends FakeVault {
  @override
  Future<String> signProof(String message) async=>'synthetic-proof';
}

void main() {
  late Vault vault;
  late Map<String,dynamic> fixture;
  late SimpleKeyPair key;
  late SimplePublicKey public;
  late MockClient httpClient;
  var failure=0;
  var revoked=false;
  var sequence=0;
  Completer<void>? held;
  var holdNextIdentity=false;
  final controllers=<PremiumController>[];
  const b='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  Future<http.Response> respond(http.Request request) async {
    expect(request.url.path,contains('/monetization/v1/'));
    expect(request.url.path, isNot(contains('/progress/')));
    final path=request.url.path;
    final owner=(request.headers['Cookie']??'').contains('sessionid=B')?b:fixture['claims']['subject'];
    Map<String,dynamic> result={};
    Map<String,String> headers={'content-type':'application/json'};
    if(path.endsWith('/session/login/')) {
      final name=jsonDecode(request.body)['username'];
      final account=name=='B'?'B':'A';
      result={'subject':account=='B'?b:fixture['claims']['subject'],'csrf_token':'csrf$account'};
      headers['set-cookie']='sessionid=$account; Path=/; HttpOnly, csrftoken=csrf$account; Path=/';
    } else if(path.endsWith('/session/csrf/')) {
      result={'csrf_token':'bootstrap'};
      headers['set-cookie']='csrftoken=bootstrap; Path=/';
    } else if(path.endsWith('/session/')) {
      if(holdNextIdentity) { holdNextIdentity=false; await held!.future; }
      if(failure!=0) return http.Response('{}',failure);
      result={'subject':owner,'csrf_token':'csrf'};
    } else if(path.endsWith('/session/logout/')) {
      result={'signed_out':true};
    } else if(path.endsWith('/challenge/')) {
      result={'id':'challenge','nonce':'fresh-${++sequence}','message':'BK-DEVICE/v1\nproof'};
    } else if(path.endsWith('/device-keys/')) {
      result={'subject':owner,'device_id':fixture['claims']['device_id'],'thumbprint':fixture['claims']['device_key_thumbprint']};
    } else if(path.endsWith('/offline-lease/')) {
      final claims=Map<String,dynamic>.from(fixture['claims']);
      final free=owner==b || revoked;
      claims.addAll({'subject':owner,'lease_id':'lease-$sequence','nonce':'fresh-$sequence',
        'entitlement_epoch':revoked?6:4,'features':free?[]:['simulation.badge'],
        'grant_ids':free?[]:fixture['claims']['grant_ids'],
        'expires_at':free?1900000000:1900604800,'offline_valid_until':free?1900000000:1900604800});
      final sorted={for(final k in claims.keys.toList()..sort()) k:claims[k]};
      final payload=base64Url.encode(utf8.encode(jsonEncode(sorted))).replaceAll('=','');
      final signature=await Ed25519().sign(utf8.encode('BK-OFFLINE-GRANT/v1\nsim-unit\n$payload'),keyPair:key);
      result={'version':1,'kid':'sim-unit','payload_b64url':payload,'signature_b64url':base64Url.encode(signature.bytes).replaceAll('=','')};
    } else if(path.endsWith('/catalog/')) {
      result={'offers':[]};
    } else if(path.endsWith('/requests/')) { result={'requests':[]}; }
    return http.Response(jsonEncode(result),200,headers:headers);
  }
  PremiumController make() {
    final rights=OfflineEntitlements(vault:vault,environment:'test',trustedKeys:{'sim-unit':public.bytes});
    final controller=PremiumController(vault:vault,rights:rights,
      transport:SessionTransport(base:Uri.parse('http://127.0.0.1/api'),client:httpClient),
      api:ApiClient(client:httpClient),eraseCommerce:()async{vault.files.clear();});
    controllers.add(controller);return controller;
  }
  setUp(()async {
    fixture=jsonDecode(File('test/fixtures/commerce_lease_test_vector.json').readAsStringSync());
    vault=Vault()..key=fixture['device_public_key_b64'];
    key=await Ed25519().newKeyPair();public=await key.extractPublicKey();
    failure=0;revoked=false;sequence=0;holdNextIdentity=false;
    httpClient=MockClient(respond);
    SharedPreferences.setMockInitialValues({'bk_qa_learning_preserved':'original'});
  });
  tearDown((){for(final c in controllers){c.dispose();}controllers.clear();});
  test('A paid -> logout -> guest offline -> B free -> restart B remains free',()async {
    final a=make();await a.initialize();await a.login('A','synthetic');
    expect(a.access.canUse('simulation.badge'),isTrue);
    await a.logout();
    final guest=make();await guest.initialize();expect(guest.subject,isNull);
    await guest.login('B','synthetic');expect(guest.subject,b);
    expect(guest.access.status,CommerceStatus.free);
    final restarted=make();await restarted.initialize();expect(restarted.subject,b);
    expect(restarted.access.canUse('simulation.badge'),isFalse);
    expect((await SharedPreferences.getInstance()).getString('bk_qa_learning_preserved'),'original');
  });
  test('A survives app restart offline but not reinstall or new installation key',()async {
    final a=make();await a.initialize();await a.login('A','synthetic');
    final restarted=make();await restarted.initialize();expect(restarted.access.canUse('simulation.badge'),isTrue);
    vault.key=base64.encode(List.filled(90,0));await restarted.checkLocal();
    expect(restarted.access.canUse('simulation.badge'),isFalse);
    vault.files.clear();final installed=make();await installed.initialize();expect(installed.subject,isNull);
  });
  test('server revoked, account disabled/deleted or session expired takes authority',()async {
    final a=make();await a.initialize();await a.login('A','synthetic');
    revoked=true;await a.refresh();expect(a.access.canUse('simulation.badge'),isFalse);
    failure=401;await a.refresh();expect(a.subject,isNull);
    expect(a.access.canUse('audio'),isTrue);
    final restarted=make();await restarted.initialize();expect(restarted.subject,isNull);
  });
  test('503 conserves proven rights without extending expiry',()async {
    final a=make();await a.initialize();await a.login('A','synthetic');
    final end=a.access.expiresAt;
    failure=503;await a.refresh();expect(a.access.canUse('simulation.badge'),isTrue);expect(a.access.expiresAt,end);
    vault.elapsed+=7*86400*1000;await a.checkLocal();expect(a.access.status,CommerceStatus.expired);
  });
  test('late A response cannot overwrite B after logout/switch',()async {
    final a=make();await a.initialize();await a.login('A','synthetic');
    held=Completer();holdNextIdentity=true;
    final pending=a.refresh();await Future<void>.delayed(const Duration(milliseconds:10));
    await a.logout();await a.login('B','synthetic');
    held!.complete();await pending;
    expect(a.subject,b);expect(a.access.canUse('simulation.badge'),isFalse);
    final restarted=make();await restarted.initialize();expect(restarted.subject,b);
  });
  test('session transport refuses redirects, foreign paths, unsafe HTTP',()async {
    expect(()=>SessionTransport(base:Uri.parse('http://public.example/api')),throwsArgumentError);
    final transport=SessionTransport(base:Uri.parse('http://127.0.0.1/api'),client:MockClient((r)async=>http.Response('',302,headers:{'location':'https://other.example'})));
    await expectLater(transport.request('/progress/'),throwsArgumentError);
    await expectLater(transport.request('/monetization/v1/session/'),throwsA(isA<ApiRequestException>()));
  });
}
