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

part 'transport.g.dart';

@Riverpod(keepAlive: true)
connect.Transport transport(TransportRef ref) {
  // dart:io HttpClient → connectrpc HttpClient adapter. HTTP/1.1 is
  // fine for unary Connect calls; we'll revisit when streaming lands.
  final httpClient = conio.createHttpClient(HttpClient());
  return cproto.Transport(
    baseUrl: kLocalServerUrl,
    codec: const cprotobuf.ProtoCodec(),
    httpClient: httpClient,
  );
}
