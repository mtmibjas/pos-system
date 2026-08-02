// This is a generated file - do not edit.
//
// Generated from pos/v1/auth_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

import '../../google/protobuf/timestamp.pbjson.dart' as $0;

@$core.Deprecated('Use registerDeviceRequestDescriptor instead')
const RegisterDeviceRequest$json = {
  '1': 'RegisterDeviceRequest',
  '2': [
    {'1': 'manager_username', '3': 1, '4': 1, '5': 9, '10': 'managerUsername'},
    {'1': 'manager_password', '3': 2, '4': 1, '5': 9, '10': 'managerPassword'},
    {'1': 'device_name', '3': 3, '4': 1, '5': 9, '10': 'deviceName'},
    {
      '1': 'replace_counter_id',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'replaceCounterId'
    },
  ],
};

/// Descriptor for `RegisterDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceRequestDescriptor = $convert.base64Decode(
    'ChVSZWdpc3RlckRldmljZVJlcXVlc3QSKQoQbWFuYWdlcl91c2VybmFtZRgBIAEoCVIPbWFuYW'
    'dlclVzZXJuYW1lEikKEG1hbmFnZXJfcGFzc3dvcmQYAiABKAlSD21hbmFnZXJQYXNzd29yZBIf'
    'CgtkZXZpY2VfbmFtZRgDIAEoCVIKZGV2aWNlTmFtZRIsChJyZXBsYWNlX2NvdW50ZXJfaWQYBC'
    'ABKAlSEHJlcGxhY2VDb3VudGVySWQ=');

@$core.Deprecated('Use registerDeviceResponseDescriptor instead')
const RegisterDeviceResponse$json = {
  '1': 'RegisterDeviceResponse',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'device_secret', '3': 2, '4': 1, '5': 9, '10': 'deviceSecret'},
    {'1': 'store_id', '3': 3, '4': 1, '5': 9, '10': 'storeId'},
    {'1': 'counter_id', '3': 4, '4': 1, '5': 9, '10': 'counterId'},
  ],
};

/// Descriptor for `RegisterDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceResponseDescriptor = $convert.base64Decode(
    'ChZSZWdpc3RlckRldmljZVJlc3BvbnNlEhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQSIw'
    'oNZGV2aWNlX3NlY3JldBgCIAEoCVIMZGV2aWNlU2VjcmV0EhkKCHN0b3JlX2lkGAMgASgJUgdz'
    'dG9yZUlkEh0KCmNvdW50ZXJfaWQYBCABKAlSCWNvdW50ZXJJZA==');

@$core.Deprecated('Use loginRequestDescriptor instead')
const LoginRequest$json = {
  '1': 'LoginRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'device_secret', '3': 2, '4': 1, '5': 9, '10': 'deviceSecret'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 4, '4': 1, '5': 9, '10': 'password'},
  ],
};

/// Descriptor for `LoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginRequestDescriptor = $convert.base64Decode(
    'CgxMb2dpblJlcXVlc3QSGwoJZGV2aWNlX2lkGAEgASgJUghkZXZpY2VJZBIjCg1kZXZpY2Vfc2'
    'VjcmV0GAIgASgJUgxkZXZpY2VTZWNyZXQSGgoIdXNlcm5hbWUYAyABKAlSCHVzZXJuYW1lEhoK'
    'CHBhc3N3b3JkGAQgASgJUghwYXNzd29yZA==');

@$core.Deprecated('Use loginResponseDescriptor instead')
const LoginResponse$json = {
  '1': 'LoginResponse',
  '2': [
    {'1': 'access_token', '3': 1, '4': 1, '5': 9, '10': 'accessToken'},
    {
      '1': 'expires_at',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
    {'1': 'tenant_id', '3': 3, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'roles', '3': 4, '4': 3, '5': 9, '10': 'roles'},
    {'1': 'user_display_name', '3': 5, '4': 1, '5': 9, '10': 'userDisplayName'},
    {'1': 'store_id', '3': 6, '4': 1, '5': 9, '10': 'storeId'},
    {'1': 'counter_id', '3': 7, '4': 1, '5': 9, '10': 'counterId'},
  ],
};

/// Descriptor for `LoginResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginResponseDescriptor = $convert.base64Decode(
    'Cg1Mb2dpblJlc3BvbnNlEiEKDGFjY2Vzc190b2tlbhgBIAEoCVILYWNjZXNzVG9rZW4SOQoKZX'
    'hwaXJlc19hdBgCIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWV4cGlyZXNBdBIb'
    'Cgl0ZW5hbnRfaWQYAyABKAlSCHRlbmFudElkEhQKBXJvbGVzGAQgAygJUgVyb2xlcxIqChF1c2'
    'VyX2Rpc3BsYXlfbmFtZRgFIAEoCVIPdXNlckRpc3BsYXlOYW1lEhkKCHN0b3JlX2lkGAYgASgJ'
    'UgdzdG9yZUlkEh0KCmNvdW50ZXJfaWQYByABKAlSCWNvdW50ZXJJZA==');

const $core.Map<$core.String, $core.dynamic> AuthServiceBase$json = {
  '1': 'AuthService',
  '2': [
    {
      '1': 'RegisterDevice',
      '2': '.pos.v1.RegisterDeviceRequest',
      '3': '.pos.v1.RegisterDeviceResponse'
    },
    {'1': 'Login', '2': '.pos.v1.LoginRequest', '3': '.pos.v1.LoginResponse'},
  ],
};

@$core.Deprecated('Use authServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    AuthServiceBase$messageJson = {
  '.pos.v1.RegisterDeviceRequest': RegisterDeviceRequest$json,
  '.pos.v1.RegisterDeviceResponse': RegisterDeviceResponse$json,
  '.pos.v1.LoginRequest': LoginRequest$json,
  '.pos.v1.LoginResponse': LoginResponse$json,
  '.google.protobuf.Timestamp': $0.Timestamp$json,
};

/// Descriptor for `AuthService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List authServiceDescriptor = $convert.base64Decode(
    'CgtBdXRoU2VydmljZRJPCg5SZWdpc3RlckRldmljZRIdLnBvcy52MS5SZWdpc3RlckRldmljZV'
    'JlcXVlc3QaHi5wb3MudjEuUmVnaXN0ZXJEZXZpY2VSZXNwb25zZRI0CgVMb2dpbhIULnBvcy52'
    'MS5Mb2dpblJlcXVlc3QaFS5wb3MudjEuTG9naW5SZXNwb25zZQ==');
