/// Shared exception types for cloud-api reports calls.
///
/// Lifted out of today_repository.dart so browse/stores can throw the
/// same types — the UI's _ErrorBody only needs to recognise one auth
/// sentinel regardless of which screen the call came from.
library;

class AuthException implements Exception {
  final int status;
  AuthException(this.status);
  @override
  String toString() => 'AuthException($status): owner login required';
}

class ReportException implements Exception {
  final int status;
  final String body;
  ReportException(this.status, this.body);
  @override
  String toString() => 'ReportException($status): $body';
}
