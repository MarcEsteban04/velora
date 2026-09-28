import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/ai/ai_client.dart';

void main() {
  test("Groq's thinking models keep their thinking short", () {
    expect(AiClient.groqReasoning('openai/gpt-oss-120b'), {
      'reasoning_effort': 'low',
      'include_reasoning': false,
    });
    expect(AiClient.groqReasoning('qwen/qwen3.8-27b'), {
      'reasoning_effort': 'none',
    });
    expect(AiClient.groqReasoning('some-other-model'), isEmpty);
  });
}
