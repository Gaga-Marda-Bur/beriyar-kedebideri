import '../../features/alphabet/alphabet_api_service.dart';
import '../../features/learning/learning_api_service.dart';
import '../../features/lessons/lessons_api_service.dart';
import '../../features/no_ena/no_ena_api_service.dart';
import '../../features/quiz/quiz_api_service.dart';
import '../../features/vocabulary/vocabulary_api_service.dart';

class BackendBootstrapSummary {
  final int charactersCount;
  final int wordsCount;
  final int themesCount;
  final int unitsCount;
  final int lessonsCount;
  final int quizzesCount;
  final int noEnaCount;

  const BackendBootstrapSummary({
    required this.charactersCount,
    required this.wordsCount,
    required this.themesCount,
    required this.unitsCount,
    required this.lessonsCount,
    required this.quizzesCount,
    required this.noEnaCount,
  });
}

class BackendBootstrapService {
  final AlphabetApiService _alphabetApiService;
  final VocabularyApiService _vocabularyApiService;
  final LearningApiService _learningApiService;
  final LessonsApiService _lessonsApiService;
  final QuizApiService _quizApiService;
  final NoEnaApiService _noEnaApiService;

  BackendBootstrapService({
    AlphabetApiService? alphabetApiService,
    VocabularyApiService? vocabularyApiService,
    LearningApiService? learningApiService,
    LessonsApiService? lessonsApiService,
    QuizApiService? quizApiService,
    NoEnaApiService? noEnaApiService,
  })  : _alphabetApiService = alphabetApiService ?? AlphabetApiService(),
        _vocabularyApiService = vocabularyApiService ?? VocabularyApiService(),
        _learningApiService = learningApiService ?? LearningApiService(),
        _lessonsApiService = lessonsApiService ?? LessonsApiService(),
        _quizApiService = quizApiService ?? QuizApiService(),
        _noEnaApiService = noEnaApiService ?? NoEnaApiService();

  Future<BackendBootstrapSummary> loadSummary() async {
    final results = await Future.wait([
      _alphabetApiService.fetchCharacters(),
      _vocabularyApiService.fetchWords(),
      _learningApiService.fetchThemes(),
      _learningApiService.fetchUnits(),
      _lessonsApiService.fetchLessons(),
      _quizApiService.fetchQuizzes(),
      _noEnaApiService.fetchPublications(),
    ]);

    return BackendBootstrapSummary(
      charactersCount: results[0].length,
      wordsCount: results[1].length,
      themesCount: results[2].length,
      unitsCount: results[3].length,
      lessonsCount: results[4].length,
      quizzesCount: results[5].length,
      noEnaCount: results[6].length,
    );
  }
}