// =============================================================================
// File        : widget_test.dart
// Fungsi Utama: Smoke test dasar Flutter — memverifikasi ExambroApp dapat
//               di-render tanpa crash. Counter test boilerplate dihapus.
// Tanggal     : 27 Februari 2026
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:exambro_sman4jember/main.dart';

void main() {
  testWidgets('ExambroApp smoke test', (WidgetTester tester) async {
    // Smoke test: pastikan ExambroApp dapat di-render tanpa exception.
    // Test ini tidak menguji logika bisnis — hanya memastikan root widget valid.
    await tester.pumpWidget(const ExambroApp());
  });
}
