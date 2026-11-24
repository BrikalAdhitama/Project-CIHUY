import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationApi {
  NotificationApi(this.baseUrl, this.idToken, {http.Client? client})
    : _client = client ?? http.Client();
  final String baseUrl;
  final Future<String?> Function() idToken;
  final http.Client _client;
  Future<void> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final base = Uri.parse(baseUrl);
    if (base.scheme != 'https') {
      throw StateError('API notifikasi harus menggunakan HTTPS.');
    }
    final token = await idToken();
    if (token == null) {
      throw StateError('Hubungkan akun notifikasi terlebih dahulu.');
    }
    final request = http.Request(method, base.resolve(path))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      throw StateError('Sesi notifikasi berakhir. Hubungkan akun kembali.');
    }
    if (response.statusCode == 429) {
      throw StateError('Terlalu banyak permintaan. Coba lagi sebentar.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Sinkronisasi notifikasi gagal (${response.statusCode}). Coba lagi.',
      );
    }
  }

  void close() => _client.close();
}
