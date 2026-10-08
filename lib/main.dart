import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización oficial de Firebase para el proyecto Favores USC
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error inicializando Firebase: $e');
  }

  // Sembrar datos de prueba si no existen para que aparezcan en Firebase (favores, objetos, chats)
  _sembrarColeccionesFirebase();

  runApp(const ProviderScope(child: FavoresUscApp()));
}

Future<void> _sembrarColeccionesFirebase() async {
  try {
    final db = FirebaseFirestore.instance;

    // 1. Colección favores
    final favDoc = await db.collection('favores').doc('ejemplo_favor').get();
    if (!favDoc.exists) {
      await db.collection('favores').doc('ejemplo_favor').set({
        'titulo': 'Copias Taller Cálculo',
        'tipoServicio': 'Apuntes',
        'descripcion': 'Llevar 5 copias a Biblioteca Piso 2',
        'ubicacion': 'Bloque 2 - Biblioteca y Aulas Generales',
        'pago': 2000,
        'estado': 'Publicado',
        'nombreAutor': 'Estudiante USC',
        'urlFotos': <String>[],
        'fechaCreacion': FieldValue.serverTimestamp(),
        'soloLectura': false,
        'yaAvisado24h': false,
        'calificacionHabilitada': false,
      });
    }

    // 2. Colección objetos
    final objDoc = await db.collection('objetos').doc('ejemplo_objeto').get();
    if (!objDoc.exists) {
      await db.collection('objetos').doc('ejemplo_objeto').set({
        'tipo': 'perdido',
        'etiquetaColor': 'rojo',
        'titulo': 'Calculadora Casio fx-570',
        'descripcion': 'Dejada en una banca cerca a la cafetería',
        'lugarCampus': 'Bloque 6 - Cafetería Central / Plazoleta',
        'urlFoto': '',
        'nombreDueno': 'Estudiante USC',
        'estadoActual': 'Publicado',
        'fechaReporte': FieldValue.serverTimestamp(),
      });
    }

    final objEncDoc = await db.collection('objetos').doc('ejemplo_objeto_encontrado').get();
    if (!objEncDoc.exists) {
      await db.collection('objetos').doc('ejemplo_objeto_encontrado').set({
        'tipo': 'encontrado',
        'etiquetaColor': 'verde',
        'titulo': 'Llaves con llavero USC',
        'descripcion': 'Encontradas en el segundo piso de la biblioteca',
        'lugarCampus': 'Bloque 2 - Biblioteca y Aulas Generales',
        'urlFoto': 'https://images.unsplash.com/photo-1582139329536-e7284fece509?w=500',
        'nombreDueno': 'Valeria Martínez',
        'estadoActual': 'Publicado',
        'fechaReporte': FieldValue.serverTimestamp(),
      });
    }

    // 3. Colección chats
    final chatDoc = await db.collection('chats').doc('ejemplo_chat').get();
    if (!chatDoc.exists) {
      await db.collection('chats').doc('ejemplo_chat').set({
        'idReferencia': 'ejemplo_favor',
        'tipoReferencia': 'FAVOR',
        'ultimoMensaje': 'Hola, te puedo colaborar con el favor.',
        'ultimaFecha': FieldValue.serverTimestamp(),
        'soloLectura': false,
      });
    }
  } catch (e) {
    debugPrint('Error sembrando colecciones de prueba: $e');
  }
}

class FavoresUscApp extends StatelessWidget {
  const FavoresUscApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAVORES USC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
