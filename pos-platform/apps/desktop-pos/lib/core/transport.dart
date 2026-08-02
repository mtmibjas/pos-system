/// Connect-RPC transport plumbing.
///
/// One [connect.Transport] is built per app process and shared across
/// every generated service client (TaxAdminServiceClient,
/// SaleServiceClient, future ItemServiceClient, …). Service clients
/// themselves are cheap extension types — instantiate per-call from
/// the shared transport.
///
/// Tests inject a fake transport by overriding [transportProvider]
/// at the ProviderScope boundary (see test/smoke_controller_test.dart).
library;

import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/io.dart' as conio;
import 'package:connectrpc/protobuf.dart' as cprotobuf;
import 'package:connectrpc/protocol/connect.dart' as cproto;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config.dart';
import '../domain/connection_health.dart';
import 'connection_health_provider.dart';
import 'rpc_policy.dart';

part 'transport.g.dart';

@Riverpod(keepAlive: true)
connect.Transport transport(TransportRef ref) {
  // Server URL comes from the config seam (config.dart) so provisioning can
  // later swap it without touching this provider.
  final cfg = ref.watch(terminalConfigProvider);
  // dart:io HttpClient → connectrpc HttpClient adapter. HTTP/1.1 is
  // fine for unary Connect calls; we'll revisit when streaming lands.
  final httpClient = conio.createHttpClient(HttpClient());

  // Feed every unary call's outcome into the health aggregator. Read the
  // notifier LAZILY (inside the callbacks) so merely building the transport
  // doesn't spin up the health provider/probe — it starts on first RPC.
  final reporter = ConnectionReporter(
    onSuccess: () =>
        ref.read(connectionHealthControllerProvider.notifier).recordSuccess(),
    onFailure: (FailureKind kind, String summary) => ref
        .read(connectionHealthControllerProvider.notifier)
        .recordFailure(kind, summary),
  );

  return cproto.Transport(
    baseUrl: cfg.serverUrl,
    codec: const cprotobuf.ProtoCodec(),
    httpClient: httpClient,
    interceptors: [resilienceInterceptor(reporter)],
  );
}
