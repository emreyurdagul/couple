import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'location_models.dart';

class LocationRepository {
  LocationRepository(this._dio);
  final Dio _dio;

  Future<LocationDto> record(LocationInput input) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/locations',
      data: input.toJson(),
    );
    return LocationDto.fromJson(res.data!);
  }

  Future<List<LocationDto>> recordBatch(List<LocationInput> inputs) async {
    if (inputs.isEmpty) return const [];
    final res = await _dio.post<List<dynamic>>(
      '/locations/batch',
      data: inputs.map((i) => i.toJson()).toList(growable: false),
    );
    final data = res.data ?? const [];
    return data
        .cast<Map<String, dynamic>>()
        .map(LocationDto.fromJson)
        .toList(growable: false);
  }

  /// Partner'ın son bilinen konumu; backend 204 NoContent dönerse null.
  Future<LocationDto?> getPartnerCurrent() async {
    final res = await _dio.get<Map<String, dynamic>>('/locations/current');
    if (res.statusCode == 204 || res.data == null) return null;
    return LocationDto.fromJson(res.data!);
  }

  /// Couple history (her iki kullanıcı). Backend `from` ve `to` zorunlu;
  /// take default 1000.
  Future<List<LocationDto>> history({
    required DateTime from,
    required DateTime to,
    int take = 1000,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/locations',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'take': take,
      },
    );
    final data = res.data ?? const [];
    return data
        .cast<Map<String, dynamic>>()
        .map(LocationDto.fromJson)
        .toList(growable: false);
  }

  Future<TogetherSummary> getTogether({
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/locations/together',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return TogetherSummary.fromJson(res.data!);
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.read(apiClientProvider));
});
