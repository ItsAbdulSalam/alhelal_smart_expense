import '../../core/services/api_client.dart';

class AnalyticsLaravelRemoteDataSource {
  AnalyticsLaravelRemoteDataSource();

  /// جلب ملخص الإحصائيات (الإجمالي، توزيع الفئات، والإنفاق اليومي)
  Future<Map<String, dynamic>> getAnalyticsSummary({String? month}) async {
    final response = await ApiClient.dio.get(
      '/analytics/summary',
      queryParameters: month != null ? {'month': month} : null,
    );

    return response.data['data'] as Map<String, dynamic>;
  }
}
