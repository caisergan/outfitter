import 'package:freezed_annotation/freezed_annotation.dart';

part 'playground_models.freezed.dart';
part 'playground_models.g.dart';

@freezed
class PlaygroundSystemPrompt with _$PlaygroundSystemPrompt {
  const factory PlaygroundSystemPrompt({
    required String id,
    required String slug,
    required String label,
    required String content,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _PlaygroundSystemPrompt;

  factory PlaygroundSystemPrompt.fromJson(Map<String, dynamic> json) =>
      _$PlaygroundSystemPromptFromJson(json);
}

@freezed
class PlaygroundTemplate with _$PlaygroundTemplate {
  const factory PlaygroundTemplate({
    required String id,
    required String slug,
    required String label,
    String? description,
    required String body,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _PlaygroundTemplate;

  factory PlaygroundTemplate.fromJson(Map<String, dynamic> json) =>
      _$PlaygroundTemplateFromJson(json);
}

@freezed
class PlaygroundPersona with _$PlaygroundPersona {
  const factory PlaygroundPersona({
    required String id,
    required String slug,
    required String label,
    required String gender,
    required String description,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _PlaygroundPersona;

  factory PlaygroundPersona.fromJson(Map<String, dynamic> json) =>
      _$PlaygroundPersonaFromJson(json);
}

@freezed
class PlaygroundRun with _$PlaygroundRun {
  const factory PlaygroundRun({
    required String id,
    @JsonKey(name: 'catalog_item_ids') required List<String> catalogItemIds,
    @JsonKey(name: 'system_prompt_id') String? systemPromptId,
    @JsonKey(name: 'template_id') String? templateId,
    @JsonKey(name: 'persona_id') String? personaId,
    @JsonKey(name: 'system_prompt_text') required String systemPromptText,
    @JsonKey(name: 'user_prompt_text') required String userPromptText,
    @JsonKey(name: 'final_prompt_text') required String finalPromptText,
    required String size,
    required String quality,
    required int n,
    @JsonKey(name: 'image_keys') required List<String> imageKeys,
    required List<String> images,
    @JsonKey(name: 'model_name') required String modelName,
    @JsonKey(name: 'elapsed_ms') required int elapsedMs,
    required String status,
    @JsonKey(name: 'error_message') String? errorMessage,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _PlaygroundRun;

  factory PlaygroundRun.fromJson(Map<String, dynamic> json) =>
      _$PlaygroundRunFromJson(json);
}

@freezed
class PlaygroundRunsPage with _$PlaygroundRunsPage {
  const factory PlaygroundRunsPage({
    required List<PlaygroundRun> items,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _PlaygroundRunsPage;

  factory PlaygroundRunsPage.fromJson(Map<String, dynamic> json) =>
      _$PlaygroundRunsPageFromJson(json);
}

@freezed
class GenerateRequest with _$GenerateRequest {
  const factory GenerateRequest({
    @JsonKey(name: 'catalog_item_ids') required List<String> catalogItemIds,
    @JsonKey(name: 'system_prompt') required String systemPrompt,
    @JsonKey(name: 'user_prompt') @Default('') String userPrompt,
    @JsonKey(name: 'template_id') String? templateId,
    @JsonKey(name: 'persona_id') String? personaId,
    @Default('1024x1536') String size,
    @Default('high') String quality,
    @Default(1) int n,
  }) = _GenerateRequest;

  factory GenerateRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerateRequestFromJson(json);
}

@freezed
class GenerateResponse with _$GenerateResponse {
  const factory GenerateResponse({
    @JsonKey(name: 'run_id') required String runId,
    required List<String> images,
    required String model,
    @JsonKey(name: 'item_count') required int itemCount,
    @JsonKey(name: 'elapsed_ms') required int elapsedMs,
    @JsonKey(name: 'daily_used') required int dailyUsed,
    @JsonKey(name: 'daily_limit') required int dailyLimit,
  }) = _GenerateResponse;

  factory GenerateResponse.fromJson(Map<String, dynamic> json) =>
      _$GenerateResponseFromJson(json);
}
