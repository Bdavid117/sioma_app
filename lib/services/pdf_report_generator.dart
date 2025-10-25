import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/custom_event.dart';
import '../services/database_service.dart';
import '../utils/app_logger.dart';

/// Servicio para generar reportes PDF de asistencia y eventos
class PDFReportGenerator {
  final DatabaseService _databaseService;

  PDFReportGenerator(this._databaseService);

  /// Genera reporte de asistencia en formato PDF
  Future<File> generateAttendanceReport({
    DateTime? startDate,
    DateTime? endDate,
    String? personName,
  }) async {
    try {
      AppLogger.info('📄 Generando reporte PDF...');

      // 1. Definir rango de fechas
      final start = startDate ?? DateTime.now().subtract(Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // 2. Obtener eventos del período
      final allEvents = await _databaseService.getAllCustomEvents();
      final filteredEvents = allEvents.where((event) {
        final inRange = event.timestamp.isAfter(start) && event.timestamp.isBefore(end);
        final matchesPerson = personName == null || event.personName.toLowerCase().contains(personName.toLowerCase());
        return inRange && matchesPerson;
      }).toList();

      filteredEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      AppLogger.info('Eventos en el reporte: ${filteredEvents.length}');

      // 3. Calcular estadísticas
      final stats = _calculateStatistics(filteredEvents);

      // 4. Crear PDF
      final pdf = pw.Document();

      // Página 1: Resumen
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _buildHeader(start, end),
            pw.SizedBox(height: 20),
            _buildStatisticsSection(stats),
            pw.SizedBox(height: 20),
            _buildEventsTable(filteredEvents),
          ],
        ),
      );

      // 5. Guardar archivo
      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'reporte_asistencia_$timestamp.pdf';
      final file = File('${output.path}/$fileName');
      
      await file.writeAsBytes(await pdf.save());

      final fileSizeKB = (await file.length()) / 1024;
      AppLogger.info('✅ Reporte PDF generado: $fileName (${fileSizeKB.toStringAsFixed(1)} KB)');

      return file;
    } catch (e, stackTrace) {
      AppLogger.error('Error al generar reporte PDF', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Construye el encabezado del reporte
  pw.Widget _buildHeader(DateTime start, DateTime end) {
    return pw.Container(
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'REPORTE DE ASISTENCIA',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Período: ${_formatDate(start)} - ${_formatDate(end)}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.Text(
            'Generado: ${_formatDateTime(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Construye la sección de estadísticas
  pw.Widget _buildStatisticsSection(ReportStatistics stats) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ESTADÍSTICAS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total Eventos', stats.totalEvents.toString(), PdfColors.blue),
              _buildStatCard('Entradas', stats.totalEntries.toString(), PdfColors.green),
              _buildStatCard('Salidas', stats.totalExits.toString(), PdfColors.red),
              _buildStatCard('Personas', stats.uniquePersons.toString(), PdfColors.purple),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Confianza Promedio: ${(stats.averageConfidence * 100).toStringAsFixed(1)}%',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta de estadística
  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE3F2FD), // Color azul claro
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Construye la tabla de eventos
  pw.Widget _buildEventsTable(List<CustomEvent> events) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: pw.FixedColumnWidth(120),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableHeader('Fecha y Hora'),
            _buildTableHeader('Persona'),
            _buildTableHeader('Documento'),
            _buildTableHeader('Tipo'),
            _buildTableHeader('Confianza'),
          ],
        ),
        // Datos
        ...events.take(50).map((event) => pw.TableRow(
          children: [
            _buildTableCell(_formatDateTime(event.timestamp), fontSize: 8),
            _buildTableCell(event.personName),
            _buildTableCell(event.documentId, fontSize: 9),
            _buildTableCell(_formatEventType(event.eventType)),
            _buildTableCell(event.confidence != null 
                ? '${(event.confidence! * 100).toStringAsFixed(0)}%' 
                : 'N/A'),
          ],
        )),
      ],
    );
  }

  /// Construye encabezado de tabla
  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Construye celda de tabla
  pw.Widget _buildTableCell(String text, {double fontSize = 10}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: fontSize),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Calcula estadísticas del reporte
  ReportStatistics _calculateStatistics(List<CustomEvent> events) {
    final totalEvents = events.length;
    final totalEntries = events.where((e) => e.eventType.toLowerCase() == 'entrada').length;
    final totalExits = events.where((e) => e.eventType.toLowerCase() == 'salida').length;
    final uniquePersons = events.map((e) => e.personId).toSet().length;
    
    final eventsWithConfidence = events.where((e) => e.confidence != null).toList();
    final avgConfidence = eventsWithConfidence.isEmpty 
      ? 0.0 
      : eventsWithConfidence.map((e) => e.confidence!).reduce((a, b) => a + b) / eventsWithConfidence.length;

    return ReportStatistics(
      totalEvents: totalEvents,
      totalEntries: totalEntries,
      totalExits: totalExits,
      uniquePersons: uniquePersons,
      averageConfidence: avgConfidence,
    );
  }

  /// Formatea fecha
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Formatea fecha y hora
  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Formatea tipo de evento
  String _formatEventType(String type) {
    switch (type) {
      case 'Entrada':
        return '🟢 Entrada';
      case 'Salida':
        return '🔴 Salida';
      default:
        return type;
    }
  }
}

/// Estadísticas del reporte
class ReportStatistics {
  final int totalEvents;
  final int totalEntries;
  final int totalExits;
  final int uniquePersons;
  final double averageConfidence;

  ReportStatistics({
    required this.totalEvents,
    required this.totalEntries,
    required this.totalExits,
    required this.uniquePersons,
    required this.averageConfidence,
  });
}
