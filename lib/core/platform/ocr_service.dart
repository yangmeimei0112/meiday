import 'dart:typed_data';

/// Enumeration of OCR execution backends
enum OcrEngineSource {
  winrt,     // Windows 10/11 native WinRT OcrEngine (100% offline)
  mlkit,     // Mobile Google ML Kit (100% offline)
  cloudByok, // User-provided BYOK cloud vision (OpenAI, Gemini, Ollama)
  mock,      // Test double
}

/// Normalized bounding box representation for recognized text
class OcrBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory OcrBoundingBox.fromJson(Map<String, dynamic> json) => OcrBoundingBox(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );
}

/// A line segment of recognized text with geometry and confidence
class OcrLine {
  final String text;
  final double confidence;
  final OcrBoundingBox? boundingBox;

  const OcrLine({
    required this.text,
    this.confidence = 1.0,
    this.boundingBox,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence,
    'boundingBox': boundingBox?.toJson(),
  };

  factory OcrLine.fromJson(Map<String, dynamic> json) => OcrLine(
    text: json['text'] as String? ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    boundingBox: json['boundingBox'] != null
        ? OcrBoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>)
        : null,
  );

  @override
  String toString() => text;
}

/// Comprehensive OCR extraction result
class OcrResult {
  final String text;
  final List<OcrLine> lines;
  final double confidence; // Normalized 0.0 to 1.0
  final OcrEngineSource source;
  final Map<String, dynamic> metadata;

  const OcrResult({
    required this.text,
    required this.lines,
    this.confidence = 1.0,
    this.source = OcrEngineSource.mock,
    this.metadata = const {},
  });

  static const empty = OcrResult(
    text: '',
    lines: [],
    confidence: 0.0,
    source: OcrEngineSource.mock,
  );

  /// Backwards-compatibility getter for line strings
  List<String> get rawLines => lines.map((l) => l.text).toList();

  bool get isLowConfidence => confidence < 0.60;
  bool get isEmpty => text.trim().isEmpty;
  bool get isNotEmpty => text.trim().isNotEmpty;

  OcrResult copyWith({
    String? text,
    List<OcrLine>? lines,
    double? confidence,
    OcrEngineSource? source,
    Map<String, dynamic>? metadata,
  }) {
    return OcrResult(
      text: text ?? this.text,
      lines: lines ?? this.lines,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Core platform OCR abstraction
abstract class OcrService {
  Future<bool> isAvailable();
  Future<OcrResult> extractText(Uint8List imageBytes, {String? languageHint});
  Future<OcrResult> extractTextFromPath(String imagePath, {String? languageHint});
}

/// Headless test double implementing OcrService
class MockOcrService implements OcrService {
  bool _isAvailable = true;
  OcrResult? _cannedResult;
  Exception? _cannedException;
  int _callCount = 0;
  Uint8List? _lastImageBytes;
  String? _lastImagePath;

  void setAvailability(bool available) => _isAvailable = available;
  void setCannedResult(OcrResult result) => _cannedResult = result;

  void setCannedText(String text, {double confidence = 1.0, OcrEngineSource source = OcrEngineSource.mock}) {
    final lineStrings = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    _cannedResult = OcrResult(
      text: text,
      lines: lineStrings.map((l) => OcrLine(text: l, confidence: confidence)).toList(),
      confidence: confidence,
      source: source,
    );
  }

  void setCannedError(Exception error) => _cannedException = error;

  int get callCount => _callCount;
  Uint8List? get lastImageBytes => _lastImageBytes;
  String? get lastImagePath => _lastImagePath;

  void reset() {
    _isAvailable = true;
    _cannedResult = null;
    _cannedException = null;
    _callCount = 0;
    _lastImageBytes = null;
    _lastImagePath = null;
  }

  @override
  Future<bool> isAvailable() async => _isAvailable;

  @override
  Future<OcrResult> extractText(Uint8List imageBytes, {String? languageHint}) async {
    _callCount++;
    _lastImageBytes = imageBytes;
    if (_cannedException != null) throw _cannedException!;
    return _cannedResult ??
        const OcrResult(
          text: '2026/10/15 14:00 專案週會\n地點：會議室 A',
          lines: [
            OcrLine(text: '2026/10/15 14:00 專案週會', confidence: 0.98),
            OcrLine(text: '地點：會議室 A', confidence: 0.98),
          ],
          confidence: 0.98,
          source: OcrEngineSource.mock,
        );
  }

  @override
  Future<OcrResult> extractTextFromPath(String imagePath, {String? languageHint}) async {
    _callCount++;
    _lastImagePath = imagePath;
    if (_cannedException != null) throw _cannedException!;
    return _cannedResult ??
        const OcrResult(
          text: '2026/10/15 14:00 專案週會\n地點：會議室 A',
          lines: [
            OcrLine(text: '2026/10/15 14:00 專案週會', confidence: 0.98),
            OcrLine(text: '地點：會議室 A', confidence: 0.98),
          ],
          confidence: 0.98,
          source: OcrEngineSource.mock,
        );
  }
}
