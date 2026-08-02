/// Data layer — AuthService repository (docs/store-server-auth-contract.md).
///
/// Hides the generated AuthServiceClient + request/response proto behind a
/// domain surface, same boundary policy as SaleRepository: controllers and
/// the session controller depend on [AuthRepository] + the plain [Session] /
/// [DeviceCredential] types, never on the connect client.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:pos_sdk/gen/pos/v1/auth_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/auth_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/transport.dart';

part 'auth_repository.g.dart';

/// A registered terminal's long-lived credential (tier 1 of the two-tier
/// auth model). Minted once by RegisterDevice, persisted in secure storage,
/// and presented on every Login. Round-trips to JSON for storage.
@immutable
class DeviceCredential {
  const DeviceCredential({
    required this.deviceId,
    required this.deviceSecret,
    required this.storeId,
    required this.counterId,
  });

  final String deviceId;
  final String deviceSecret;
  final String storeId;
  final String counterId;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceSecret': deviceSecret,
        'storeId': storeId,
        'counterId': counterId,
      };

  factory DeviceCredential.fromJson(Map<String, dynamic> j) => DeviceCredential(
        deviceId: j['deviceId'] as String,
        deviceSecret: j['deviceSecret'] as String,
        storeId: j['storeId'] as String,
        counterId: j['counterId'] as String,
      );
}

/// An authenticated cashier session (tier 2). Carries the short-lived
/// access token plus the identity the UI renders and sales are stamped
/// with. Round-trips to JSON for storage so a relaunch resumes until expiry.
@immutable
class Session {
  const Session({
    required this.username,
    required this.displayName,
    required this.roles,
    required this.token,
    required this.expiresAt,
    required this.tenantId,
    required this.storeId,
    required this.counterId,
  });

  final String username; // JWT sub — the cashier identity on sales
  final String displayName;
  final List<String> roles;
  final String token;
  final DateTime expiresAt;
  final String tenantId;
  final String storeId;
  final String counterId;

  bool hasRole(String role) => roles.contains(role);

  /// now() is fine here — expiry is a wall-clock concept and a few seconds
  /// of skew only costs an extra re-login.
  bool get isExpired => !DateTime.now().isBefore(expiresAt);

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'roles': roles,
        'token': token,
        'expiresAt': expiresAt.toIso8601String(),
        'tenantId': tenantId,
        'storeId': storeId,
        'counterId': counterId,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        username: j['username'] as String,
        displayName: j['displayName'] as String,
        roles: (j['roles'] as List).cast<String>(),
        token: j['token'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        tenantId: j['tenantId'] as String,
        storeId: j['storeId'] as String,
        counterId: j['counterId'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.username == username &&
      other.token == token &&
      other.expiresAt == expiresAt &&
      listEquals(other.roles, roles);

  @override
  int get hashCode => Object.hash(username, token, expiresAt);
}

/// The auth data-access surface. Both procedures are unauthenticated on the
/// server (the door); the session token they yield gates everything else.
abstract class AuthRepository {
  /// Manager-gated device registration. [replaceCounterId] re-provisions an
  /// existing counter (till swap); null/empty assigns a new one.
  Future<DeviceCredential> registerDevice({
    required String managerUsername,
    required String managerPassword,
    required String deviceName,
    String? replaceCounterId,
  });

  /// Cashier login on a registered device → a session token.
  Future<Session> login({
    required String deviceId,
    required String deviceSecret,
    required String username,
    required String password,
  });
}

class ConnectAuthRepository implements AuthRepository {
  ConnectAuthRepository(this._transport);

  final connect.Transport _transport;

  @override
  Future<DeviceCredential> registerDevice({
    required String managerUsername,
    required String managerPassword,
    required String deviceName,
    String? replaceCounterId,
  }) async {
    final client = AuthServiceClient(_transport);
    final resp = await client.registerDevice(RegisterDeviceRequest(
      managerUsername: managerUsername,
      managerPassword: managerPassword,
      deviceName: deviceName,
      replaceCounterId: replaceCounterId ?? '',
    ));
    return DeviceCredential(
      deviceId: resp.deviceId,
      deviceSecret: resp.deviceSecret,
      storeId: resp.storeId,
      counterId: resp.counterId,
    );
  }

  @override
  Future<Session> login({
    required String deviceId,
    required String deviceSecret,
    required String username,
    required String password,
  }) async {
    final client = AuthServiceClient(_transport);
    final resp = await client.login(LoginRequest(
      deviceId: deviceId,
      deviceSecret: deviceSecret,
      username: username,
      password: password,
    ));
    return Session(
      username: username, // the server echoes display/roles, not the sub
      displayName: resp.userDisplayName,
      roles: resp.roles.toList(growable: false),
      token: resp.accessToken,
      expiresAt: resp.expiresAt.toDateTime(),
      tenantId: resp.tenantId,
      storeId: resp.storeId,
      counterId: resp.counterId,
    );
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) =>
    ConnectAuthRepository(ref.watch(transportProvider));
