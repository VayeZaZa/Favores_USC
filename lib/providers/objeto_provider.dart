import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/objeto_model.dart';
import '../services/objeto_service.dart';

/// Provider del servicio de Objetos
final objetoServiceProvider = Provider<ObjetoService>((ref) {
  return ObjetoService();
});

/// La pantalla filtra la misma lista para evitar consultas duplicadas.
final objetosStreamProvider = StreamProvider.autoDispose<List<ObjetoModel>>((
  ref,
) {
  final service = ref.watch(objetoServiceProvider);
  return service.obtenerObjetosStream();
});

/// Provider para obtener un objeto específico en tiempo real
final objetoDetalleProvider = StreamProvider.autoDispose
    .family<ObjetoModel?, String>((ref, id) {
      final service = ref.watch(objetoServiceProvider);
      return Stream.fromFuture(service.obtenerObjetoPorId(id));
    });
