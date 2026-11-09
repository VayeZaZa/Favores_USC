import '../../models/objeto_model.dart';

/// Casos locales para previsualizar las pestañas Perdidos y Encontrados.
List<ObjetoModel> crearObjetosDemostracion() {
  final ahora = DateTime.now();
  return [
    ObjetoModel(
      id: 'vista_previa_llaves_alex',
      idDueno: 'demo_alex',
      nombreDueno: 'Alex',
      titulo: 'Llaves de moto con llavero de carrito',
      descripcion: 'Perdí mis llaves; tienen un llavero tejido de carrito.',
      tipo: 'perdido',
      etiquetaColor: 'rojo',
      lugarCampus: 'Bloque 1',
      estadoActual: 'Publicado',
      fechaReporte: ahora,
      esDemostracion: true,
    ),
    ObjetoModel(
      id: 'vista_previa_cartera_david',
      idDueno: 'demo_david',
      nombreDueno: 'david san',
      titulo: 'Cartera rosada',
      descripcion: 'Encontré una cartera rosada en el Bloque 1.',
      tipo: 'encontrado',
      etiquetaColor: 'amarillo',
      lugarCampus: 'Bloque 1',
      estadoActual: 'Publicado',
      dondeQuedo: 'Encontrada en el Bloque 1',
      fechaReporte: ahora,
      esDemostracion: true,
    ),
  ];
}
