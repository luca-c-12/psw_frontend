import 'package:flutter_test/flutter_test.dart';
import 'package:psw_frontend/model/support/Formati.dart';

void main() {
  test('formattaEuro usa la virgola e due decimali', () {
    expect(formattaEuro(12.5), '€ 12,50');
  });

  test('leggiImporto accetta sia la virgola sia il punto', () {
    expect(leggiImporto('12,50'), 12.5);
    expect(leggiImporto('12.50'), 12.5);
    expect(leggiImporto('abc'), null);
  });
}
