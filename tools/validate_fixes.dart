#!/usr/bin/env dart
// Validador de fixes para SIOMA
// Este script valida que todos los cambios estén correctamente implementados

import 'dart:io';
import 'dart:async';

void main() async {
  print('🔍 SIOMA - VALIDADOR DE FIXES DE CRASH');
  print('=' * 50);
  
  final validator = FixValidator();
  await validator.validateAllFixes();
}

class FixValidator {
  final List<String> _errors = [];
  final List<String> _warnings = [];
  final List<String> _successes = [];

  Future<void> validateAllFixes() async {
    print('\n📋 Iniciando validación de fixes...\n');

    // Validar archivos principales
    await _validateCameraService();
    await _validateCameraCaptureScreen();
    await _validatePersonEnrollmentScreen();
    await _validateIdentificationService();
    
    // Mostrar resultados
    _showResults();
  }

  Future<void> _validateCameraService() async {
    print('🔧 Validando CameraService...');
    
    try {
      final file = File('lib/services/camera_service.dart');
      if (!await file.exists()) {
        _addError('CameraService no encontrado');
        return;
      }

      final content = await file.readAsString();
      
      // Verificar método dispose seguro
      if (content.contains('Future.delayed(const Duration(milliseconds: 100))')) {
        _addSuccess('✅ Delay de seguridad en dispose implementado');
      } else {
        _addError('❌ Falta delay de seguridad en dispose');
      }

      // Verificar método disposeSync
      if (content.contains('void disposeSync()')) {
        _addSuccess('✅ Método disposeSync implementado');
      } else {
        _addError('❌ Falta método disposeSync');
      }

      // Verificar manejo de errores
      if (content.contains('developer.log') && content.contains('level: 900')) {
        _addSuccess('✅ Logging de errores implementado');
      } else {
        _addWarning('⚠️  Logging de errores podría mejorarse');
      }

    } catch (e) {
      _addError('Error validando CameraService: $e');
    }
  }

  Future<void> _validateCameraCaptureScreen() async {
    print('📱 Validando CameraCaptureScreen...');
    
    try {
      final file = File('lib/screens/camera_capture_screen.dart');
      if (!await file.exists()) {
        _addError('CameraCaptureScreen no encontrado');
        return;
      }

      final content = await file.readAsString();
      
      // Verificar dispose seguro
      if (content.contains('Future.microtask')) {
        _addSuccess('✅ Dispose seguro implementado');
      } else {
        _addError('❌ Falta dispose seguro');
      }

      // Verificar navegación con delay
      if (content.contains('await Future.delayed(const Duration(milliseconds: 200))')) {
        _addSuccess('✅ Delays de navegación implementados');
      } else {
        _addError('❌ Faltan delays de navegación');
      }

      // Verificar checks de mounted
      if (content.contains('if (mounted)')) {
        _addSuccess('✅ Checks de mounted implementados');
      } else {
        _addWarning('⚠️  Podrían faltar checks de mounted');
      }

    } catch (e) {
      _addError('Error validando CameraCaptureScreen: $e');
    }
  }

  Future<void> _validatePersonEnrollmentScreen() async {
    print('👤 Validando PersonEnrollmentScreen...');
    
    try {
      final file = File('lib/screens/person_enrollment_screen.dart');
      if (!await file.exists()) {
        _addError('PersonEnrollmentScreen no encontrado');
        return;
      }

      final content = await file.readAsString();
      
      // Verificar import de IdentificationService
      if (content.contains('import \'../services/identification_service.dart\'')) {
        _addSuccess('✅ Import de IdentificationService añadido');
      } else {
        _addError('❌ Falta import de IdentificationService');
      }

      // Verificar instancia del servicio
      if (content.contains('final IdentificationService _identificationService')) {
        _addSuccess('✅ Instancia de IdentificationService creada');
      } else {
        _addError('❌ Falta instancia de IdentificationService');
      }

      // Verificar logging de eventos
      if (content.contains('registerAnalysisEvent')) {
        _addSuccess('✅ Logging de eventos implementado');
      } else {
        _addWarning('⚠️  Logging de eventos podría faltar');
      }

      // Verificar delays en captura
      if (content.contains('await Future.delayed(const Duration(milliseconds: 500))')) {
        _addSuccess('✅ Delays de captura implementados');
      } else {
        _addWarning('⚠️  Podrían faltar delays de captura');
      }

    } catch (e) {
      _addError('Error validando PersonEnrollmentScreen: $e');
    }
  }

  Future<void> _validateIdentificationService() async {
    print('🔍 Validando IdentificationService...');
    
    try {
      final file = File('lib/services/identification_service.dart');
      if (!await file.exists()) {
        _addError('IdentificationService no encontrado');
        return;
      }

      final content = await file.readAsString();
      
      // Verificar método registerAnalysisEvent
      if (content.contains('Future<void> registerAnalysisEvent')) {
        _addSuccess('✅ Método registerAnalysisEvent disponible');
      } else {
        _addError('❌ Falta método registerAnalysisEvent');
      }

      // Verificar imports necesarios
      if (content.contains('analysis_event.dart')) {
        _addSuccess('✅ Import de AnalysisEvent correcto');
      } else {
        _addWarning('⚠️  Podría faltar import de AnalysisEvent');
      }

    } catch (e) {
      _addError('Error validando IdentificationService: $e');
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
    print('📊 RESULTADOS DE VALIDACIÓN');
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
      print('🎉 VALIDACIÓN EXITOSA - Todos los fixes implementados correctamente!');
      print('🚀 La aplicación debería ejecutarse sin crashes de registro.');
    } else {
      print('⚠️  Se encontraron ${_errors.length} errores que necesitan atención.');
    }
    
    print('=' * 50);
  }
}