import 'outbox_mutation.dart';

class BatchSyncPayload {
  final String idempotencyKey;
  final String deviceId;
  final String userId;
  final DateTime sentAt;
  final List<OutboxMutation> mutations;

  const BatchSyncPayload({
    required this.idempotencyKey,
    required this.deviceId,
    required this.userId,
    required this.sentAt,
    required this.mutations,
  });

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'device_id': deviceId,
        'user_id': userId,
        'sent_at': sentAt.toIso8601String(),
        'mutations': mutations.map((m) => m.toJson()).toList(),
      };

  factory BatchSyncPayload.fromJson(Map<String, dynamic> json) {
    return BatchSyncPayload(
      idempotencyKey: json['idempotency_key'] as String,
      deviceId: json['device_id'] as String,
      userId: json['user_id'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      mutations: (json['mutations'] as List<dynamic>)
          .map((item) => OutboxMutation.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BatchSyncResult {
  final String idempotencyKey;
  final bool isSuccess;
  final int appliedCount;
  final int skippedDuplicateCount;
  final List<String> rejectedMutationIds;
  final String? errorMessage;

  const BatchSyncResult({
    required this.idempotencyKey,
    required this.isSuccess,
    this.appliedCount = 0,
    this.skippedDuplicateCount = 0,
    this.rejectedMutationIds = const [],
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'is_success': isSuccess,
        'applied_count': appliedCount,
        'skipped_duplicate_count': skippedDuplicateCount,
        'rejected_mutation_ids': rejectedMutationIds,
        'error_message': errorMessage,
      };

  factory BatchSyncResult.fromJson(Map<String, dynamic> json) {
    return BatchSyncResult(
      idempotencyKey: json['idempotency_key'] as String,
      isSuccess: json['is_success'] as bool,
      appliedCount: json['applied_count'] as int? ?? 0,
      skippedDuplicateCount: json['skipped_duplicate_count'] as int? ?? 0,
      rejectedMutationIds: (json['rejected_mutation_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      errorMessage: json['error_message'] as String?,
    );
  }
}
