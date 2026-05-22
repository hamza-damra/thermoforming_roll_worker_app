import 'dart:convert';

import '../domain/entities/operator_dashboard_event.dart';

/// Raw `event:` + `data:` pair extracted from the SSE byte stream.
///
/// One [RawSseEvent] is dispatched per blank-line terminated record. The
/// frame parser converts `data` (when it's a valid JSON object) into a
/// typed [OperatorDashboardEvent].
class RawSseEvent {
  const RawSseEvent({required this.name, required this.data});

  /// `event:` field value, or `null` when the server omitted the line.
  final String? name;

  /// Concatenated `data:` field value. Empty string when no `data:` line
  /// was present in the record.
  final String data;
}

/// Streaming parser for the text/event-stream wire format defined by the
/// HTML5 EventSource spec — used by the operator-dashboard SSE channel.
///
/// Rules implemented (the only ones the backend uses):
///   - Lines are separated by `\n` (any preceding `\r` is stripped).
///   - A line starting with `:` is a comment / heartbeat — ignored.
///   - A line of the form `field: value` (or `field:value`) splits on the
///     first colon; a leading space in the value is stripped per spec.
///   - `event: name` sets the event name for the in-flight record.
///   - `data: text` appends to the in-flight data buffer (with `\n`
///     separator on subsequent `data:` lines per spec).
///   - A blank line dispatches the in-flight record and resets the buffers.
///
/// `id:` and `retry:` are accepted but ignored — the broker assigns its
/// own `eventId` inside the JSON payload, and reconnect cadence is the
/// client's responsibility (handoff §6).
class SseFrameParser {
  SseFrameParser();

  String _eventName = '';
  final StringBuffer _dataBuffer = StringBuffer();
  bool _hasData = false;

  /// Carry-over for the latest partial line (no terminating `\n` yet).
  String _residual = '';

  /// Feeds a chunk of UTF-8 decoded text into the parser and emits any
  /// records completed by this chunk. The parser remains stateful across
  /// calls so multi-chunk records are reassembled correctly.
  Iterable<RawSseEvent> feed(String chunk) sync* {
    final String combined = _residual + chunk;
    final List<String> parts = combined.split('\n');
    _residual = parts.removeLast();
    for (final String raw in parts) {
      final String line = raw.endsWith('\r')
          ? raw.substring(0, raw.length - 1)
          : raw;
      if (line.isEmpty) {
        final RawSseEvent? event = _flush();
        if (event != null) yield event;
        continue;
      }
      if (line.startsWith(':')) {
        // Heartbeat / comment — server keeps the connection warm with these.
        continue;
      }
      final int colon = line.indexOf(':');
      final String field;
      final String value;
      if (colon < 0) {
        field = line;
        value = '';
      } else {
        field = line.substring(0, colon);
        final String rawValue = line.substring(colon + 1);
        value = rawValue.startsWith(' ') ? rawValue.substring(1) : rawValue;
      }
      _ingest(field, value);
    }
  }

  /// Flushes any final residual (called when the upstream stream closes).
  /// Returns a record only if the trailing line completes one.
  RawSseEvent? finish() {
    if (_residual.isEmpty) return _flush();
    // Treat the dangling residual as a complete line so a record without
    // a terminating newline still dispatches at end-of-stream.
    final String line = _residual;
    _residual = '';
    if (line.isEmpty) return _flush();
    if (!line.startsWith(':')) {
      final int colon = line.indexOf(':');
      final String field;
      final String value;
      if (colon < 0) {
        field = line;
        value = '';
      } else {
        field = line.substring(0, colon);
        final String rawValue = line.substring(colon + 1);
        value = rawValue.startsWith(' ') ? rawValue.substring(1) : rawValue;
      }
      _ingest(field, value);
    }
    return _flush();
  }

  void _ingest(String field, String value) {
    switch (field) {
      case 'event':
        _eventName = value;
      case 'data':
        if (_hasData) {
          _dataBuffer.write('\n');
        }
        _dataBuffer.write(value);
        _hasData = true;
      case 'id':
      case 'retry':
        // Ignored — see class docs.
        break;
    }
  }

  RawSseEvent? _flush() {
    if (_eventName.isEmpty && !_hasData) return null;
    final RawSseEvent event = RawSseEvent(
      name: _eventName.isEmpty ? null : _eventName,
      data: _dataBuffer.toString(),
    );
    _eventName = '';
    _dataBuffer.clear();
    _hasData = false;
    return event;
  }
}

/// Translates a [RawSseEvent] whose JSON `data` body conforms to the
/// operator-dashboard frame schema (handoff §2/§3) into a typed
/// [OperatorDashboardEvent].
///
/// Returns `null` when:
///   - the event name is not `operator-dashboard-changed`, OR
///   - the JSON body is missing required wrapping fields
///     (`lineId`, `reason`).
///
/// When the wrapping is valid but `data` is absent or fails strict
/// payload parsing, the returned event still has its wrapping fields set
/// but [OperatorDashboardEvent.payload] is `null` so callers can fall
/// back to a REST refetch (handoff §7).
class OperatorDashboardFrameParser {
  OperatorDashboardFrameParser._();

  static const String eventName = 'operator-dashboard-changed';
  static const String handshakeName = 'connected';

  /// Returns null when the event is irrelevant (handshake, comment,
  /// unknown name). The handshake event is detected separately via
  /// [isHandshake] before calling this helper.
  static OperatorDashboardEvent? parse(RawSseEvent raw) {
    if (raw.name != eventName) return null;
    final Object? decoded = _safeJsonDecode(raw.data);
    if (decoded is! Map<String, dynamic>) return null;

    final Object? lineIdRaw = decoded['lineId'];
    if (lineIdRaw is! num) return null;
    final int lineId = lineIdRaw.toInt();

    final String? reasonWire = decoded['reason'] is String
        ? decoded['reason'] as String
        : null;
    if (reasonWire == null) return null;
    final OperatorDashboardReason reason = OperatorDashboardReason.fromWire(
      reasonWire,
    );

    final List<String> affected = _readAffected(decoded['affected']);
    final int? version = decoded['version'] is num
        ? (decoded['version'] as num).toInt()
        : null;
    final String? eventId = decoded['eventId'] is String
        ? decoded['eventId'] as String
        : null;
    final DateTime? occurredAt = decoded['occurredAt'] is String
        ? DateTime.tryParse(decoded['occurredAt'] as String)
        : null;

    final Object? data = decoded['data'];
    final OperatorDashboardPayload? payload = data is Map<String, dynamic>
        ? _parsePayload(reason, data)
        : null;

    return OperatorDashboardEvent(
      lineId: lineId,
      reason: reason,
      affected: affected,
      version: version,
      eventId: eventId,
      occurredAt: occurredAt,
      payload: payload,
    );
  }

  static bool isHandshake(RawSseEvent raw) => raw.name == handshakeName;

  static Object? _safeJsonDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static List<String> _readAffected(Object? raw) {
    if (raw is! List) return const <String>[];
    return <String>[
      for (final Object? entry in raw)
        if (entry is String) entry,
    ];
  }

  static OperatorDashboardPayload? _parsePayload(
    OperatorDashboardReason reason,
    Map<String, dynamic> data,
  ) {
    switch (reason) {
      case OperatorDashboardReason.productChanged:
        return _parseProductChanged(data);
      case OperatorDashboardReason.rollConsumptionSegmentRecorded:
        return _parseSegmentRecorded(data);
      case OperatorDashboardReason.rollContinuedWithNewProduct:
        return _parseRollContinued(data);
      case OperatorDashboardReason.rollReturnedRemaining:
        return _parseRollReturnedRemaining(data);
      case OperatorDashboardReason.machineRollStateUpdated:
        return _parseMachineRollState(data);
      // Takeover / line-state events carry no typed payload — returning null
      // routes them through the notification-only path so the sync controller
      // refetches the REST summary (which owns the takeover state).
      case OperatorDashboardReason.lineTakeoverRequested:
      case OperatorDashboardReason.lineTakeoverAccepted:
      case OperatorDashboardReason.lineTakeoverRejected:
      case OperatorDashboardReason.lineTakeoverTimeoutAutoReleased:
      case OperatorDashboardReason.lineTakeoverPostAcceptTimeoutAutoReleased:
      case OperatorDashboardReason.lineTakeoverCompleted:
      case OperatorDashboardReason.lineStateChanged:
      case OperatorDashboardReason.rollsEmployeeChanged:
      case OperatorDashboardReason.palletizingEmployeeChanged:
      case OperatorDashboardReason.unknown:
        return null;
    }
  }

  static ProductChangedPayload? _parseProductChanged(Map<String, dynamic> d) {
    final int? machineId = _asInt(d['machineId']);
    final int? newProductId = _asInt(d['newProductId']);
    final String? newProductName = _asString(d['newProductName']);
    if (machineId == null ||
        newProductId == null ||
        newProductName == null ||
        newProductName.isEmpty) {
      return null;
    }
    return ProductChangedPayload(
      machineId: machineId,
      newProductId: newProductId,
      newProductName: newProductName,
      oldProductId: _asInt(d['oldProductId']),
      oldProductName: _asString(d['oldProductName']),
      changedBy: _asInt(d['changedBy']),
      currentRollId: _asInt(d['currentRollId']),
      compatibilityResult: _asString(d['compatibilityResult']),
    );
  }

  static RollConsumptionSegmentRecordedPayload? _parseSegmentRecorded(
    Map<String, dynamic> d,
  ) {
    final int? machineId = _asInt(d['machineId']);
    final int? rollId = _asInt(d['rollId']);
    final int? productId = _asInt(d['productId']);
    final String? productName = _asString(d['productName']);
    final double? previousWeight = _asDouble(d['previousWeight']);
    final double? currentWeight = _asDouble(d['currentWeight']);
    final double? consumedWeight = _asDouble(d['consumedWeight']);
    if (machineId == null ||
        rollId == null ||
        productId == null ||
        productName == null ||
        previousWeight == null ||
        currentWeight == null ||
        consumedWeight == null) {
      return null;
    }
    return RollConsumptionSegmentRecordedPayload(
      machineId: machineId,
      rollId: rollId,
      productId: productId,
      productName: productName,
      previousWeight: previousWeight,
      currentWeight: currentWeight,
      consumedWeight: consumedWeight,
    );
  }

  static RollContinuedWithNewProductPayload? _parseRollContinued(
    Map<String, dynamic> d,
  ) {
    final int? machineId = _asInt(d['machineId']);
    final int? rollId = _asInt(d['rollId']);
    final String? rollNumber = _asString(d['rollNumber']);
    final int? newProductId = _asInt(d['newProductId']);
    final String? newProductName = _asString(d['newProductName']);
    final double? currentWeight = _asDouble(d['currentWeight']);
    final bool? mounted = _asBool(d['mounted']);
    if (machineId == null ||
        rollId == null ||
        rollNumber == null ||
        newProductId == null ||
        newProductName == null ||
        currentWeight == null ||
        mounted == null) {
      return null;
    }
    return RollContinuedWithNewProductPayload(
      machineId: machineId,
      rollId: rollId,
      rollNumber: rollNumber,
      newProductId: newProductId,
      newProductName: newProductName,
      currentWeight: currentWeight,
      mounted: mounted,
    );
  }

  static RollReturnedRemainingPayload? _parseRollReturnedRemaining(
    Map<String, dynamic> d,
  ) {
    final int? machineId = _asInt(d['machineId']);
    final int? rollId = _asInt(d['rollId']);
    final String? rollNumber = _asString(d['rollNumber']);
    final double? returnedWeight = _asDouble(d['returnedWeight']);
    final bool? canPrintLabel = _asBool(d['canPrintLabel']);
    final bool? mounted = _asBool(d['mounted']);
    if (machineId == null ||
        rollId == null ||
        rollNumber == null ||
        returnedWeight == null ||
        canPrintLabel == null ||
        mounted == null) {
      return null;
    }
    return RollReturnedRemainingPayload(
      machineId: machineId,
      rollId: rollId,
      rollNumber: rollNumber,
      returnedWeight: returnedWeight,
      canPrintLabel: canPrintLabel,
      mounted: mounted,
      oldProductId: _asInt(d['oldProductId']),
      oldProductName: _asString(d['oldProductName']),
      newProductId: _asInt(d['newProductId']),
      newProductName: _asString(d['newProductName']),
      labelId: _asInt(d['labelId']),
    );
  }

  static MachineRollStateUpdatedPayload? _parseMachineRollState(
    Map<String, dynamic> d,
  ) {
    final int? machineId = _asInt(d['machineId']);
    if (machineId == null) return null;
    return MachineRollStateUpdatedPayload(
      machineId: machineId,
      activeProductId: _asInt(d['activeProductId']),
      activeProductName: _asString(d['activeProductName']),
      mountedRollId: _asInt(d['mountedRollId']),
      mountedRollNumber: _asString(d['mountedRollNumber']),
      mountedRollCurrentWeight: _asDouble(d['mountedRollCurrentWeight']),
      mountedRollCompatibleWithActiveProduct: _asBool(
        d['mountedRollCompatibleWithActiveProduct'],
      ),
      lastAction: _asString(d['lastAction']),
    );
  }

  static int? _asInt(Object? v) {
    if (v is num) return v.toInt();
    return null;
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    return null;
  }

  static String? _asString(Object? v) {
    if (v is String) return v;
    return null;
  }

  static bool? _asBool(Object? v) {
    if (v is bool) return v;
    return null;
  }
}
