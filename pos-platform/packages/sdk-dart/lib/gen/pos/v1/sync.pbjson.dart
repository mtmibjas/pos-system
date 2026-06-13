// This is a generated file - do not edit.
//
// Generated from pos/v1/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use operationDescriptor instead')
const Operation$json = {
  '1': 'Operation',
  '2': [
    {
      '1': 'operation_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.OperationId',
      '10': 'operationId'
    },
    {'1': 'operation_type', '3': 2, '4': 1, '5': 9, '10': 'operationType'},
    {'1': 'entity_type', '3': 3, '4': 1, '5': 9, '10': 'entityType'},
    {'1': 'entity_id', '3': 4, '4': 1, '5': 9, '10': 'entityId'},
    {
      '1': 'envelope',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.EventEnvelope',
      '10': 'envelope'
    },
    {
      '1': 'created_at',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'origin',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.OriginNode',
      '10': 'origin'
    },
    {'1': 'retry_count', '3': 8, '4': 1, '5': 13, '10': 'retryCount'},
  ],
};

/// Descriptor for `Operation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationDescriptor = $convert.base64Decode(
    'CglPcGVyYXRpb24SNgoMb3BlcmF0aW9uX2lkGAEgASgLMhMucG9zLnYxLk9wZXJhdGlvbklkUg'
    'tvcGVyYXRpb25JZBIlCg5vcGVyYXRpb25fdHlwZRgCIAEoCVINb3BlcmF0aW9uVHlwZRIfCgtl'
    'bnRpdHlfdHlwZRgDIAEoCVIKZW50aXR5VHlwZRIbCgllbnRpdHlfaWQYBCABKAlSCGVudGl0eU'
    'lkEjEKCGVudmVsb3BlGAUgASgLMhUucG9zLnYxLkV2ZW50RW52ZWxvcGVSCGVudmVsb3BlEjkK'
    'CmNyZWF0ZWRfYXQYBiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQX'
    'QSKgoGb3JpZ2luGAcgASgLMhIucG9zLnYxLk9yaWdpbk5vZGVSBm9yaWdpbhIfCgtyZXRyeV9j'
    'b3VudBgIIAEoDVIKcmV0cnlDb3VudA==');

@$core.Deprecated('Use syncBatchDescriptor instead')
const SyncBatch$json = {
  '1': 'SyncBatch',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {
      '1': 'tenant_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.TenantId',
      '10': 'tenantId'
    },
    {
      '1': 'operations',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.Operation',
      '10': 'operations'
    },
    {
      '1': 'client_sent_at',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'clientSentAt'
    },
  ],
};

/// Descriptor for `SyncBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncBatchDescriptor = $convert.base64Decode(
    'CglTeW5jQmF0Y2gSGQoIYmF0Y2hfaWQYASABKAlSB2JhdGNoSWQSLQoJdGVuYW50X2lkGAIgAS'
    'gLMhAucG9zLnYxLlRlbmFudElkUgh0ZW5hbnRJZBIxCgpvcGVyYXRpb25zGAMgAygLMhEucG9z'
    'LnYxLk9wZXJhdGlvblIKb3BlcmF0aW9ucxJACg5jbGllbnRfc2VudF9hdBgEIAEoCzIaLmdvb2'
    'dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSDGNsaWVudFNlbnRBdA==');

@$core.Deprecated('Use syncBatchAckDescriptor instead')
const SyncBatchAck$json = {
  '1': 'SyncBatchAck',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.pos.v1.SyncBatchAck.Status',
      '10': 'status'
    },
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'operation_acks',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.OperationAck',
      '10': 'operationAcks'
    },
  ],
  '4': [SyncBatchAck_Status$json],
};

@$core.Deprecated('Use syncBatchAckDescriptor instead')
const SyncBatchAck_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'STATUS_UNSPECIFIED', '2': 0},
    {'1': 'STATUS_APPLIED', '2': 1},
    {'1': 'STATUS_DUPLICATE', '2': 2},
    {'1': 'STATUS_REJECTED', '2': 3},
    {'1': 'STATUS_RETRY_LATER', '2': 4},
  ],
};

/// Descriptor for `SyncBatchAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncBatchAckDescriptor = $convert.base64Decode(
    'CgxTeW5jQmF0Y2hBY2sSGQoIYmF0Y2hfaWQYASABKAlSB2JhdGNoSWQSMwoGc3RhdHVzGAIgAS'
    'gOMhsucG9zLnYxLlN5bmNCYXRjaEFjay5TdGF0dXNSBnN0YXR1cxIYCgdtZXNzYWdlGAMgASgJ'
    'UgdtZXNzYWdlEjsKDm9wZXJhdGlvbl9hY2tzGAQgAygLMhQucG9zLnYxLk9wZXJhdGlvbkFja1'
    'INb3BlcmF0aW9uQWNrcyJ3CgZTdGF0dXMSFgoSU1RBVFVTX1VOU1BFQ0lGSUVEEAASEgoOU1RB'
    'VFVTX0FQUExJRUQQARIUChBTVEFUVVNfRFVQTElDQVRFEAISEwoPU1RBVFVTX1JFSkVDVEVEEA'
    'MSFgoSU1RBVFVTX1JFVFJZX0xBVEVSEAQ=');

@$core.Deprecated('Use operationAckDescriptor instead')
const OperationAck$json = {
  '1': 'OperationAck',
  '2': [
    {
      '1': 'operation_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.pos.v1.SyncBatchAck.Status',
      '10': 'status'
    },
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `OperationAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationAckDescriptor = $convert.base64Decode(
    'CgxPcGVyYXRpb25BY2sSNgoMb3BlcmF0aW9uX2lkGAEgASgLMhMucG9zLnYxLk9wZXJhdGlvbk'
    'lkUgtvcGVyYXRpb25JZBIzCgZzdGF0dXMYAiABKA4yGy5wb3MudjEuU3luY0JhdGNoQWNrLlN0'
    'YXR1c1IGc3RhdHVzEhQKBWVycm9yGAMgASgJUgVlcnJvcg==');
