/// Modelo de datos de una receta generada por la IA.
class Receta {
  final String id;
  final String titulo;
  final String tiempo;
  final int porciones;
  final String dificultad;
  final List<String> ingredientes;
  final List<String> pasos;
  final String consejo;
  final bool favorito;

  const Receta({
    required this.id,
    required this.titulo,
    required this.tiempo,
    required this.porciones,
    required this.dificultad,
    required this.ingredientes,
    required this.pasos,
    required this.consejo,
    required this.favorito,
  });

  factory Receta.fromJson(Map<String, dynamic> json) {
    List<String> lista(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];

    return Receta(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? 'Receta sin título',
      tiempo: json['tiempo']?.toString() ?? 'N/D',
      porciones: int.tryParse(json['porciones']?.toString() ?? '') ?? 2,
      dificultad: json['dificultad']?.toString() ?? 'Fácil',
      ingredientes: lista(json['ingredientes']),
      pasos: lista(json['pasos']),
      consejo: json['consejo_antidesperdicio']?.toString() ?? '',
      favorito: json['favorito'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'tiempo': tiempo,
        'porciones': porciones,
        'dificultad': dificultad,
        'ingredientes': ingredientes,
        'pasos': pasos,
        'consejo_antidesperdicio': consejo,
        'favorito': favorito,
      };
}
