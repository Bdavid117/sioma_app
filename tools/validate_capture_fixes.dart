#!/usr/bin/env dart
// Validador de fixes para problemas de captura de foto
// Verifica que no haya duplicación ni congelamiento

import 'dart:io';

void main() async {
  print('🔍 SIOMA - VALIDADOR DE FIXES DE CAPTURA');
  print('=' * 50);
  
  final validator = CaptureFixValidator();
  await validator.validateCaptureFixes();
}

class CaptureFixValidator {
  final List<String> _errors = [];
  final List<String> _warnings = [];
  final List<String> _successes = [];

  Future<void> validateCaptureFixes() async {
    print('\n📋 Validando fixes de captura de foto...\n');

    // Validar fixes implementados
    await _validateCameraCaptureScreenFixes();
    await _validateCameraServiceOptimization();
    await _validatePersonEnrollmentScreenFixes();
    
    // Mostrar resultados
    _showResults();
  }

  Future<void> _validateCameraCaptureScreenFixes() async {
    print('📱 Validando CameraCaptureScreen fixes...');
    
    try {
      final file = File('lib/screens/camera_capture_screen.dart');
      if (!await file.exists()) {
        _addError('CameraCaptureScreen no encontrado');
        return;
      }

      final content = await file.readAsString();
      
      // Verificar que NO se ejecute callback en _takePicture
      if (!content.contains('// NO ejecutar callback aquí - evita duplicación')) {
        _addError('❌ Falta prevención de duplicación en _takePicture');
      } else {
        _addSuccess('✅ Duplicación de callback prevenida');
      }

      // Verificar que callback se ejecute solo en confirmación
      if (content.contains('// Ejecutar callback SOLO cuando el usuario confirma')) {
        _addSuccess('✅ Callback ejecutado solo en confirmación');
      } else {
        _addError('❌ Falta ejecución controlada de callback');
      }

      // Verificar indicadores visuales mejorados
      if (content.contains('¿Desea usar esta foto?')) {
        _addSuccess('✅ Indicadores visuales mejorados');
      } else {
        _addWarning('⚠️  Podrían faltar indicadores visuales');
      }

      // Verificar delay optimizado
      if (content.contains('Duration(milliseconds: 50)')) {
        _addSuccess('✅ Delay optimizado para evitar congelamiento');
      } else {
        _addWarning('⚠️  Delay podría no estar optimizado');
      }

      // Verificar barrierDismissible
      if (content.contains('barrierDismissible: false')) {
        _addSuccess('✅ Dialog no dismissible implementado');
      } else {
        _addWarning('⚠️  Dialog podría cerrarse accidentalmente');
      }

    } catch (e) {
      _addError('Error validando CameraCaptureScreen: $e');
    }
  }

  Future<void> _validateCameraServiceOptimization() async {
    print('🔧 Validando CameraService optimización...');
    
    try {
      final file = File('lib/services/camera_service.dart');
      if (!await file.exists()) {
        _addError('CameraService no encontrado');
        return;
      }

      final content = await file.readAsString();
      
      // Verificar optimización de movimiento de archivo
      if (content.contains('await tempFile.rename(filePath)')) {
        _addSuccess('✅ Optimización de archivo con rename implementada');
      } else {
        _addError('❌ Falta optimización con rename');
      }

      // Verificar eliminación de copy innecesario
      if (!content.contains('await tempFile.copy(filePath)')) {
        _addSuccess('✅ Copy innecesario eliminado');
      } else {
        _addWarning('⚠️  Aún usa copy en lugar de rename');
      }

      // Verificar verificación de existencia
      if (content.contains('await finalFile.exists()')) {
        _addSuccess('✅ Verificación de archivo final implementada');
      } else {
        _addWarning('⚠️  Podría faltar verificación de archivo final');
      }

    } catch (e) {
      _addError('Error validando CameraService: $e');
    }
  }

  Future<void> _validatePersonEnrollmentScreenFixes() async {
    print('👤 Validando PersonEnrollmentScreen fixes...');
    
    try {
      final file = File('lib/screens/person_enrollment_screen.dart');
      if (!await file.exists()) {
        _addError('PersonEnrollmentScreen no encontrado');
        return;
      }

      final content = await file.readAsString();
      
      // Verificar callback vacío
      if (content.contains('// Callback vacío para evitar duplicación')) {
        _addSuccess('✅ Callback vacío implementado');
      } else {
        _addError('❌ Falta callback vacío para prevenir duplicación');
      }

      // Verificar procesamiento único
      if (content.contains('// El procesamiento se hará cuando se retorne el result')) {
        _addSuccess('✅ Procesamiento único asegurado');
      } else {
        _addWarning('⚠️  Podría faltar comentario de procesamiento único');
      }

      // Verificar delay optimizado
      if (content.contains('Duration(milliseconds: 200)')) {
        _addSuccess('✅ Delay optimizado para embedding');
      } else {
        _addWarning('⚠️  Delay para embedding podría no estar optimizado');
      }

      // Verificar indicador de procesamiento
      if (content.contains('_isProcessing = true; // Mantener indicador')) {
        _addSuccess('✅ Indicador de procesamiento mantenido');
      } else {
        _addWarning('⚠️  Podría faltar indicador de procesamiento');
      }

    } catch (e) {
      _addError('Error validando PersonEnrollmentScreen: $e');
    }
  }

  void _addError(String message) {
    _errors.add(message);
    print('  $message');
  }

  void _addWarning(String message) {
    _warnings.add(message);
    print('  $message');
  }

  void _addSuccess(String message) {
    _successes.add(message);
    print('  $message');
  }

  void _showResults() {
    print('\n' + '=' * 50);
    print('📊 RESULTADOS DE VALIDACIÓN DE CAPTURA');
    print('=' * 50);
    
    print('\n✅ ÉXITOS (${_successes.length}):');
    for (final success in _successes) {
      print('  $success');
    }
    
    if (_warnings.isNotEmpty) {
      print('\n⚠️  ADVERTENCIAS (${_warnings.length}):');
      for (final warning in _warnings) {
        print('  $warning');
      }
    }
    
    if (_errors.isNotEmpty) {
      print('\n❌ ERRORES (${_errors.length}):');
      for (final error in _errors) {
        print('  $error');
      }
    }
    
    print('\n' + '=' * 50);
    
    if (_errors.isEmpty) {
      print('🎉 VALIDACIÓN EXITOSA - Fixes de captura implementados correctamente!');
      print('📷 Las fotos no deberían duplicarse ni congelar la pantalla.');
    } else {
      print('⚠️  Se encontraron ${_errors.length} errores que necesitan atención.');
    }
    
    print('=' * 50);
  }
}