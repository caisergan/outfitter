import 'package:freezed_annotation/freezed_annotation.dart';

part 'tryon_models.freezed.dart';
part 'tryon_models.g.dart';

@freezed
class TryOnSystemPrompt with _$TryOnSystemPrompt {
  const factory TryOnSystemPrompt({
    required String id,
    required String slug,
    required String label,
    required String content,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _TryOnSystemPrompt;

  factory TryOnSystemPrompt.fromJson(Map<String, dynamic> json) =>
      _$TryOnSystemPromptFromJson(json);
}

@freezed
class TryOnTemplate with _$TryOnTemplate {
  const factory TryOnTemplate({
    required String id,
    required String slug,
    required String label,
    String? description,
    required String body,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _TryOnTemplate;

  factory TryOnTemplate.fromJson(Map<String, dynamic> json) =>
      _$TryOnTemplateFromJson(json);
}

@freezed
class TryOnPersona with _$TryOnPersona {
  const factory TryOnPersona({
    required String id,
    required String slug,
    required String label,
    required String gender,
    required String description,
    @JsonKey(name: 'is_active') required bool isActive,
  }) = _TryOnPersona;

  factory TryOnPersona.fromJson(Map<String, dynamic> json) =>
      _$TryOnPersonaFromJson(json);
}

@freezed
class TryOnRun with _$TryOnRun {
  const factory TryOnRun({
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
  }) = _TryOnRun;

  factory TryOnRun.fromJson(Map<String, dynamic> json) =>
      _$TryOnRunFromJson(json);
}

@freezed
class TryOnRunsPage with _$TryOnRunsPage {
  const factory TryOnRunsPage({
    required List<TryOnRun> items,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _TryOnRunsPage;

  factory TryOnRunsPage.fromJson(Map<String, dynamic> json) =>
      _$TryOnRunsPageFromJson(json);
}

@freezed
class TryOnGenerateRequest with _$TryOnGenerateRequest {
  const factory TryOnGenerateRequest({
    @JsonKey(name: 'catalog_item_ids') required List<String> catalogItemIds,
    @JsonKey(name: 'system_prompt') required String systemPrompt,
    @JsonKey(name: 'user_prompt') @Default('') String userPrompt,
    @JsonKey(name: 'template_id') String? templateId,
    @JsonKey(name: 'persona_id') String? personaId,
    @Default('1024x1536') String size,
    @Default('high') String quality,
    @Default(1) int n,
  }) = _TryOnGenerateRequest;

  factory TryOnGenerateRequest.fromJson(Map<String, dynamic> json) =>
      _$TryOnGenerateRequestFromJson(json);
}

@freezed
class TryOnGenerateResponse with _$TryOnGenerateResponse {
  const factory TryOnGenerateResponse({
    @JsonKey(name: 'run_id') required String runId,
    required String status,
    required List<String> images,
    required String model,
    @JsonKey(name: 'item_count') required int itemCount,
    @JsonKey(name: 'elapsed_ms') required int elapsedMs,
    @JsonKey(name: 'daily_used') required int dailyUsed,
    @JsonKey(name: 'daily_limit') required int dailyLimit,
  }) = _TryOnGenerateResponse;

  factory TryOnGenerateResponse.fromJson(Map<String, dynamic> json) =>
      _$TryOnGenerateResponseFromJson(json);
}
