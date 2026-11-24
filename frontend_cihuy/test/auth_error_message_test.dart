import 'package:cihuy/services/google_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('gagal kirim email verifikasi tidak dianggap isian salah', () {
    final message = GoogleAuthRepository.emailErrorMessage(
      const AuthException(
        'Error sending confirmation email',
        code: 'unexpected_failure',
        statusCode: '500',
      ),
    );

    expect(message, contains('gagal mengirim email verifikasi'));
    expect(message, isNot(contains('Periksa isian')));
  });

  test('kode error lain tetap memakai pesan yang sudah ada', () {
    expect(
      GoogleAuthRepository.emailErrorMessage(
        const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      ),
      contains('tidak sesuai'),
    );
    expect(
      GoogleAuthRepository.emailErrorMessage(
        const AuthException(
          'For security purposes, you can only request this after 60 seconds.',
          code: 'over_email_send_rate_limit',
        ),
      ),
      contains('Tunggu sebentar'),
    );
  });
}
