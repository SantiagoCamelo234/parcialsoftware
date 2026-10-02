import 'package:flutter/material.dart';

import '../models/receta.dart';

/// Pantalla de Resultado: muestra título, tiempo, ingredientes y pasos.
class RecetaScreen extends StatelessWidget {
  final Receta receta;
  const RecetaScreen({super.key, required this.receta});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(receta.titulo, maxLines: 2),
            backgroundColor: scheme.primaryContainer,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Dato(icon: Icons.timer, texto: receta.tiempo),
                    _Dato(icon: Icons.people, texto: '${receta.porciones} porciones'),
                    _Dato(icon: Icons.signal_cellular_alt, texto: receta.dificultad),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.shopping_basket, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text('Ingredientes', style: text.titleLarge),
                        ]),
                        const Divider(),
                        for (final ing in receta.ingredientes)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle, size: 18, color: scheme.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text(ing, style: text.bodyLarge)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(Icons.menu_book, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Preparación', style: text.titleLarge),
                ]),
                const SizedBox(height: 8),
                for (var i = 0; i < receta.pasos.length; i++)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        child: Text('${i + 1}'),
                      ),
                      title: Text(receta.pasos[i]),
                    ),
                  ),
                if (receta.consejo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: scheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.eco),
                      title: const Text('Consejo anti-desperdicio'),
                      subtitle: Text(receta.consejo),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _Dato({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(texto));
}
