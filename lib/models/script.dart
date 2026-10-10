/// Un guion: título + contenido que se lee en el teleprompter.
class Script {
  const Script({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Script.create({String title = '', String content = ''}) {
    final now = DateTime.now();
    return Script(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Script.fromJson(Map<String, dynamic> json) => Script(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
  );

  /// Palabras por minuto de una lectura natural frente a cámara.
  static const wordsPerMinute = 150;

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle => title.trim().isEmpty ? 'Sin título' : title.trim();

  bool get isEmpty => title.trim().isEmpty && content.trim().isEmpty;

  int get wordCount => countWords(content);

  Duration get readingTime => estimateReadingTime(content);

  Script copyWith({String? title, String? content, DateTime? updatedAt}) => Script(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  static int countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  static Duration estimateReadingTime(String text) {
    final seconds = (countWords(text) / wordsPerMinute * 60).round();
    return Duration(seconds: seconds);
  }
}
