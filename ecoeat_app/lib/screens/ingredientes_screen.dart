import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'receta_screen.dart';

/// Pantalla de Ingreso: agregar/remover ingredientes y generar receta.
class IngredientesScreen extends StatefulWidget {
  const IngredientesScreen({super.key});

  @override
  State<IngredientesScreen> createState() => _IngredientesScreenState();
}

class _IngredientesScreenState extends State<IngredientesScreen> {
  final _controller = TextEditingController();
  final List<String> _ingredientes = [];
  List<String> _sugeridos = [];
  bool _cargandoSugeridos = false;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _cargarSugeridos();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _mostrarError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cargarSugeridos() async {
    setState(() => _cargandoSugeridos = true);
    try {
      final lista = await ApiService.obtenerSugeridos();
      if (mounted) setState(() => _sugeridos = lista);
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _cargandoSugeridos = false);
    }
  }

  void _agregar(String valor) {
    final nombre = valor.trim();
    if (nombre.isEmpty) return;
    final existe = _ingredientes.any((i) => i.toLowerCase() == nombre.toLowerCase());
    if (!existe) setState(() => _ingredientes.add(nombre));
    _controller.clear();
  }

  void _remover(String nombre) => setState(() => _ingredientes.remove(nombre));

  Future<void> _generar() async {
    if (_ingredientes.isEmpty) {
      _mostrarError('Agrega al menos un ingrediente');
      return;
    }
    setState(() => _generando = true);
    try {
      final receta = await ApiService.generarReceta(_ingredientes);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecetaScreen(receta: receta)),
      );
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _abrirConfiguracion() async {
    final urlCtrl = TextEditingController(text: ApiService.baseUrl);
    final nuevaUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuración del servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL del backend Flask',
                hintText: 'http://10.0.2.2:5000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Emulador Android: 10.0.2.2 · Web/Windows: localhost · '
              'Celular: IP local del PC',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    urlCtrl.dispose();
    if (nuevaUrl != null && nuevaUrl.isNotEmpty) {
      ApiService.baseUrl = nuevaUrl.endsWith('/')
          ? nuevaUrl.substring(0, nuevaUrl.length - 1)
          : nuevaUrl;
      _cargarSugeridos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disponibles =
        _sugeridos.where((s) => !_ingredientes.contains(s)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoEat · Chef Virtual'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings),
            onPressed: _generando ? null : _abrirConfiguracion,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Autocomplete<String>(
                optionsBuilder: (value) {
                  final q = value.text.toLowerCase();
                  if (q.isEmpty) return const Iterable<String>.empty();
                  return disponibles.where((s) => s.toLowerCase().contains(q));
                },
                onSelected: (s) {
                  _agregar(s);
                  FocusScope.of(context).unfocus();
                },
                fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                  return TextField(
                    controller: ctrl,
                    focusNode: focus,
                    enabled: !_generando,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: '¿Qué ingredientes tienes?',
                      prefixIcon: const Icon(Icons.kitchen),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          _agregar(ctrl.text);
                          ctrl.clear();
                        },
                      ),
                    ),
                    onSubmitted: (v) {
                      _agregar(v);
                      ctrl.clear();
                    },
                  );
                },
              ),
            ),
            if (_cargandoSugeridos)
              const LinearProgressIndicator()
            else if (disponibles.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final s in disponibles)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(s),
                          onPressed: _generando ? null : () => _agregar(s),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text('Mis ingredientes (${_ingredientes.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_ingredientes.isNotEmpty && !_generando)
                    TextButton(
                      onPressed: () => setState(_ingredientes.clear),
                      child: const Text('Limpiar'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _ingredientes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco, size: 64, color: scheme.primary),
                          const SizedBox(height: 8),
                          const Text('Agrega lo que tienes en tu cocina'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _ingredientes.length,
                      itemBuilder: (_, i) {
                        final ing = _ingredientes[i];
                        return Dismissible(
                          key: ValueKey(ing),
                          direction: _generando
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          onDismissed: (_) => _remover(ing),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade400,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: scheme.primaryContainer,
                                child: Text(ing[0].toUpperCase()),
                              ),
                              title: Text(ing),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _generando ? null : () => _remover(ing),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _generando ? null : _generar,
                  icon: _generando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_generando ? 'Cocinando con IA...' : 'Generar Receta'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
