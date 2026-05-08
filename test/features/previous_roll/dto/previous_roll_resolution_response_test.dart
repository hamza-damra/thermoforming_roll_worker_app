import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/dto/previous_roll_resolution_response.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/entities/previous_roll_resolution.dart';

void main() {
  group('PreviousRollResolutionResponse.fromJson', () {
    test('parses CLOSED_FULL / CONSUMED / NONE', () {
      final dto =
          PreviousRollResolutionResponse.fromJson(const <String, dynamic>{
            'rollId': 999,
            'generatedRollId': '777000000001',
            'finalState': 'CONSUMED',
            'consumedWeightKg': 250.0,
            'remainingWeightKg': 0.0,
            'remainderAction': 'NONE',
            'eventType': 'CLOSED_FULL',
            'reprintAvailable': false,
          });
      expect(dto.finalState, PreviousRollFinalState.consumed);
      expect(dto.remainderAction, PreviousRollRemainderAction.none);
      expect(dto.eventType, PreviousRollEventType.closedFull);
      expect(dto.consumedWeightKg, 250.0);
      expect(dto.remainingWeightKg, 0.0);
      expect(dto.reprintAvailable, isFalse);
    });

    test('parses CLOSED_PARTIAL_RETURN / PARTIALLY_RETURNED / RETURN', () {
      final dto =
          PreviousRollResolutionResponse.fromJson(const <String, dynamic>{
            'rollId': 999,
            'generatedRollId': '777000000001',
            'finalState': 'PARTIALLY_RETURNED',
            'consumedWeightKg': 175.5,
            'remainingWeightKg': 75.5,
            'remainderAction': 'RETURN',
            'eventType': 'CLOSED_PARTIAL_RETURN',
            'reprintAvailable': true,
          });
      expect(dto.finalState, PreviousRollFinalState.partiallyReturned);
      expect(dto.remainderAction, PreviousRollRemainderAction.returned);
      expect(dto.eventType, PreviousRollEventType.closedPartialReturn);
      expect(dto.reprintAvailable, isTrue);
    });

    test('parses CLOSED_PARTIAL_GRINDING / SENT_TO_GRINDING / GRINDING', () {
      final dto =
          PreviousRollResolutionResponse.fromJson(const <String, dynamic>{
            'rollId': 999,
            'generatedRollId': '777000000001',
            'finalState': 'SENT_TO_GRINDING',
            'consumedWeightKg': 210.0,
            'remainingWeightKg': 40.0,
            'remainderAction': 'GRINDING',
            'eventType': 'CLOSED_PARTIAL_GRINDING',
            'reprintAvailable': true,
          });
      expect(dto.finalState, PreviousRollFinalState.sentToGrinding);
      expect(dto.remainderAction, PreviousRollRemainderAction.grinding);
      expect(dto.eventType, PreviousRollEventType.closedPartialGrinding);
    });

    test('rejects unknown finalState', () {
      expect(
        () => PreviousRollResolutionResponse.fromJson(const <String, dynamic>{
          'rollId': 1,
          'generatedRollId': 'x',
          'finalState': 'UNRELEASED_NEW_STATE',
          'consumedWeightKg': 0.0,
          'remainingWeightKg': 0.0,
          'remainderAction': 'NONE',
          'eventType': 'CLOSED_FULL',
          'reprintAvailable': false,
        }),
        throwsFormatException,
      );
    });

    test('toEntity copies every field', () {
      final entity =
          PreviousRollResolutionResponse.fromJson(const <String, dynamic>{
            'rollId': 999,
            'generatedRollId': '777000000001',
            'finalState': 'PARTIALLY_RETURNED',
            'consumedWeightKg': 175.5,
            'remainingWeightKg': 75.5,
            'remainderAction': 'RETURN',
            'eventType': 'CLOSED_PARTIAL_RETURN',
            'reprintAvailable': true,
          }).toEntity();
      expect(entity.generatedRollId, '777000000001');
      expect(entity.finalState, PreviousRollFinalState.partiallyReturned);
      expect(entity.reprintAvailable, isTrue);
    });

    test('integer-typed weights are coerced to double', () {
      final dto =
          PreviousRollResolutionResponse.fromJson(const <String, dynamic>{
            'rollId': 1,
            'generatedRollId': '777000000001',
            'finalState': 'CONSUMED',
            'consumedWeightKg': 250,
            'remainingWeightKg': 0,
            'remainderAction': 'NONE',
            'eventType': 'CLOSED_FULL',
            'reprintAvailable': false,
          });
      expect(dto.consumedWeightKg, 250.0);
      expect(dto.remainingWeightKg, 0.0);
    });
  });
}
