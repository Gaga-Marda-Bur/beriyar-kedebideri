import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'Beřiyar Kedebideři'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In fr, this message translates to:
  /// **'Écouter. Lire. Écrire. Transmettre.'**
  String get appTagline;

  /// No description provided for @home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get home;

  /// No description provided for @learn.
  ///
  /// In fr, this message translates to:
  /// **'Apprendre'**
  String get learn;

  /// No description provided for @alphabet.
  ///
  /// In fr, this message translates to:
  /// **'Alphabet'**
  String get alphabet;

  /// No description provided for @vocabulary.
  ///
  /// In fr, this message translates to:
  /// **'Vocabulaire'**
  String get vocabulary;

  /// No description provided for @noEna.
  ///
  /// In fr, this message translates to:
  /// **'No Ena'**
  String get noEna;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @startLearning.
  ///
  /// In fr, this message translates to:
  /// **'Commencer à apprendre'**
  String get startLearning;

  /// No description provided for @backendStatus.
  ///
  /// In fr, this message translates to:
  /// **'État du backend'**
  String get backendStatus;

  /// No description provided for @connected.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In fr, this message translates to:
  /// **'Non connecté'**
  String get notConnected;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In fr, this message translates to:
  /// **'Arabe'**
  String get arabic;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'La voix Beriya rencontre son écriture.'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Apprends Beriya Erfe avec l’écoute, les caractères, les mots, les leçons et les quiz.'**
  String get welcomeSubtitle;

  /// No description provided for @openSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les paramètres'**
  String get openSettings;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;

  /// No description provided for @errorLoading.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get errorLoading;

  /// No description provided for @listen.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get listen;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get search;

  /// No description provided for @searchVocabulary.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un mot, une transcription ou une traduction...'**
  String get searchVocabulary;

  /// No description provided for @noCharacters.
  ///
  /// In fr, this message translates to:
  /// **'Aucun caractère trouvé.'**
  String get noCharacters;

  /// No description provided for @noWords.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mot trouvé.'**
  String get noWords;

  /// No description provided for @transcriptionMissing.
  ///
  /// In fr, this message translates to:
  /// **'Transcription à compléter'**
  String get transcriptionMissing;

  /// No description provided for @translationMissing.
  ///
  /// In fr, this message translates to:
  /// **'Traduction à compléter'**
  String get translationMissing;

  /// No description provided for @learningPath.
  ///
  /// In fr, this message translates to:
  /// **'Parcours d’apprentissage'**
  String get learningPath;

  /// No description provided for @learningPathSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Apprends par thèmes et unités courtes.'**
  String get learningPathSubtitle;

  /// No description provided for @openUnit.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir l’unité'**
  String get openUnit;

  /// No description provided for @startUnit.
  ///
  /// In fr, this message translates to:
  /// **'Commencer l’unité'**
  String get startUnit;

  /// No description provided for @characters.
  ///
  /// In fr, this message translates to:
  /// **'Caractères'**
  String get characters;

  /// No description provided for @words.
  ///
  /// In fr, this message translates to:
  /// **'Mots'**
  String get words;

  /// No description provided for @lessons.
  ///
  /// In fr, this message translates to:
  /// **'Leçons'**
  String get lessons;

  /// No description provided for @quizzes.
  ///
  /// In fr, this message translates to:
  /// **'Quiz'**
  String get quizzes;

  /// No description provided for @minutes.
  ///
  /// In fr, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @minimumScore.
  ///
  /// In fr, this message translates to:
  /// **'Score minimum'**
  String get minimumScore;

  /// No description provided for @unitContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu de l’unité'**
  String get unitContent;

  /// No description provided for @noThemes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun thème disponible.'**
  String get noThemes;

  /// No description provided for @noLessons.
  ///
  /// In fr, this message translates to:
  /// **'Aucune leçon disponible.'**
  String get noLessons;

  /// No description provided for @noQuizzes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun quiz disponible.'**
  String get noQuizzes;

  /// No description provided for @practice.
  ///
  /// In fr, this message translates to:
  /// **'Pratique'**
  String get practice;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get previous;

  /// No description provided for @finishUnit.
  ///
  /// In fr, this message translates to:
  /// **'Terminer l’unité'**
  String get finishUnit;

  /// No description provided for @restartUnit.
  ///
  /// In fr, this message translates to:
  /// **'Recommencer l’unité'**
  String get restartUnit;

  /// No description provided for @unitFinished.
  ///
  /// In fr, this message translates to:
  /// **'Unité terminée'**
  String get unitFinished;

  /// No description provided for @listenRepeat.
  ///
  /// In fr, this message translates to:
  /// **'Écoute et répète'**
  String get listenRepeat;

  /// No description provided for @reviewCharacters.
  ///
  /// In fr, this message translates to:
  /// **'Réviser les caractères'**
  String get reviewCharacters;

  /// No description provided for @reviewWords.
  ///
  /// In fr, this message translates to:
  /// **'Réviser les mots'**
  String get reviewWords;

  /// No description provided for @practiceLessons.
  ///
  /// In fr, this message translates to:
  /// **'Suivre les leçons'**
  String get practiceLessons;

  /// No description provided for @practiceQuiz.
  ///
  /// In fr, this message translates to:
  /// **'Réviser les quiz'**
  String get practiceQuiz;

  /// No description provided for @step.
  ///
  /// In fr, this message translates to:
  /// **'Étape'**
  String get step;

  /// No description provided for @sync.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation'**
  String get sync;

  /// No description provided for @syncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get syncNow;

  /// No description provided for @syncSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation réussie'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation échouée'**
  String get syncFailed;

  /// No description provided for @syncedItems.
  ///
  /// In fr, this message translates to:
  /// **'Éléments synchronisés'**
  String get syncedItems;

  /// No description provided for @noEnaSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Contenu qui mérite d’être regardé.'**
  String get noEnaSubtitle;

  /// No description provided for @featured.
  ///
  /// In fr, this message translates to:
  /// **'Mis en avant'**
  String get featured;

  /// No description provided for @cultureTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème culturel'**
  String get cultureTheme;

  /// No description provided for @contributor.
  ///
  /// In fr, this message translates to:
  /// **'Contributeur'**
  String get contributor;

  /// No description provided for @views.
  ///
  /// In fr, this message translates to:
  /// **'Vues'**
  String get views;

  /// No description provided for @openContent.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get openContent;

  /// No description provided for @noNoEna.
  ///
  /// In fr, this message translates to:
  /// **'Aucune publication No Ena disponible.'**
  String get noNoEna;

  /// No description provided for @image.
  ///
  /// In fr, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @video.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get video;

  /// No description provided for @audio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @playAudio.
  ///
  /// In fr, this message translates to:
  /// **'Lire l’audio'**
  String get playAudio;

  /// No description provided for @relatedContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu lié'**
  String get relatedContent;

  /// No description provided for @relatedCharacter.
  ///
  /// In fr, this message translates to:
  /// **'Caractère lié'**
  String get relatedCharacter;

  /// No description provided for @relatedWord.
  ///
  /// In fr, this message translates to:
  /// **'Mot lié'**
  String get relatedWord;

  /// No description provided for @relatedUnit.
  ///
  /// In fr, this message translates to:
  /// **'Unité liée'**
  String get relatedUnit;

  /// No description provided for @offlinePacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs hors ligne'**
  String get offlinePacks;

  /// No description provided for @offlinePacksSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Télécharge une fois, apprends ensuite sans internet.'**
  String get offlinePacksSubtitle;

  /// No description provided for @download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get downloaded;

  /// No description provided for @installing.
  ///
  /// In fr, this message translates to:
  /// **'Installation...'**
  String get installing;

  /// No description provided for @installedPacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs installés'**
  String get installedPacks;

  /// No description provided for @availablePacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs disponibles'**
  String get availablePacks;

  /// No description provided for @packSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get packSize;

  /// No description provided for @packItems.
  ///
  /// In fr, this message translates to:
  /// **'Éléments'**
  String get packItems;

  /// No description provided for @packVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get packVersion;

  /// No description provided for @openPack.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le pack'**
  String get openPack;

  /// No description provided for @noPacks.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pack disponible.'**
  String get noPacks;

  /// No description provided for @downloadSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Pack téléchargé avec succès'**
  String get downloadSuccess;

  /// No description provided for @downloadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du téléchargement'**
  String get downloadFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
