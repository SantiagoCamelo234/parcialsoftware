import 'package:ecoeat_app/models/receta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Receta.fromJson parsea la respuesta del backend', () {
    final r = Receta.fromJson({
      'id': 'abc123',
      'titulo': 'Arroz con huevo',
      'tiempo': '15 minutos',
      'porciones': 2,
      'dificultad': 'Fácil',
      'ingredientes': ['1 taza de arroz', '2 huevos'],
      'pasos': ['Cocinar arroz', 'Freír huevos'],
      'consejo_antidesperdicio': 'Usa arroz del día anterior',
      'favorito': true,
    });
    expect(r.titulo, 'Arroz con huevo');
    expect(r.ingredientes.length, 2);
    expect(r.pasos.first, 'Cocinar arroz');
    expect(r.favorito, isTrue);
  });

  test('Receta.fromJson tolera campos faltantes', () {
    final r = Receta.fromJson({});
    expect(r.titulo, 'Receta sin título');
    expect(r.pasos, isEmpty);
  });
}
