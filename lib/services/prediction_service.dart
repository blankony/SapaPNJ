class PredictionService {
  // --- 1. PERSONALIZED KNOWLEDGE BASE (Markov Chain) ---
  final Map<String, Map<String, int>> _userMarkovChain = {};

  final Map<String, List<String>> _globalPhraseDatabase = {
    'selamat': ['pagi', 'siang', 'malam', 'datang', 'jalan', 'ulang tahun'],
    'good': ['morning', 'night', 'luck', 'job', 'vibes', 'day'],
    'tomorrow': ['is monday', 'is friday', 'will be better'],
    'kuliah': ['umum', 'pengganti', 'libur', 'offline', 'online'],
    'politeknik': ['negeri jakarta'],
    'terima': ['kasih', 'kasih banyak'],
  };

  // --- 2. LEARNING ENGINE ---
  void learnFromUserPosts(List<String> posts) {
    _userMarkovChain.clear();
    for (String post in posts) {
      String cleanPost = post.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      List<String> words = cleanPost.split(RegExp(r'\s+'));

      for (int i = 0; i < words.length - 1; i++) {
        String current = words[i];
        String next = words[i + 1];
        if (!_userMarkovChain.containsKey(current)) {
          _userMarkovChain[current] = {};
        }
        _userMarkovChain[current]![next] = (_userMarkovChain[current]![next] ?? 0) + 1;
      }
    }
  }

  // --- 3. PREDICTIVE TEXT (Recursive Sentence Generation) ---
  Future<String?> getLocalPrediction(String currentText) async {
    if (currentText.trim().isEmpty) return null;

    final String text = currentText.toLowerCase();
    final List<String> words = text.trim().split(RegExp(r'\s+'));
    final String lastWord = words.last;

    String? personalizedPrediction = _generateChain(lastWord);

    if (personalizedPrediction == null && _globalPhraseDatabase.containsKey(lastWord)) {
      personalizedPrediction = _globalPhraseDatabase[lastWord]!.first;
    } else if (personalizedPrediction == null) {
      for (var key in _globalPhraseDatabase.keys) {
        if (key.startsWith(lastWord) && key != lastWord) {
          return key.substring(lastWord.length);
        }
      }
    }
    return personalizedPrediction;
  }

  String? _generateChain(String startWord) {
    if (!_userMarkovChain.containsKey(startWord)) return null;

    final StringBuffer prediction = StringBuffer();
    String current = startWord;
    int wordsAdded = 0;
    const int maxPredictionLength = 5;

    while (wordsAdded < maxPredictionLength) {
      final nextCandidates = _userMarkovChain[current];
      if (nextCandidates == null || nextCandidates.isEmpty) break;
      String bestNext = nextCandidates.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      prediction.write("$bestNext ");
      current = bestNext;
      wordsAdded++;
    }
    return prediction.isEmpty ? null : prediction.toString().trim();
  }


  // --- Algorithms 4-7 (Trending, Discover, Recommended, Community Recs) ---
  // These have been offloaded to Google Cloud Functions.
  // See: cloud_functions/api/routes/explore.js
  // See: cloud_functions/api/routes/communities.js (GET /recommended)
}

