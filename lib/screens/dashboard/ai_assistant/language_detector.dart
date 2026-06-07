class LanguageDetector {
  static const Set<String> _idWords = {
    'aku',
    'kamu',
    'dia',
    'kita',
    'kami',
    'mereka',
    'saya',
    'anda',
    'kalian',
    'gue',
    'lu',
    'elo',
    'gw',
    'lo',
    'beliau',
    'yang',
    'nya',
    'di',
    'ke',
    'dari',
    'pada',
    'untuk',
    'buat',
    'dan',
    'atau',
    'tapi',
    'tetapi',
    'karena',
    'jika',
    'kalau',
    'ada',
    'adalah',
    'ialah',
    'jadi',
    'bisa',
    'dapat',
    'mau',
    'ingin',
    'akan',
    'sudah',
    'telah',
    'belum',
    'pernah',
    'harus',
    'bantu',
    'tolong',
    'minta',
    'ngetes',
    'tidak',
    'tak',
    'bukan',
    'jangan',
    'gak',
    'nggak',
    'kagak',
    'enggak',
    'apa',
    'siapa',
    'kapan',
    'dimana',
    'kemana',
    'kenapa',
    'mengapa',
    'bagaimana',
    'berapa',
    'mana',
    'ngapain',
    'gimana',
    'hari',
    'besok',
    'kemarin',
    'sekarang',
    'nanti',
    'tadi',
    'banyak',
    'sedikit',
    'semua',
    'halo',
    'hai',
    'selamat',
    'pagi',
    'siang',
    'sore',
    'malam',
    'terima',
    'kasih',
    'dong',
    'sih',
    'deh',
    'kok',
    'yuk',
    'nih',
    'tuh',
    'lain',
    'lainnya',
  };

  static const Set<String> _enWords = {
    'the',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'should',
    'could',
    'can',
    'may',
    'might',
    'what',
    'where',
    'when',
    'why',
    'how',
    'who',
    'which',
    'this',
    'that',
    'these',
    'those',
    'not',
    'no',
    'yes',
  };

  static String detect(String text) {
    if (text.trim().isEmpty) return 'en-US';

    final cleanText = text.toLowerCase().trim();
    var idScore = 0;
    var enScore = 0;

    if (RegExp(r'\b(meng|peng|ber|ter|ke|se)\w+').hasMatch(cleanText)) {
      idScore += 3;
    }
    if (RegExp(r'\w+nya\b').hasMatch(cleanText)) {
      idScore += 3;
    }
    if (RegExp(r'\bdi\s+\w+').hasMatch(cleanText)) {
      idScore += 2;
    }

    final words = cleanText
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1)
        .toList();

    for (final word in words) {
      if (_idWords.contains(word)) idScore += 2;
      if (_enWords.contains(word)) enScore += 2;
    }

    if (RegExp(r'[bcdfghjklmnpqrstvwxyz]{4,}').hasMatch(cleanText)) {
      enScore += 1;
    }

    if (idScore > enScore) return 'id-ID';
    if (enScore > idScore) return 'en-US';

    if (RegExp(r'\b(yang|nya|di|ke|dari|untuk|dan)\b').hasMatch(cleanText)) {
      return 'id-ID';
    }

    return 'en-US';
  }
}
