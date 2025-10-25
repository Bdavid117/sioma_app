// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sioma_app/main.dart';

void main() {
  // Inicializar SQLite FFI y configurar ProviderScope para tests de widgets
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Carga de app y navegación base', (WidgetTester tester) async {
    // Construir la app con Riverpod
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Permitir un frame inicial
    await tester.pump(const Duration(milliseconds: 200));

    // Validar que exista la barra de navegación inferior
    expect(find.byType(NavigationBar), findsOneWidget);

    // Validar que existan destinos principales (por etiqueta)
    expect(find.text('Registrar'), findsWidgets);
    expect(find.text('Eventos'), findsWidgets);
  });
}
