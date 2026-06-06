typedef VoiceLogAiFallback =
    Future<VoiceLogResult?> Function(String normalizedText);

class VoiceLogResult {
  const VoiceLogResult({
    this.flowIntensity,
    this.flowColor,
    this.symptoms = const [],
    this.mood = const [],
    this.energyLevel,
    this.painLevel,
    this.sleepQuality,
  });

  final String? flowIntensity;
  final String? flowColor;
  final List<String> symptoms;
  final List<String> mood;
  final int? energyLevel;
  final int? painLevel;
  final String? sleepQuality;

  VoiceLogResult mergeMissing(VoiceLogResult fallback) {
    return VoiceLogResult(
      flowIntensity: flowIntensity ?? fallback.flowIntensity,
      flowColor: flowColor ?? fallback.flowColor,
      symptoms:
          symptoms.isNotEmpty
              ? _dedupe([...symptoms, ...fallback.symptoms])
              : fallback.symptoms,
      mood:
          mood.isNotEmpty
              ? _dedupe([...mood, ...fallback.mood])
              : fallback.mood,
      energyLevel: energyLevel ?? fallback.energyLevel,
      painLevel: painLevel ?? fallback.painLevel,
      sleepQuality: sleepQuality ?? fallback.sleepQuality,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flowIntensity': flowIntensity,
      'flowColor': flowColor,
      'symptoms': symptoms,
      'mood': mood,
      'energyLevel': energyLevel,
      'painLevel': painLevel,
      'sleepQuality': sleepQuality,
    };
  }
}

class VoiceLogProcessor {
  const VoiceLogProcessor({this.aiFallback});

  final VoiceLogAiFallback? aiFallback;

  Future<VoiceLogResult> process(String rawText) async {
    final normalized = normalize(rawText);
    final mapped = _mapKeywords(normalized);
    if (!_needsFallback(mapped) || aiFallback == null) {
      return mapped;
    }
    final fallback = await aiFallback!(normalized);
    return fallback == null ? mapped : mapped.mergeMissing(fallback);
  }

  String normalize(String rawText) {
    final fillerPattern = RegExp(
      r'\b(um|uh|erm|like|just|actually|basically|you know|i mean)\b',
      caseSensitive: false,
    );
    return rawText
        .toLowerCase()
        .replaceAll(fillerPattern, ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _needsFallback(VoiceLogResult result) {
    return result.flowIntensity == null ||
        result.flowColor == null ||
        result.energyLevel == null ||
        result.painLevel == null ||
        result.sleepQuality == null;
  }

  VoiceLogResult _mapKeywords(String text) {
    return VoiceLogResult(
      flowIntensity: _firstMatch(text, const {
        'light': ['light bleeding', 'light flow', 'spotting', 'a little blood'],
        'medium': ['medium bleeding', 'moderate bleeding', 'normal flow'],
        'heavy': [
          'heavy bleeding',
          'heavy flow',
          'flooding',
          'soaked',
          'clots',
        ],
      }),
      flowColor: _firstMatch(text, const {
        'red': ['red blood', 'bright red', 'fresh blood', 'red flow'],
        'dark': ['dark blood', 'dark red', 'blackish', 'black blood'],
        'brown': ['brown blood', 'brown spotting'],
        'pink': ['pink blood', 'pink spotting', 'light pink'],
      }),
      symptoms: _matches(text, const {
        'cramps': ['cramp', 'cramps', 'cramping'],
        'back pain': ['back pain', 'lower back'],
        'headache': ['headache', 'migraine'],
        'bloating': ['bloated', 'bloating'],
        'tender breasts': ['tender breast', 'sore breast'],
        'nausea': ['nausea', 'nauseous'],
        'fatigue': ['fatigue', 'tired', 'exhausted', 'drained'],
        'acne': ['acne', 'breakout'],
        'cravings': ['craving', 'cravings'],
      }),
      mood: _matches(text, const {
        'calm': ['calm', 'relaxed'],
        'happy': ['happy', 'good mood', 'cheerful'],
        'sad': ['sad', 'down', 'low mood'],
        'anxious': ['anxious', 'anxiety', 'worried'],
        'irritable': ['irritable', 'angry', 'annoyed'],
        'tired': ['tired', 'fatigue', 'exhausted', 'drained'],
      }),
      energyLevel: _energyLevel(text),
      painLevel: _painLevel(text),
      sleepQuality: _firstMatch(text, const {
        'poor': [
          'bad sleep',
          'poor sleep',
          'not great sleep',
          'could not sleep',
          'terrible sleep',
          'slept badly',
        ],
        'fair': ['okay sleep', 'fair sleep', 'average sleep'],
        'good': ['good sleep', 'slept well', 'decent sleep'],
        'great': ['great sleep', 'excellent sleep', 'amazing sleep'],
      }),
    );
  }

  String? _firstMatch(String text, Map<String, List<String>> options) {
    for (final entry in options.entries) {
      if (entry.value.any(text.contains)) {
        return entry.key;
      }
    }
    return null;
  }

  List<String> _matches(String text, Map<String, List<String>> options) {
    return [
      for (final entry in options.entries)
        if (entry.value.any(text.contains)) entry.key,
    ];
  }

  int? _energyLevel(String text) {
    if (RegExp(
      r'\b(very tired|exhausted|drained|no energy)\b',
    ).hasMatch(text)) {
      return 2;
    }
    if (RegExp(r'\b(tired|low energy|fatigue)\b').hasMatch(text)) return 4;
    if (RegExp(r'\b(okay energy|normal energy)\b').hasMatch(text)) return 6;
    if (RegExp(r'\b(energized|high energy|active)\b').hasMatch(text)) return 8;
    if (RegExp(r'\b(great energy|full of energy)\b').hasMatch(text)) return 9;
    return null;
  }

  int? _painLevel(String text) {
    if (RegExp(r'\b(no pain|painless)\b').hasMatch(text)) return 0;
    if (RegExp(r'\b(mild pain|mild cramps|little pain)\b').hasMatch(text)) {
      return 3;
    }
    if (RegExp(
      r'\b(cramps|back pain|headache|moderate pain)\b',
    ).hasMatch(text)) {
      return 5;
    }
    if (RegExp(r'\b(severe pain|bad cramps|intense pain)\b').hasMatch(text)) {
      return 8;
    }
    if (RegExp(r'\b(unbearable pain|worst pain)\b').hasMatch(text)) return 10;
    return null;
  }
}

List<String> _dedupe(List<String> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (seen.add(value)) value,
  ];
}
