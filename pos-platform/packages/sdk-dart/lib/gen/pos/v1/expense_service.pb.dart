// This is a generated file - do not edit.
//
// Generated from pos/v1/expense_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Expense is one row in the store expense ledger. id is the primary key
/// (a server-assigned UUID). tenant_id / store_id are pinned from server
/// config on writes (ignored on the wire).
///
/// date is a display-friendly YYYY-MM-DD string — the ledger only needs
/// it for grouping/reporting, not arithmetic. category and payment_mode
/// are free-form operator strings (e.g. "Utilities", "Cash"). amount is
/// the gross spend; vat is the input VAT paid (claimable), which MAY be
/// a zero Money when no VAT applies.
class Expense extends $pb.GeneratedMessage {
  factory Expense({
    $core.String? id,
    $core.String? tenantId,
    $core.String? storeId,
    $core.String? date,
    $core.String? category,
    $core.String? description,
    $core.String? paymentMode,
    $0.Money? amount,
    $0.Money? vat,
    $fixnum.Int64? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (tenantId != null) result.tenantId = tenantId;
    if (storeId != null) result.storeId = storeId;
    if (date != null) result.date = date;
    if (category != null) result.category = category;
    if (description != null) result.description = description;
    if (paymentMode != null) result.paymentMode = paymentMode;
    if (amount != null) result.amount = amount;
    if (vat != null) result.vat = vat;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  Expense._();

  factory Expense.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Expense.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Expense',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'tenantId')
    ..aOS(3, _omitFieldNames ? '' : 'storeId')
    ..aOS(4, _omitFieldNames ? '' : 'date')
    ..aOS(5, _omitFieldNames ? '' : 'category')
    ..aOS(6, _omitFieldNames ? '' : 'description')
    ..aOS(7, _omitFieldNames ? '' : 'paymentMode')
    ..aOM<$0.Money>(8, _omitFieldNames ? '' : 'amount',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(9, _omitFieldNames ? '' : 'vat',
        subBuilder: $0.Money.create)
    ..aInt64(10, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Expense clone() => Expense()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Expense copyWith(void Function(Expense) updates) =>
      super.copyWith((message) => updates(message as Expense)) as Expense;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Expense create() => Expense._();
  @$core.override
  Expense createEmptyInstance() => create();
  static $pb.PbList<Expense> createRepeated() => $pb.PbList<Expense>();
  @$core.pragma('dart2js:noInline')
  static Expense getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Expense>(create);
  static Expense? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tenantId => $_getSZ(1);
  @$pb.TagNumber(2)
  set tenantId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTenantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTenantId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get storeId => $_getSZ(2);
  @$pb.TagNumber(3)
  set storeId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStoreId() => $_has(2);
  @$pb.TagNumber(3)
  void clearStoreId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get date => $_getSZ(3);
  @$pb.TagNumber(4)
  set date($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDate() => $_has(3);
  @$pb.TagNumber(4)
  void clearDate() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get category => $_getSZ(4);
  @$pb.TagNumber(5)
  set category($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCategory() => $_has(4);
  @$pb.TagNumber(5)
  void clearCategory() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get description => $_getSZ(5);
  @$pb.TagNumber(6)
  set description($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearDescription() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get paymentMode => $_getSZ(6);
  @$pb.TagNumber(7)
  set paymentMode($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPaymentMode() => $_has(6);
  @$pb.TagNumber(7)
  void clearPaymentMode() => $_clearField(7);

  @$pb.TagNumber(8)
  $0.Money get amount => $_getN(7);
  @$pb.TagNumber(8)
  set amount($0.Money value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasAmount() => $_has(7);
  @$pb.TagNumber(8)
  void clearAmount() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.Money ensureAmount() => $_ensure(7);

  @$pb.TagNumber(9)
  $0.Money get vat => $_getN(8);
  @$pb.TagNumber(9)
  set vat($0.Money value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasVat() => $_has(8);
  @$pb.TagNumber(9)
  void clearVat() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.Money ensureVat() => $_ensure(8);

  @$pb.TagNumber(10)
  $fixnum.Int64 get createdAt => $_getI64(9);
  @$pb.TagNumber(10)
  set createdAt($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCreatedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearCreatedAt() => $_clearField(10);
}

/// ListExpensesRequest has no pagination — a single store's monthly
/// expense list stays small enough to fetch in one shot. Add a
/// page_token field if/when that stops being true.
class ListExpensesRequest extends $pb.GeneratedMessage {
  factory ListExpensesRequest() => create();

  ListExpensesRequest._();

  factory ListExpensesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListExpensesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListExpensesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListExpensesRequest clone() => ListExpensesRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListExpensesRequest copyWith(void Function(ListExpensesRequest) updates) =>
      super.copyWith((message) => updates(message as ListExpensesRequest))
          as ListExpensesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListExpensesRequest create() => ListExpensesRequest._();
  @$core.override
  ListExpensesRequest createEmptyInstance() => create();
  static $pb.PbList<ListExpensesRequest> createRepeated() =>
      $pb.PbList<ListExpensesRequest>();
  @$core.pragma('dart2js:noInline')
  static ListExpensesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListExpensesRequest>(create);
  static ListExpensesRequest? _defaultInstance;
}

class ListExpensesResponse extends $pb.GeneratedMessage {
  factory ListExpensesResponse({
    $core.Iterable<Expense>? expenses,
  }) {
    final result = create();
    if (expenses != null) result.expenses.addAll(expenses);
    return result;
  }

  ListExpensesResponse._();

  factory ListExpensesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListExpensesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListExpensesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..pc<Expense>(1, _omitFieldNames ? '' : 'expenses', $pb.PbFieldType.PM,
        subBuilder: Expense.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListExpensesResponse clone() =>
      ListExpensesResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListExpensesResponse copyWith(void Function(ListExpensesResponse) updates) =>
      super.copyWith((message) => updates(message as ListExpensesResponse))
          as ListExpensesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListExpensesResponse create() => ListExpensesResponse._();
  @$core.override
  ListExpensesResponse createEmptyInstance() => create();
  static $pb.PbList<ListExpensesResponse> createRepeated() =>
      $pb.PbList<ListExpensesResponse>();
  @$core.pragma('dart2js:noInline')
  static ListExpensesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListExpensesResponse>(create);
  static ListExpensesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Expense> get expenses => $_getList(0);
}

class CreateExpenseRequest extends $pb.GeneratedMessage {
  factory CreateExpenseRequest({
    Expense? expense,
  }) {
    final result = create();
    if (expense != null) result.expense = expense;
    return result;
  }

  CreateExpenseRequest._();

  factory CreateExpenseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateExpenseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateExpenseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Expense>(1, _omitFieldNames ? '' : 'expense',
        subBuilder: Expense.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExpenseRequest clone() =>
      CreateExpenseRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExpenseRequest copyWith(void Function(CreateExpenseRequest) updates) =>
      super.copyWith((message) => updates(message as CreateExpenseRequest))
          as CreateExpenseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateExpenseRequest create() => CreateExpenseRequest._();
  @$core.override
  CreateExpenseRequest createEmptyInstance() => create();
  static $pb.PbList<CreateExpenseRequest> createRepeated() =>
      $pb.PbList<CreateExpenseRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateExpenseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateExpenseRequest>(create);
  static CreateExpenseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Expense get expense => $_getN(0);
  @$pb.TagNumber(1)
  set expense(Expense value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExpense() => $_has(0);
  @$pb.TagNumber(1)
  void clearExpense() => $_clearField(1);
  @$pb.TagNumber(1)
  Expense ensureExpense() => $_ensure(0);
}

class CreateExpenseResponse extends $pb.GeneratedMessage {
  factory CreateExpenseResponse({
    Expense? expense,
  }) {
    final result = create();
    if (expense != null) result.expense = expense;
    return result;
  }

  CreateExpenseResponse._();

  factory CreateExpenseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateExpenseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateExpenseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Expense>(1, _omitFieldNames ? '' : 'expense',
        subBuilder: Expense.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExpenseResponse clone() =>
      CreateExpenseResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExpenseResponse copyWith(
          void Function(CreateExpenseResponse) updates) =>
      super.copyWith((message) => updates(message as CreateExpenseResponse))
          as CreateExpenseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateExpenseResponse create() => CreateExpenseResponse._();
  @$core.override
  CreateExpenseResponse createEmptyInstance() => create();
  static $pb.PbList<CreateExpenseResponse> createRepeated() =>
      $pb.PbList<CreateExpenseResponse>();
  @$core.pragma('dart2js:noInline')
  static CreateExpenseResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateExpenseResponse>(create);
  static CreateExpenseResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Expense get expense => $_getN(0);
  @$pb.TagNumber(1)
  set expense(Expense value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExpense() => $_has(0);
  @$pb.TagNumber(1)
  void clearExpense() => $_clearField(1);
  @$pb.TagNumber(1)
  Expense ensureExpense() => $_ensure(0);
}

/// ExpenseService is the operator-facing expense ledger surface. The
/// desktop client lists store expenses (rent, utilities, salaries, …) to
/// render the Expenses screen, and can record a new expense.
///
/// Like ItemService and TaxAdminService, expense writes are NOT sync
/// events — they mutate the local store ledger directly. A cloud-side GL
/// projection may consume them later; until then, CreateExpense (and
/// cmd/seed-demo) are the only seed paths.
class ExpenseServiceApi {
  final $pb.RpcClient _client;

  ExpenseServiceApi(this._client);

  $async.Future<ListExpensesResponse> listExpenses(
          $pb.ClientContext? ctx, ListExpensesRequest request) =>
      _client.invoke<ListExpensesResponse>(ctx, 'ExpenseService',
          'ListExpenses', request, ListExpensesResponse());
  $async.Future<CreateExpenseResponse> createExpense(
          $pb.ClientContext? ctx, CreateExpenseRequest request) =>
      _client.invoke<CreateExpenseResponse>(ctx, 'ExpenseService',
          'CreateExpense', request, CreateExpenseResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
