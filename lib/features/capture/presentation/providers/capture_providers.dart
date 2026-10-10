import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/bilingual_nlp_parser.dart';
import '../../domain/entities/nlp_parse_result.dart';
import '../../domain/services/nlp_parser.dart';

final nlpParserProvider = Provider<NlpParser>((ref) {
  return const BilingualNlpParser();
});

final quickCaptureInputProvider = StateProvider<String>((ref) => '');

final quickCaptureParsedResultProvider = Provider<NlpParseResult>((ref) {
  final parser = ref.watch(nlpParserProvider);
  final text = ref.watch(quickCaptureInputProvider);
  return parser.parse(text);
});
