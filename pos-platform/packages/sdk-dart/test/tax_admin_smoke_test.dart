/// Manual smoke test for the Connect-Dart bindings against a running
/// local-store-server.
///
/// This is intentionally NOT an automated unit test:
///   - It hits the real Go binary over HTTP/Connect on the loopback
///     socket, so it requires an external process to be running.
///   - CI runs without `POS_LOCAL_URL` set and skips this test entirely.
///
/// How to run locally:
///   1. Start the server:
///        cd apps/local-store-server && go run .
///      (defaults to 127.0.0.1:8081, tenant-A, node-local)
///   2. Run the smoke test:
///        cd packages/sdk-dart && \
///        POS_LOCAL_URL=http://127.0.0.1:8081 dart test
///
/// What it asserts:
///   - GetTaxCategory with a random unknown UUID returns
///     ConnectException(code: notFound). That single round-trip exercises
///     the full client stack: codegen → ProtoCodec → connect transport
///     → Go handler → tax store → error mapping back through the wire.
///
/// If this passes, the generated bindings are wire-compatible with the
/// server's Connect surface. We don't need broader Dart-side coverage
/// here because api_test.go already validates server behavior; this
/// test only catches generator/runtime drift.

import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/io.dart' as conio;
import 'package:connectrpc/protobuf.dart' as cprotobuf;
import 'package:connectrpc/protocol/connect.dart' as cproto;
import 'package:pos_sdk/gen/pos/v1/tax_admin_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/tax_admin_service.pb.dart';
import 'package:test/test.dart';

void main() {
  final baseUrl = Platform.environment['POS_LOCAL_URL'];

  test(
    'GetTaxCategory unknown id -> notFound',
    () async {
      final transport = cproto.Transport(
        baseUrl: baseUrl!,
        codec: const cprotobuf.ProtoCodec(),
        httpClient: conio.createHttpClient(HttpClient()),
      );
      final client = TaxAdminServiceClient(transport);

      // Random UUID that no operator would ever seed.
      final req = GetTaxCategoryRequest(
        id: '00000000-0000-0000-0000-deadbeefcafe',
      );

      await expectLater(
        () => client.getTaxCategory(req),
        throwsA(
          isA<connect.ConnectException>().having(
            (e) => e.code,
            'code',
            connect.Code.notFound,
          ),
        ),
      );
    },
    skip: baseUrl == null
        ? 'set POS_LOCAL_URL=http://127.0.0.1:8081 (with a running server) to run'
        : false,
  );
}
