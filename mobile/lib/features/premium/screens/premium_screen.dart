import 'package:flutter/material.dart';
import '../../../core/monetization/premium_controller.dart';
import '../../../core/monetization/offline_entitlements.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class PremiumScreen extends StatefulWidget {
  final PremiumController? controller;
  const PremiumScreen({super.key, this.controller});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with WidgetsBindingObserver {
  late final PremiumController controller;
  final username = TextEditingController();
  final password = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = widget.controller ?? PremiumController.create();
    controller.addListener(_changed);
    controller.initialize().then((_) => controller.refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.checkLocal();
      controller.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    if (widget.controller == null) controller.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  String copy(String fr, String en, String ar) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ar' => ar,
        'en' => en,
        _ => fr,
      };
  @override
  Widget build(BuildContext context) {
    final logged = controller.subject != null;
    final status = switch (controller.access.status) {
      CommerceStatus.active => copy(
        'Droit simulé actif',
        'Simulated access active',
        'وصول تجريبي نشط',
      ),
      CommerceStatus.expired => copy(
        'Droit expiré',
        'Access expired',
        'انتهت الصلاحية',
      ),
      CommerceStatus.verificationRequired => copy(
        'Vérification nécessaire',
        'Verification required',
        'يلزم التحقق',
      ),
      CommerceStatus.free => copy('Accès gratuit', 'Free access', 'وصول مجاني'),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          copy(
            'Premium · Simulation',
            'Premium · Simulation',
            'بريميوم · محاكاة',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 52,
              color: AppColors.gold,
            ),
            const SizedBox(height: 16),
            Text(
              copy(
                'Soutenir BK, préserver l’apprentissage',
                'Support BK, preserve learning',
                'دعم BK مع الحفاظ على التعلم',
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              copy(
                'Démonstration uniquement. Achats indisponibles. Aucune publicité ni paiement réel.',
                'Demo only. Purchases unavailable. No ads or real payments.',
                'عرض تجريبي فقط. الشراء غير متاح. لا إعلانات ولا مدفوعات حقيقية.',
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    key: const Key('premium-status'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    logged
                        ? copy(
                            'Compte connecté · droits isolés',
                            'Signed in · isolated access',
                            'حساب متصل · وصول منفصل',
                          )
                        : copy('Mode invité', 'Guest mode', 'وضع الضيف'),
                    key: const Key('premium-identity'),
                  ),
                  Text(
                    copy('Synchronisation : ', 'Sync: ', 'المزامنة: ') +
                        _syncLabel(),
                  ),
                  if (controller.access.expiresAt != null)
                    Text(
                      copy('Expiration : ', 'Expires: ', 'الانتهاء: ') +
                          MaterialLocalizations.of(context).formatMediumDate(
                            controller.access.expiresAt!.toLocal(),
                          ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    copy(
                      'Hors ligne : 7 jours maximum, sans dépasser le droit. Après redémarrage du téléphone, vérification réseau pour les seuls extras.',
                      'Offline: up to 7 days, capped by access expiry. After a phone reboot, extra features need online verification.',
                      'دون اتصال: حتى 7 أيام ضمن مدة الصلاحية. بعد إعادة تشغيل الهاتف يلزم اتصال للتحقق من المزايا الإضافية فقط.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              copy('Toujours gratuit', 'Always free', 'مجاني دائماً'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              copy(
                'Alphabet, dictionnaire, clavier Erfe, audio, quiz, SRS, packs et progressions existants.',
                'Alphabet, dictionary, Erfe keyboard, audio, quizzes, SRS, existing packs and progress.',
                'الأبجدية والقاموس ولوحة Erfe والصوت والاختبارات والمراجعة والحزم والتقدم الحالي.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              copy(
                'Avantage de test : badge simulé. Aucun nouveau contenu linguistique payant.',
                'Test benefit: simulated badge. No new paid language content.',
                'ميزة اختبار: شارة تجريبية. لا محتوى لغوي مدفوع جديد.',
              ),
            ),
            if (!controller.enabled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  copy(
                    'Recette non configurée : aucun identifiant ne sera envoyé.',
                    'Test environment not configured: no credentials will be sent.',
                    'بيئة الاختبار غير مهيأة: لن يتم إرسال بيانات الدخول.',
                  ),
                ),
              ),
            if (!logged && controller.enabled) ...[
              const SizedBox(height: 20),
              TextField(
                key: const Key('premium-username'),
                controller: username,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: copy(
                    'Identifiant de test',
                    'Test username',
                    'اسم مستخدم الاختبار',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('premium-password'),
                controller: password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: copy('Mot de passe', 'Password', 'كلمة المرور'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('premium-login'),
                onPressed: controller.busy
                    ? null
                    : () async {
                        final value = password.text;
                        password.clear();
                        await controller.login(username.text.trim(), value);
                      },
                child: Text(copy('Se connecter', 'Sign in', 'تسجيل الدخول')),
              ),
            ],
            if (logged) ...[
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('premium-refresh'),
                onPressed: controller.busy ? null : controller.refresh,
                child: Text(
                  copy(
                    'Vérifier les droits',
                    'Verify access',
                    'التحقق من الوصول',
                  ),
                ),
              ),
              OutlinedButton(
                key: const Key('premium-logout'),
                onPressed: controller.logout,
                child: Text(
                  copy(
                    'Déconnexion / changer de compte',
                    'Sign out / change account',
                    'تسجيل الخروج / تغيير الحساب',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                copy('Offres de démonstration', 'Demo offers', 'عروض تجريبية'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final offer in controller.offers)
                ListTile(
                  title: Text(offer['label'].toString()),
                  subtitle: Text(
                    copy(
                      'Simulation · aucun achat possible',
                      'Simulation · no purchase available',
                      'محاكاة · لا يمكن الشراء',
                    ),
                  ),
                ),
              OutlinedButton(
                key: const Key('premium-demo-request'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      copy(
                        'Demande de démonstration',
                        'Demo activation request',
                        'طلب تفعيل تجريبي',
                      ),
                    ),
                    content: Text(
                      copy(
                        'Aucune demande envoyée. Une activation fictive est préparée par un administrateur de recette puis vérifiée par un autre rôle. Aucun paiement.',
                        'Nothing sent. A test administrator prepares a fictitious activation for independent review. No payment.',
                        'لم يتم إرسال طلب. يعد مسؤول الاختبار تفعيلاً وهمياً لمراجعة مستقلة. لا دفع.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(copy('Fermer', 'Close', 'إغلاق')),
                      ),
                    ],
                  ),
                ),
                child: Text(
                  copy(
                    'Comprendre la demande d’activation',
                    'Preview an activation request',
                    'معاينة طلب التفعيل',
                  ),
                ),
              ),
              Text(
                copy(
                  'Historique de simulation',
                  'Simulation history',
                  'سجل المحاكاة',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (controller.history.isEmpty)
                Text(
                  copy(
                    'Aucune opération de simulation disponible.',
                    'No simulated operations available.',
                    'لا عمليات تجريبية متاحة.',
                  ),
                ),
              for (final entry in controller.history)
                ListTile(
                  title: Text(entry['purpose'].toString()),
                  subtitle: Text(entry['status'].toString()),
                ),
            ],
            if (controller.busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  String _syncLabel() => switch (controller.sync) {
    'verified' => copy('vérifiée', 'verified', 'تم التحقق'),
    'offline' => copy(
      'hors ligne · à revérifier',
      'offline · recheck needed',
      'دون اتصال · يلزم إعادة التحقق',
    ),
    'connecting' => copy('connexion…', 'connecting…', 'جارٍ الاتصال…'),
    'login_failed' => copy(
      'connexion refusée ou indisponible',
      'sign-in refused or unavailable',
      'الدخول مرفوض أو غير متاح',
    ),
    'authentication_required' => copy(
      'reconnexion nécessaire',
      'sign in again',
      'يلزم تسجيل الدخول مجدداً',
    ),
    _ => copy('non vérifiée', 'not verified', 'غير متحقق'),
  };
}
