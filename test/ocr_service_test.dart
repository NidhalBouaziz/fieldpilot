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

  test('extractRows strips trailing city names from the customer name', () {
    const rawText = '''
411037 TABBESSI TAREK FOUSSANA
RUE ABOU KACEM CHABBI
411035 TAHAR AHMED KASSERINE
AV ADDOULLEB IMM IMEN 1200
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(2));
    expect(rows[0].name, 'TABBESSI TAREK');
    expect(rows[0].address, contains('FOUSSANA'));
    expect(rows[0].address, contains('RUE ABOU KACEM CHABBI'));
    expect(rows[1].name, 'TAHAR AHMED');
    expect(rows[1].address, contains('KASSERINE'));
  });

  test('extractRows splits compact OCR text with repeated client codes', () {
    const rawText = '411037 TABBESSI TAREK RUE ABOU KACEM CHABBI FOUSSANA '
        '411035 TAHAR AHMED AV ADDOULLEB IMM IMEN 1200 KASSERINE '
        '411000 TAHER EMNA AV ENVIRONNEMENT KM1 IM';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.code), ['411037', '411035', '411000']);
    expect(rows.map((row) => row.name), [
      'TABBESSI TAREK',
      'TAHAR AHMED',
      'TAHER EMNA',
    ]);
    expect(rows[0].address, contains('RUE ABOU KACEM CHABBI'));
  });

  test('extractRows keeps phone and TVA on the same compact row', () {
    const rawText =
        '411001 TKA ANIS PLACE ALI BELHOUENE 5110 BOUMERDESS 73620300 473942/S '
        '411001 TKITEK ABDELLHAK AV DE L ENVIRONNEMENT 3010 EL HANCHA 74 284 222 881738/N';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(2));
    expect(rows[0].name, 'TKA ANIS');
    expect(rows[0].address, contains('PLACE ALI BELHOUENE'));
    expect(rows[0].phone, '73620300');
    expect(rows[0].taxCode, '473942/S');
    expect(rows[1].name, 'TKITEK ABDELLHAK');
    expect(rows[1].phone, '74 284 222');
    expect(rows[1].taxCode, '881738/N');
  });

  test('extractRows rejects rows where location was read as the customer name',
      () {
    const rawText = '''
411001 SFAX
RTE DE L AFRANCE KM 4
74665345
1034271PAP000
411001 TRIGUI WIEM
18 RUE ABDERRAHMEN EL GAFSI
3002 SFAX
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(1));
    expect(rows.single.name, 'TRIGUI WIEM');
    expect(rows.single.address, contains('18 RUE ABDERRAHMEN EL GAFSI'));
  });

  test('extractRows moves parenthesized city from name into address', () {
    const rawText = '411058 TRIFA EMNA (SFAX) '
        'RTE AFRAN KM 3 RESD GHADA APP1.4 74661163 1594044V';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(1));
    expect(rows.single.name, 'TRIFA EMNA');
    expect(rows.single.address, contains('SFAX'));
    expect(rows.single.taxCode, '1594044V');
  });

  test('extractRows does not treat client or TVA codes as phone numbers', () {
    const rawText = '''
411045 WALHA AYMEN
AV MOKHTAR ZIEDI SAKIET EZZIT-SFAX-
74853941
1307855A
411061 WOUROUD ABBES MAALOUL
GABES
94035783
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(2));
    expect(rows[0].name, 'WALHA AYMEN');
    expect(rows[0].phone, '74853941');
    expect(rows[0].taxCode, '1307855A');
    expect(rows[1].name, 'WOUROUD ABBES MAALOUL');
    expect(rows[1].phone, '94035783');
  });

  test('extractRows recovers orphan customer names as separate rows', () {
    const rawText = '''
411037 TABBESSI TAREK
RUE ABOU KACEM CHABBI
TRIGUI HANA
AV HABIB BOURGUIBA 4200 KBELLI
74665345
411035 TAHAR AHMED
AV ADDOULLEB IMM IMEN 1200
KASSERINE
77476610
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(3));
    expect(rows[0].name, 'TABBESSI TAREK');
    expect(rows[0].address, contains('RUE ABOU KACEM CHABBI'));
    expect(rows[0].address, isNot(contains('TRIGUI HANA')));
    expect(rows[0].address, isNot(contains('AV HABIB BOURGUIBA')));
    expect(rows[0].phone, isNull);
    expect(rows[1].code, isEmpty);
    expect(rows[1].name, 'TRIGUI HANA');
    expect(rows[1].address, contains('AV HABIB BOURGUIBA'));
    expect(rows[1].phone, '74665345');
    expect(rows[2].name, 'TAHAR AHMED');
    expect(rows[2].phone, '77476610');
  });

  test('extractRows keeps known location fragments in address', () {
    const rawText = '''
411000 TAHER EMNA
AV ENVIRONNEMENT KM1 IM
ZOHER BEN GUERDEN
53630541
1721527X
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(1));
    expect(rows.single.name, 'TAHER EMNA');
    expect(rows.single.address, contains('ZOHER BEN GUERDEN'));
    expect(rows.single.phone, '53630541');
    expect(rows.single.taxCode, '1721527X');
  });

  test('extractRows ignores extra TVA fragments after first row TVA', () {
    const rawText = '''
411058 TRIFA EMNA
RTE AFRAN KM 3 RESD GHADA APP1.4
1594044V
9999999X
8888888Y
411047 TRIFA TIMOUMI EMNA
CITE EL BALAOUI RTE HAFFOUZ
1626251CAP000
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(2));
    expect(rows.first.name, 'TRIFA EMNA');
    expect(rows.first.taxCode, '1594044V');
    expect(rows.first.address, isNot(contains('9999999X')));
    expect(rows.first.address, isNot(contains('8888888Y')));
    expect(rows.last.name, 'TRIFA TIMOUMI EMNA');
    expect(rows.last.taxCode, '1626251CAP000');
  });

  test('extractRows cleans phone and TVA fragments out of addresses', () {
    const rawText = '''
411058 TRIFA EMNA
RTE AFRAN KM 3 RESD GHADA APP1.4 74661163 1594044V
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(1));
    expect(rows.single.name, 'TRIFA EMNA');
    expect(rows.single.address, 'RTE AFRAN KM 3 RESD GHADA APP1.4');
    expect(rows.single.phone, '74661163');
    expect(rows.single.taxCode, '1594044V');
  });

  test('extractRows supports simple name and city lists without codes', () {
    const rawText = '''
Liste Clients
Nom Ville
TABBESSI TAREK FOUSSANA
TAHAR AHMED KASSERINE
TAHER EMNA KASSERINE
TAHER FATMA GAFSA
TAHER HAZEM SFAX
TALEB ATEF GABES
TELILI MONGI KAIROUAN
THABET HANA SFAX
THAMER MAROUEN GABES
TITAY WISSEM TOZEUR
TKA ANIS MAHDIA
TLILI IMED SFAX
TOUATI HAITHEM KEBILI
TRIFA EMNA SOUSSE
TRIGUI HANA SFAX
WOUROUD ABBES MAALOUL GABES
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(16));
    expect(rows.first.code, isEmpty);
    expect(rows.first.name, 'TABBESSI TAREK');
    expect(rows.first.address, 'FOUSSANA');
    expect(rows.first.phone, isNull);
    expect(rows.last.name, 'WOUROUD ABBES MAALOUL');
    expect(rows.last.address, 'GABES');
  });

  test('extractRows supports simple lists where city is on the next line', () {
    const rawText = '''
Clients
TRIGUI WIEM
SFAX
TRIFA EMNA
SOUSSE
WOUROUD ABBES MAALOUL
GABES
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.name), [
      'TRIGUI WIEM',
      'TRIFA EMNA',
      'WOUROUD ABBES MAALOUL',
    ]);
    expect(rows.map((row) => row.address), ['SFAX', 'SOUSSE', 'GABES']);
  });

  test('extractRows keeps same names in different cities', () {
    const rawText = '''
Clients
ALI AMOR SFAX
ALI AMOR SOUSSE
ALI AMOR GABES
''';

    final rows = OcrService().extractRows(rawText);

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.address), ['SFAX', 'SOUSSE', 'GABES']);
  });

  test('guessCityFromAddress normalizes Kbelli spelling to Kebeli', () {
    const address = 'AV HABIB BOURGUIBA 4200 KBELLI';

    expect(guessCityFromAddress(address), 'KEBELI');
  });

  test('guessCityFromAddress recognizes Tunisia governorates', () {
    const governorates = {
      'ARIANA': 'ARIANA',
      'BEJA': 'BEJA',
      'BEN AROUS': 'BEN AROUS',
      'BIZERTE': 'BIZERTE',
      'GABES': 'GABES',
      'GAFSA': 'GAFSA',
      'JENDOUBA': 'JENDOUBA',
      'KAIROUAN': 'KAIROUAN',
      'KASSERINE': 'KASSERINE',
      'KEBILI': 'KEBELI',
      'KEF': 'KEF',
      'MAHDIA': 'MAHDIA',
      'MANOUBA': 'MANOUBA',
      'MEDENINE': 'MEDENINE',
      'MONASTIR': 'MONASTIR',
      'NABEUL': 'NABEUL',
      'SFAX': 'SFAX',
      'SIDI BOUZID': 'SIDI BOUZID',
      'SILIANA': 'SILIANA',
      'SOUSSE': 'SOUSSE',
      'TATAOUINE': 'TATAOUINE',
      'TOZEUR': 'TOZEUR',
      'TUNIS': 'TUNIS',
      'ZAGHOUAN': 'ZAGHOUAN',
    };

    for (final entry in governorates.entries) {
      expect(
        guessCityFromAddress('AV HABIB BOURGUIBA ${entry.key}'),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('guessCityFromAddress maps known towns to governorates', () {
    const examples = {
      'RUE ABOU KACEM CHABBI FOUSSANA': 'KASSERINE',
      'AV MOKHTAR ZIEDI SAKIET EZZIT': 'SFAX',
      'PLACE ALI BELHOUENE BOUMERDESS': 'MAHDIA',
      'RTE AFRAN KM 3 RESD GHADA KBELLI': 'KEBELI',
      'AV DE L ENVIRONNEMENT EL HANCHA': 'SFAX',
      'GHANNOUCHE': 'GABES',
      'DJERBA': 'MEDENINE',
    };

    for (final entry in examples.entries) {
      expect(guessCityFromAddress(entry.key), entry.value, reason: entry.key);
    }
  });

  test('extract keeps notes empty for automatic imports', () async {
    const rawText = '''
411037 TABBESSI TAREK FOUSSANA
RUE ABOU KACEM CHABBI
77 476 610
''';

    final extracted = await OcrService().extract(rawText);

    expect(extracted.name, 'TABBESSI TAREK');
    expect(extracted.address, contains('FOUSSANA'));
    expect(extracted.notes, isNull);
  });
}
