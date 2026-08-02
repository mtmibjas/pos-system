// This is a generated file - do not edit.
//
// Generated from pos/v1/auth_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../../google/protobuf/timestamp.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// RegisterDeviceRequest carries the manager's credentials (verified inline,
/// never logged) plus how to place the new device.
///
/// counter_id is SERVER-ASSIGNED (sequential per store) — the manager does
/// not pick it. For a till swap, set replace_counter_id to re-provision an
/// existing counter: the server revokes the old device and reuses that
/// counter_id so shift reports/audit stay continuous across the swap.
class RegisterDeviceRequest extends $pb.GeneratedMessage {
  factory RegisterDeviceRequest({
    $core.String? managerUsername,
    $core.String? managerPassword,
    $core.String? deviceName,
    $core.String? replaceCounterId,
  }) {
    final result = create();
    if (managerUsername != null) result.managerUsername = managerUsername;
    if (managerPassword != null) result.managerPassword = managerPassword;
    if (deviceName != null) result.deviceName = deviceName;
    if (replaceCounterId != null) result.replaceCounterId = replaceCounterId;
    return result;
  }

  RegisterDeviceRequest._();

  factory RegisterDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'managerUsername')
    ..aOS(2, _omitFieldNames ? '' : 'managerPassword')
    ..aOS(3, _omitFieldNames ? '' : 'deviceName')
    ..aOS(4, _omitFieldNames ? '' : 'replaceCounterId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceRequest clone() =>
      RegisterDeviceRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceRequest copyWith(
          void Function(RegisterDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterDeviceRequest))
          as RegisterDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest create() => RegisterDeviceRequest._();
  @$core.override
  RegisterDeviceRequest createEmptyInstance() => create();
  static $pb.PbList<RegisterDeviceRequest> createRepeated() =>
      $pb.PbList<RegisterDeviceRequest>();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterDeviceRequest>(create);
  static RegisterDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get managerUsername => $_getSZ(0);
  @$pb.TagNumber(1)
  set managerUsername($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasManagerUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearManagerUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get managerPassword => $_getSZ(1);
  @$pb.TagNumber(2)
  set managerPassword($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasManagerPassword() => $_has(1);
  @$pb.TagNumber(2)
  void clearManagerPassword() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get deviceName => $_getSZ(2);
  @$pb.TagNumber(3)
  set deviceName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDeviceName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get replaceCounterId => $_getSZ(3);
  @$pb.TagNumber(4)
  set replaceCounterId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReplaceCounterId() => $_has(3);
  @$pb.TagNumber(4)
  void clearReplaceCounterId() => $_clearField(4);
}

/// RegisterDeviceResponse returns the device identity + the one-time secret.
/// The terminal persists device_id + device_secret in flutter_secure_storage;
/// the server keeps only the bcrypt hash of the secret, so it cannot be
/// recovered server-side — losing it means re-registering.
class RegisterDeviceResponse extends $pb.GeneratedMessage {
  factory RegisterDeviceResponse({
    $core.String? deviceId,
    $core.String? deviceSecret,
    $core.String? storeId,
    $core.String? counterId,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (deviceSecret != null) result.deviceSecret = deviceSecret;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    return result;
  }

  RegisterDeviceResponse._();

  factory RegisterDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceSecret')
    ..aOS(3, _omitFieldNames ? '' : 'storeId')
    ..aOS(4, _omitFieldNames ? '' : 'counterId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceResponse clone() =>
      RegisterDeviceResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceResponse copyWith(
          void Function(RegisterDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as RegisterDeviceResponse))
          as RegisterDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceResponse create() => RegisterDeviceResponse._();
  @$core.override
  RegisterDeviceResponse createEmptyInstance() => create();
  static $pb.PbList<RegisterDeviceResponse> createRepeated() =>
      $pb.PbList<RegisterDeviceResponse>();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterDeviceResponse>(create);
  static RegisterDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceSecret => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceSecret($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceSecret() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceSecret() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get storeId => $_getSZ(2);
  @$pb.TagNumber(3)
  set storeId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStoreId() => $_has(2);
  @$pb.TagNumber(3)
  void clearStoreId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get counterId => $_getSZ(3);
  @$pb.TagNumber(4)
  set counterId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCounterId() => $_has(3);
  @$pb.TagNumber(4)
  void clearCounterId() => $_clearField(4);
}

/// LoginRequest pairs the device credential (proves "a provisioned terminal")
/// with the user credential (proves "who is at the till"). Both are checked;
/// failure of either returns the same generic Unauthenticated to prevent
/// device/user enumeration.
class LoginRequest extends $pb.GeneratedMessage {
  factory LoginRequest({
    $core.String? deviceId,
    $core.String? deviceSecret,
    $core.String? username,
    $core.String? password,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (deviceSecret != null) result.deviceSecret = deviceSecret;
    if (username != null) result.username = username;
    if (password != null) result.password = password;
    return result;
  }

  LoginRequest._();

  factory LoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceSecret')
    ..aOS(3, _omitFieldNames ? '' : 'username')
    ..aOS(4, _omitFieldNames ? '' : 'password')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest clone() => LoginRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest copyWith(void Function(LoginRequest) updates) =>
      super.copyWith((message) => updates(message as LoginRequest))
          as LoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginRequest create() => LoginRequest._();
  @$core.override
  LoginRequest createEmptyInstance() => create();
  static $pb.PbList<LoginRequest> createRepeated() =>
      $pb.PbList<LoginRequest>();
  @$core.pragma('dart2js:noInline')
  static LoginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginRequest>(create);
  static LoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceSecret => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceSecret($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceSecret() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceSecret() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get username => $_getSZ(2);
  @$pb.TagNumber(3)
  set username($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsername() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsername() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get password => $_getSZ(3);
  @$pb.TagNumber(4)
  set password($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPassword() => $_has(3);
  @$pb.TagNumber(4)
  void clearPassword() => $_clearField(4);
}

/// LoginResponse carries the session token plus the context the client needs
/// to render (display name, roles) and to label work. Note store_id and
/// counter_id come from the DEVICE record, not from anything the client sent
/// — they, the cashier identity (sub=username), and roles are also embedded
/// as signed claims inside access_token, which is the authoritative copy the
/// server trusts on subsequent calls.
class LoginResponse extends $pb.GeneratedMessage {
  factory LoginResponse({
    $core.String? accessToken,
    $0.Timestamp? expiresAt,
    $core.String? tenantId,
    $core.Iterable<$core.String>? roles,
    $core.String? userDisplayName,
    $core.String? storeId,
    $core.String? counterId,
  }) {
    final result = create();
    if (accessToken != null) result.accessToken = accessToken;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (tenantId != null) result.tenantId = tenantId;
    if (roles != null) result.roles.addAll(roles);
    if (userDisplayName != null) result.userDisplayName = userDisplayName;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    return result;
  }

  LoginResponse._();

  factory LoginResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aOM<$0.Timestamp>(2, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $0.Timestamp.create)
    ..aOS(3, _omitFieldNames ? '' : 'tenantId')
    ..pPS(4, _omitFieldNames ? '' : 'roles')
    ..aOS(5, _omitFieldNames ? '' : 'userDisplayName')
    ..aOS(6, _omitFieldNames ? '' : 'storeId')
    ..aOS(7, _omitFieldNames ? '' : 'counterId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse clone() => LoginResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse copyWith(void Function(LoginResponse) updates) =>
      super.copyWith((message) => updates(message as LoginResponse))
          as LoginResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginResponse create() => LoginResponse._();
  @$core.override
  LoginResponse createEmptyInstance() => create();
  static $pb.PbList<LoginResponse> createRepeated() =>
      $pb.PbList<LoginResponse>();
  @$core.pragma('dart2js:noInline')
  static LoginResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginResponse>(create);
  static LoginResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.Timestamp get expiresAt => $_getN(1);
  @$pb.TagNumber(2)
  set expiresAt($0.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresAt() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.Timestamp ensureExpiresAt() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get tenantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set tenantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTenantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTenantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get roles => $_getList(3);

  /// From users.display_name; falls back to username when unset. Display-only
  /// (e.g. "Logged in as …") — never an identity the server trusts; the
  /// authoritative cashier identity is sub=username inside access_token.
  @$pb.TagNumber(5)
  $core.String get userDisplayName => $_getSZ(4);
  @$pb.TagNumber(5)
  set userDisplayName($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUserDisplayName() => $_has(4);
  @$pb.TagNumber(5)
  void clearUserDisplayName() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get storeId => $_getSZ(5);
  @$pb.TagNumber(6)
  set storeId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStoreId() => $_has(5);
  @$pb.TagNumber(6)
  void clearStoreId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get counterId => $_getSZ(6);
  @$pb.TagNumber(7)
  set counterId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCounterId() => $_has(6);
  @$pb.TagNumber(7)
  void clearCounterId() => $_clearField(7);
}

/// AuthService is the desktop terminal's door into the local store server.
/// See docs/store-server-auth-contract.md for the full design.
///
/// Two auth acts, two tiers of credential:
///   - RegisterDevice (manager/owner-gated): binds a terminal to a
///     server-assigned counter and returns a long-lived, revocable DEVICE
///     credential (an opaque secret; the server stores only its bcrypt hash).
///   - Login (cashier or manager, on a registered device): exchanges the
///     device credential + user credentials for a short-lived SESSION token
///     (HS256 JWT) that rides Authorization: Bearer on every subsequent
///     Connect call and carries who-sold-it + where.
///
/// Both procedures here are UNAUTHENTICATED (the door, not the room): the
/// auth interceptor exempts them. Every OTHER mutating procedure requires a
/// valid session token, and the server derives store_id/counter_id/cashier_id
/// from the verified claims rather than trusting request-body fields.
///
/// Offline-first: this runs entirely against the store server's LOCAL users
/// + devices tables, so login works with the cloud unreachable. Users are
/// mirrored cloud->store (catalog-pull analogue); the store re-authenticates
/// against the local mirror.
///
/// Passwords/secrets cross the wire here. Loopback topology needs no TLS;
/// for a separate-LAN-box, LAN-hop TLS is a separate, deferred concern that
/// does not change this contract.
class AuthServiceApi {
  final $pb.RpcClient _client;

  AuthServiceApi(this._client);

  /// RegisterDevice provisions THIS terminal. Manager authenticates inline;
  /// requires the `owner` role. Returns the device_secret exactly once.
  $async.Future<RegisterDeviceResponse> registerDevice(
          $pb.ClientContext? ctx, RegisterDeviceRequest request) =>
      _client.invoke<RegisterDeviceResponse>(ctx, 'AuthService',
          'RegisterDevice', request, RegisterDeviceResponse());

  /// Login authenticates a user on an already-registered device and mints a
  /// session token. No refresh token by design — re-login at expiry.
  $async.Future<LoginResponse> login(
          $pb.ClientContext? ctx, LoginRequest request) =>
      _client.invoke<LoginResponse>(
          ctx, 'AuthService', 'Login', request, LoginResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
