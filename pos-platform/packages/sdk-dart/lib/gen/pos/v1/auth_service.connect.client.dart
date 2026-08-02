//
//  Generated code. Do not modify.
//  source: pos/v1/auth_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "auth_service.pb.dart" as posv1auth_service;
import "auth_service.connect.spec.dart" as specs;

/// AuthService is the desktop terminal's door into the local store server.
/// See docs/store-server-auth-contract.md for the full design.
/// Two auth acts, two tiers of credential:
///   - RegisterDevice (manager/owner-gated): binds a terminal to a
///     server-assigned counter and returns a long-lived, revocable DEVICE
///     credential (an opaque secret; the server stores only its bcrypt hash).
///   - Login (cashier or manager, on a registered device): exchanges the
///     device credential + user credentials for a short-lived SESSION token
///     (HS256 JWT) that rides Authorization: Bearer on every subsequent
///     Connect call and carries who-sold-it + where.
/// Both procedures here are UNAUTHENTICATED (the door, not the room): the
/// auth interceptor exempts them. Every OTHER mutating procedure requires a
/// valid session token, and the server derives store_id/counter_id/cashier_id
/// from the verified claims rather than trusting request-body fields.
/// Offline-first: this runs entirely against the store server's LOCAL users
/// + devices tables, so login works with the cloud unreachable. Users are
/// mirrored cloud->store (catalog-pull analogue); the store re-authenticates
/// against the local mirror.
/// Passwords/secrets cross the wire here. Loopback topology needs no TLS;
/// for a separate-LAN-box, LAN-hop TLS is a separate, deferred concern that
/// does not change this contract.
extension type AuthServiceClient (connect.Transport _transport) {
  /// RegisterDevice provisions THIS terminal. Manager authenticates inline;
  /// requires the `owner` role. Returns the device_secret exactly once.
  Future<posv1auth_service.RegisterDeviceResponse> registerDevice(
    posv1auth_service.RegisterDeviceRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.AuthService.registerDevice,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Login authenticates a user on an already-registered device and mints a
  /// session token. No refresh token by design — re-login at expiry.
  Future<posv1auth_service.LoginResponse> login(
    posv1auth_service.LoginRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.AuthService.login,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
