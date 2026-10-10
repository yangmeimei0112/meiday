import '../entities/nlp_parse_result.dart';

abstract class NlpParser {
  NlpParseResult parse(String rawText, {DateTime? referenceTime});
}
