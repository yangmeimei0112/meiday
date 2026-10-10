enum SyncAction {
  insert,
  update,
  delete;

  static SyncAction fromString(String val) {
    switch (val.toUpperCase()) {
      case 'INSERT':
        return SyncAction.insert;
      case 'UPDATE':
        return SyncAction.update;
      case 'DELETE':
        return SyncAction.delete;
      default:
        return SyncAction.update;
    }
  }

  String toDbString() => name.toUpperCase();
}

enum SyncStatus {
  pending,
  processing,
  synced,
  failed;

  static SyncStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'pending':
        return SyncStatus.pending;
      case 'processing':
        return SyncStatus.processing;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }
}

class OutboxMutation {
  final String id;
  final String tableName;
  final String recordId;
  final SyncAction action;
  final String payloadJson;
  final DateTime clientTimestamp;
  final int retryCount;
  final SyncStatus status;
  final String? errorMessage;
  final String? idempotencyKey;

  const OutboxMutation({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    required this.payloadJson,
    required this.clientTimestamp,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
    this.errorMessage,
    this.idempotencyKey,
  });

  OutboxMutation copyWith({
    String? id,
    String? tableName,
    String? recordId,
    SyncAction? action,
    String? payloadJson,
    DateTime? clientTimestamp,
    int? retryCount,
    SyncStatus? status,
    String? errorMessage,
    String? idempotencyKey,
  }) {
    return OutboxMutation(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      action: action ?? this.action,
      payloadJson: payloadJson ?? this.payloadJson,
      clientTimestamp: clientTimestamp ?? this.clientTimestamp,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'action': action.toDbString(),
        'payload_json': payloadJson,
        'client_timestamp': clientTimestamp.toIso8601String(),
        'retry_count': retryCount,
        'status': status.name,
        'error_message': errorMessage,
        'idempotency_key': idempotencyKey,
      };

  factory OutboxMutation.fromJson(Map<String, dynamic> json) {
    return OutboxMutation(
      id: json['id'] as String,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      action: SyncAction.fromString(json['action'] as String),
      payloadJson: json['payload_json'] as String,
      clientTimestamp: DateTime.parse(json['client_timestamp'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      status: SyncStatus.fromString(json['status'] as String? ?? 'pending'),
      errorMessage: json['error_message'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
    );
  }
}
