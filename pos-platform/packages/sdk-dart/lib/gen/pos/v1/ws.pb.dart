// This is a generated file - do not edit.
//
// Generated from pos/v1/ws.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../google/protobuf/timestamp.pb.dart' as $0;
import 'common.pb.dart' as $2;
import 'events.pb.dart' as $1;
import 'ws.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'ws.pbenum.dart';

enum WsMessage_Body {
  hello,
  subscribe,
  event,
  inventory,
  cart,
  heartbeat,
  goodbye,
  notSet
}

/// WsMessage — every websocket frame between local-store-server and POS clients
/// is one of these. Using a single envelope avoids ad-hoc framing.
class WsMessage extends $pb.GeneratedMessage {
  factory WsMessage({
    $core.String? messageId,
    $0.Timestamp? sentAt,
    Hello? hello,
    Subscribe? subscribe,
    $1.EventEnvelope? event,
    InventoryUpdate? inventory,
    CartUpdate? cart,
    Heartbeat? heartbeat,
    Goodbye? goodbye,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    if (sentAt != null) result.sentAt = sentAt;
    if (hello != null) result.hello = hello;
    if (subscribe != null) result.subscribe = subscribe;
    if (event != null) result.event = event;
    if (inventory != null) result.inventory = inventory;
    if (cart != null) result.cart = cart;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (goodbye != null) result.goodbye = goodbye;
    return result;
  }

  WsMessage._();

  factory WsMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WsMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, WsMessage_Body> _WsMessage_BodyByTag = {
    10: WsMessage_Body.hello,
    11: WsMessage_Body.subscribe,
    12: WsMessage_Body.event,
    13: WsMessage_Body.inventory,
    14: WsMessage_Body.cart,
    15: WsMessage_Body.heartbeat,
    16: WsMessage_Body.goodbye,
    0: WsMessage_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WsMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16])
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOM<$0.Timestamp>(2, _omitFieldNames ? '' : 'sentAt',
        subBuilder: $0.Timestamp.create)
    ..aOM<Hello>(10, _omitFieldNames ? '' : 'hello', subBuilder: Hello.create)
    ..aOM<Subscribe>(11, _omitFieldNames ? '' : 'subscribe',
        subBuilder: Subscribe.create)
    ..aOM<$1.EventEnvelope>(12, _omitFieldNames ? '' : 'event',
        subBuilder: $1.EventEnvelope.create)
    ..aOM<InventoryUpdate>(13, _omitFieldNames ? '' : 'inventory',
        subBuilder: InventoryUpdate.create)
    ..aOM<CartUpdate>(14, _omitFieldNames ? '' : 'cart',
        subBuilder: CartUpdate.create)
    ..aOM<Heartbeat>(15, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: Heartbeat.create)
    ..aOM<Goodbye>(16, _omitFieldNames ? '' : 'goodbye',
        subBuilder: Goodbye.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WsMessage clone() => WsMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WsMessage copyWith(void Function(WsMessage) updates) =>
      super.copyWith((message) => updates(message as WsMessage)) as WsMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WsMessage create() => WsMessage._();
  @$core.override
  WsMessage createEmptyInstance() => create();
  static $pb.PbList<WsMessage> createRepeated() => $pb.PbList<WsMessage>();
  @$core.pragma('dart2js:noInline')
  static WsMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WsMessage>(create);
  static WsMessage? _defaultInstance;

  WsMessage_Body whichBody() => _WsMessage_BodyByTag[$_whichOneof(0)]!;
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.Timestamp get sentAt => $_getN(1);
  @$pb.TagNumber(2)
  set sentAt($0.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSentAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearSentAt() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.Timestamp ensureSentAt() => $_ensure(1);

  @$pb.TagNumber(10)
  Hello get hello => $_getN(2);
  @$pb.TagNumber(10)
  set hello(Hello value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasHello() => $_has(2);
  @$pb.TagNumber(10)
  void clearHello() => $_clearField(10);
  @$pb.TagNumber(10)
  Hello ensureHello() => $_ensure(2);

  @$pb.TagNumber(11)
  Subscribe get subscribe => $_getN(3);
  @$pb.TagNumber(11)
  set subscribe(Subscribe value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSubscribe() => $_has(3);
  @$pb.TagNumber(11)
  void clearSubscribe() => $_clearField(11);
  @$pb.TagNumber(11)
  Subscribe ensureSubscribe() => $_ensure(3);

  @$pb.TagNumber(12)
  $1.EventEnvelope get event => $_getN(4);
  @$pb.TagNumber(12)
  set event($1.EventEnvelope value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasEvent() => $_has(4);
  @$pb.TagNumber(12)
  void clearEvent() => $_clearField(12);
  @$pb.TagNumber(12)
  $1.EventEnvelope ensureEvent() => $_ensure(4);

  @$pb.TagNumber(13)
  InventoryUpdate get inventory => $_getN(5);
  @$pb.TagNumber(13)
  set inventory(InventoryUpdate value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasInventory() => $_has(5);
  @$pb.TagNumber(13)
  void clearInventory() => $_clearField(13);
  @$pb.TagNumber(13)
  InventoryUpdate ensureInventory() => $_ensure(5);

  @$pb.TagNumber(14)
  CartUpdate get cart => $_getN(6);
  @$pb.TagNumber(14)
  set cart(CartUpdate value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCart() => $_has(6);
  @$pb.TagNumber(14)
  void clearCart() => $_clearField(14);
  @$pb.TagNumber(14)
  CartUpdate ensureCart() => $_ensure(6);

  @$pb.TagNumber(15)
  Heartbeat get heartbeat => $_getN(7);
  @$pb.TagNumber(15)
  set heartbeat(Heartbeat value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasHeartbeat() => $_has(7);
  @$pb.TagNumber(15)
  void clearHeartbeat() => $_clearField(15);
  @$pb.TagNumber(15)
  Heartbeat ensureHeartbeat() => $_ensure(7);

  @$pb.TagNumber(16)
  Goodbye get goodbye => $_getN(8);
  @$pb.TagNumber(16)
  set goodbye(Goodbye value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasGoodbye() => $_has(8);
  @$pb.TagNumber(16)
  void clearGoodbye() => $_clearField(16);
  @$pb.TagNumber(16)
  Goodbye ensureGoodbye() => $_ensure(8);
}

/// Hello — client → server on connect. Includes resume cursor for replay.
class Hello extends $pb.GeneratedMessage {
  factory Hello({
    $2.CounterId? counterId,
    $2.UserId? userId,
    $core.String? lastSeenMessageId,
  }) {
    final result = create();
    if (counterId != null) result.counterId = counterId;
    if (userId != null) result.userId = userId;
    if (lastSeenMessageId != null) result.lastSeenMessageId = lastSeenMessageId;
    return result;
  }

  Hello._();

  factory Hello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Hello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Hello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<$2.CounterId>(1, _omitFieldNames ? '' : 'counterId',
        subBuilder: $2.CounterId.create)
    ..aOM<$2.UserId>(2, _omitFieldNames ? '' : 'userId',
        subBuilder: $2.UserId.create)
    ..aOS(3, _omitFieldNames ? '' : 'lastSeenMessageId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello clone() => Hello()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Hello copyWith(void Function(Hello) updates) =>
      super.copyWith((message) => updates(message as Hello)) as Hello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Hello create() => Hello._();
  @$core.override
  Hello createEmptyInstance() => create();
  static $pb.PbList<Hello> createRepeated() => $pb.PbList<Hello>();
  @$core.pragma('dart2js:noInline')
  static Hello getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Hello>(create);
  static Hello? _defaultInstance;

  @$pb.TagNumber(1)
  $2.CounterId get counterId => $_getN(0);
  @$pb.TagNumber(1)
  set counterId($2.CounterId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCounterId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCounterId() => $_clearField(1);
  @$pb.TagNumber(1)
  $2.CounterId ensureCounterId() => $_ensure(0);

  @$pb.TagNumber(2)
  $2.UserId get userId => $_getN(1);
  @$pb.TagNumber(2)
  set userId($2.UserId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.UserId ensureUserId() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get lastSeenMessageId => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastSeenMessageId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastSeenMessageId() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastSeenMessageId() => $_clearField(3);
}

/// Subscribe — coarse-grained topic subscription (e.g. "inventory", "cart").
class Subscribe extends $pb.GeneratedMessage {
  factory Subscribe({
    $core.Iterable<$core.String>? topics,
  }) {
    final result = create();
    if (topics != null) result.topics.addAll(topics);
    return result;
  }

  Subscribe._();

  factory Subscribe.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Subscribe.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Subscribe',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'topics')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscribe clone() => Subscribe()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscribe copyWith(void Function(Subscribe) updates) =>
      super.copyWith((message) => updates(message as Subscribe)) as Subscribe;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Subscribe create() => Subscribe._();
  @$core.override
  Subscribe createEmptyInstance() => create();
  static $pb.PbList<Subscribe> createRepeated() => $pb.PbList<Subscribe>();
  @$core.pragma('dart2js:noInline')
  static Subscribe getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Subscribe>(create);
  static Subscribe? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get topics => $_getList(0);
}

/// InventoryUpdate — broadcast when stock for a SKU changes at this store.
/// Carries the new derived quantity so clients don't have to replay all events.
class InventoryUpdate extends $pb.GeneratedMessage {
  factory InventoryUpdate({
    $core.String? sku,
    $fixnum.Int64? quantityOnHand,
    $0.Timestamp? asOf,
  }) {
    final result = create();
    if (sku != null) result.sku = sku;
    if (quantityOnHand != null) result.quantityOnHand = quantityOnHand;
    if (asOf != null) result.asOf = asOf;
    return result;
  }

  InventoryUpdate._();

  factory InventoryUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InventoryUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InventoryUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sku')
    ..aInt64(2, _omitFieldNames ? '' : 'quantityOnHand')
    ..aOM<$0.Timestamp>(3, _omitFieldNames ? '' : 'asOf',
        subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InventoryUpdate clone() => InventoryUpdate()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InventoryUpdate copyWith(void Function(InventoryUpdate) updates) =>
      super.copyWith((message) => updates(message as InventoryUpdate))
          as InventoryUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InventoryUpdate create() => InventoryUpdate._();
  @$core.override
  InventoryUpdate createEmptyInstance() => create();
  static $pb.PbList<InventoryUpdate> createRepeated() =>
      $pb.PbList<InventoryUpdate>();
  @$core.pragma('dart2js:noInline')
  static InventoryUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InventoryUpdate>(create);
  static InventoryUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sku => $_getSZ(0);
  @$pb.TagNumber(1)
  set sku($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSku() => $_has(0);
  @$pb.TagNumber(1)
  void clearSku() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get quantityOnHand => $_getI64(1);
  @$pb.TagNumber(2)
  set quantityOnHand($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuantityOnHand() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuantityOnHand() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Timestamp get asOf => $_getN(2);
  @$pb.TagNumber(3)
  set asOf($0.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAsOf() => $_has(2);
  @$pb.TagNumber(3)
  void clearAsOf() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Timestamp ensureAsOf() => $_ensure(2);
}

/// CartUpdate — for "live cart" multi-counter visibility (Phase 4).
class CartUpdate extends $pb.GeneratedMessage {
  factory CartUpdate({
    $core.String? cartId,
    $2.CounterId? counterId,
    CartUpdate_State? state,
    $core.int? lineCount,
  }) {
    final result = create();
    if (cartId != null) result.cartId = cartId;
    if (counterId != null) result.counterId = counterId;
    if (state != null) result.state = state;
    if (lineCount != null) result.lineCount = lineCount;
    return result;
  }

  CartUpdate._();

  factory CartUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CartUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CartUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cartId')
    ..aOM<$2.CounterId>(2, _omitFieldNames ? '' : 'counterId',
        subBuilder: $2.CounterId.create)
    ..e<CartUpdate_State>(3, _omitFieldNames ? '' : 'state', $pb.PbFieldType.OE,
        defaultOrMaker: CartUpdate_State.STATE_UNSPECIFIED,
        valueOf: CartUpdate_State.valueOf,
        enumValues: CartUpdate_State.values)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'lineCount', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CartUpdate clone() => CartUpdate()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CartUpdate copyWith(void Function(CartUpdate) updates) =>
      super.copyWith((message) => updates(message as CartUpdate)) as CartUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CartUpdate create() => CartUpdate._();
  @$core.override
  CartUpdate createEmptyInstance() => create();
  static $pb.PbList<CartUpdate> createRepeated() => $pb.PbList<CartUpdate>();
  @$core.pragma('dart2js:noInline')
  static CartUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CartUpdate>(create);
  static CartUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get cartId => $_getSZ(0);
  @$pb.TagNumber(1)
  set cartId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCartId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCartId() => $_clearField(1);

  @$pb.TagNumber(2)
  $2.CounterId get counterId => $_getN(1);
  @$pb.TagNumber(2)
  set counterId($2.CounterId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCounterId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCounterId() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.CounterId ensureCounterId() => $_ensure(1);

  @$pb.TagNumber(3)
  CartUpdate_State get state => $_getN(2);
  @$pb.TagNumber(3)
  set state(CartUpdate_State value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get lineCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set lineCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLineCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearLineCount() => $_clearField(4);
}

class Heartbeat extends $pb.GeneratedMessage {
  factory Heartbeat({
    $fixnum.Int64? seq,
  }) {
    final result = create();
    if (seq != null) result.seq = seq;
    return result;
  }

  Heartbeat._();

  factory Heartbeat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Heartbeat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Heartbeat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'seq', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat clone() => Heartbeat()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat copyWith(void Function(Heartbeat) updates) =>
      super.copyWith((message) => updates(message as Heartbeat)) as Heartbeat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Heartbeat create() => Heartbeat._();
  @$core.override
  Heartbeat createEmptyInstance() => create();
  static $pb.PbList<Heartbeat> createRepeated() => $pb.PbList<Heartbeat>();
  @$core.pragma('dart2js:noInline')
  static Heartbeat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Heartbeat>(create);
  static Heartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seq => $_getI64(0);
  @$pb.TagNumber(1)
  set seq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeq() => $_clearField(1);
}

class Goodbye extends $pb.GeneratedMessage {
  factory Goodbye({
    $core.String? reason,
  }) {
    final result = create();
    if (reason != null) result.reason = reason;
    return result;
  }

  Goodbye._();

  factory Goodbye.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Goodbye.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Goodbye',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Goodbye clone() => Goodbye()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Goodbye copyWith(void Function(Goodbye) updates) =>
      super.copyWith((message) => updates(message as Goodbye)) as Goodbye;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Goodbye create() => Goodbye._();
  @$core.override
  Goodbye createEmptyInstance() => create();
  static $pb.PbList<Goodbye> createRepeated() => $pb.PbList<Goodbye>();
  @$core.pragma('dart2js:noInline')
  static Goodbye getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Goodbye>(create);
  static Goodbye? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
