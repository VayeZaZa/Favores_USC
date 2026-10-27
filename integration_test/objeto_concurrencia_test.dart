import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:favores_usc/services/objeto_service.dart';

/// Ejecutar únicamente contra el emulador del proyecto demo-favores-tests.
/// Esta prueba ejercita conflictos reales; FakeFirestore no reproduce contención.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const host = String.fromEnvironment('FIRESTORE_EMULATOR_HOST');
  testWidgets(
    'dos acciones simultáneas sobre Pendiente tienen un solo ganador',
    (tester) async {
      final app = await Firebase.initializeApp(
        name: 'rf13-tests',
        options: const FirebaseOptions(
          apiKey: 'demo-api-key',
          appId: '1:123:android:test',
          messagingSenderId: '123',
          projectId: 'demo-favores-tests',
        ),
      );
      final db = FirebaseFirestore.instanceFor(app: app);
      db.settings = const Settings(persistenceEnabled: false);
      db.useFirestoreEmulator(host, 8080);
      final service = ObjetoService(
        firestore: db,
        usuarioActual: () => 'dueno',
      );
      try {
        // Repetir con casos aislados para no depender de un resultado previo.
        for (var i = 0; i < 5; i++) {
          final objeto = db.collection('objetos').doc();
          final chat = db.collection('chats').doc();
          await chat.set({'soloLectura': false});
          await objeto.set({
            'idDueno': 'dueno',
            'idReclamante': 'ayudante',
            'estadoActual': 'Pendiente',
            'chatId': chat.id,
          });
          Future<bool> intentar(String estado, bool rechazo) async {
            try {
              await service.cambiarEstadoObjeto(
                idObjeto: objeto.id,
                nuevoEstadoStr: estado,
                idUsuarioAccion: 'dueno',
                chatIdEsperado: chat.id,
                estadoEsperado: 'Pendiente',
                esRechazo: rechazo,
              );
              return true;
            } on StateError {
              return false;
            }
          }

          try {
            final resultados = await Future.wait([
              intentar('Confirmado', false),
              intentar('Publicado', true),
            ]);
            expect(resultados.where((ok) => ok).length, 1);
            final estado = (await objeto.get()).data()!['estadoActual'];
            expect(estado, resultados[0] ? 'Confirmado' : 'Publicado');
            expect((await chat.get()).data()!['soloLectura'], !resultados[0]);
          } finally {
            await objeto.delete();
            await chat.delete();
          }
        }
      } finally {
        await db.terminate();
        await app.delete();
      }
    },
    skip: host.isEmpty,
  );
}
