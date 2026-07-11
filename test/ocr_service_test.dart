import 'package:fieldpilot/core/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractRows keeps separate customers from table text', () {
    const rawText = '''
Etat des Clients
Code Raison Sociale Adresse Tel Code TVA
411037 TABBESSI TAREK
RUE ABOU KACEM CHABBI
FOUSSANA
411035 TAHAR AHMED
AV ADDOULLEB IMM IMEN 1200
KASSERINE
77 476 610
1055033RAP000
411000 TAHER EMNA
AV ENVIRONNEMENT KM1 IM
ZOHER BEN GUERDEN
53630541
1721527X
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(3));
    expect(rows[0].name, 'TABBESSI TAREK');
    expect(rows[1].name, 'TAHAR AHMED');
    expect(rows[1].address, contains('KASSERINE'));
    expect(rows[1].phone, '77 476 610');
    expect(rows[1].taxCode, '1055033RAP000');
    expect(rows[2].name, 'TAHER EMNA');
  });

  test('extractRows splits compact OCR text with repeated client codes', () {
    const rawText = '411037 TABBESSI TAREK RUE ABOU KACEM CHABBI FOUSSANA '
        '411035 TAHAR AHMED AV ADDOULLEB IMM IMEN 1200 KASSERINE '
        '411000 TAHER EMNA AV ENVIRONNEMENT KM1 IM';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.code), ['411037', '411035', '411000']);
  });
}
