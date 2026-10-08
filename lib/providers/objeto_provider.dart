import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/objeto_model.dart';
import '../services/objeto_service.dart';

/// Provider del servicio de Objetos
final objetoServiceProvider = Provider<ObjetoService>((ref) {
  return ObjetoService();
});

/// Filtro actual de la vista: 'todos', 'perdido', 'encontrado'
final filtroObjetosTipoProvider = StateProvider<String>((ref) => 'todos');

/// Stream en tiempo real de los objetos según el filtro seleccionado (RF10)
final objetosStreamProvider = StreamProvider.autoDispose<List<ObjetoModel>>((ref) {
  final service = ref.watch(objetoServiceProvider);
  final filtro = ref.watch(filtroObjetosTipoProvider);
  return service.obtenerObjetosStream(filtroTipo: filtro);
});

/// Provider para obtener un objeto específico en tiempo real
final objetoDetalleProvider = StreamProvider.autoDispose.family<ObjetoModel?, String>((ref, id) {
  final service = ref.watch(objetoServiceProvider);
  return Stream.fromFuture(service.obtenerObjetoPorId(id));
});
