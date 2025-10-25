import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/service_providers.dart';
import '../models/custom_event.dart';

/// Pantalla de dashboard de analytics con estadísticas y gráficas
class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends ConsumerState<AnalyticsDashboardScreen> {
  bool _isLoading = true;
  DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final dbService = ref.read(databaseServiceProvider);
    
    try {
      final persons = await dbService.getAllPersons();
      final events = await dbService.getAllCustomEvents();
      
      // Calcular estadísticas
      final data = DashboardData.fromEvents(persons.length, events);
      
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Sin datos disponibles'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tarjetas de resumen
                        _buildSummaryCards(),
                        const SizedBox(height: 24),
                        
                        // Gráfica de entradas por hora (últimas 24h)
                        _buildSectionTitle('Actividad por Hora (Últimas 24h)'),
                        const SizedBox(height: 12),
                        _buildHourlyChart(),
                        const SizedBox(height: 24),
                        
                        // Gráfica de tendencia últimos 7 días
                        _buildSectionTitle('Tendencia Semanal'),
                        const SizedBox(height: 12),
                        _buildWeeklyTrendChart(),
                        const SizedBox(height: 24),
                        
                        // Top 5 personas más identificadas
                        _buildSectionTitle('Top 5 Personas (Esta Semana)'),
                        const SizedBox(height: 12),
                        _buildTopPeopleList(),
                        const SizedBox(height: 24),
                        
                        // Estadísticas de confianza
                        _buildSectionTitle('Distribución de Confianza'),
                        const SizedBox(height: 12),
                        _buildConfidenceStats(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Personas',
            _data!.totalPersons.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Eventos Hoy',
            _data!.eventsToday.toString(),
            Icons.event,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildHourlyChart() {
    final hourlyData = _data!.hourlyData;
    
    if (hourlyData.isEmpty) {
      return _buildEmptyChart('Sin datos de las últimas 24 horas');
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (hourlyData.values.reduce((a, b) => a > b ? a : b) * 1.2),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}h',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: hourlyData.entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  color: Colors.blue,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWeeklyTrendChart() {
    final weeklyData = _data!.weeklyData;
    
    if (weeklyData.isEmpty) {
      return _buildEmptyChart('Sin datos semanales');
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                  final index = value.toInt();
                  if (index >= 0 && index < days.length) {
                    return Text(days[index], style: const TextStyle(fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: weeklyData.entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                  .toList(),
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withAlpha(51),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPeopleList() {
    final topPeople = _data!.topPeople;
    
    if (topPeople.isEmpty) {
      return _buildEmptyCard('Sin identificaciones esta semana');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topPeople.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final person = topPeople[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColorForRank(index),
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(person['name'] as String),
            subtitle: Text('Documento: ${person['documentId']}'),
            trailing: Chip(
              label: Text('${person['count']} veces'),
              backgroundColor: _getColorForRank(index).withAlpha(51),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfidenceStats() {
    final confidenceStats = _data!.confidenceDistribution;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildConfidenceRow('Alta (≥80%)', confidenceStats['high']!, Colors.green),
          const SizedBox(height: 8),
          _buildConfidenceRow('Media (65-79%)', confidenceStats['medium']!, Colors.orange),
          const SizedBox(height: 8),
          _buildConfidenceRow('Baja (<65%)', confidenceStats['low']!, Colors.red),
          const Divider(height: 24),
          Text(
            'Promedio: ${confidenceStats['average']!.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceRow(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label),
        ),
        Expanded(
          flex: 3,
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.grey[300],
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            '${value.toInt()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Color _getColorForRank(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}

/// Datos del dashboard
class DashboardData {
  final int totalPersons;
  final int eventsToday;
  final Map<int, int> hourlyData; // hora -> count
  final Map<int, int> weeklyData; // día -> count
  final List<Map<String, dynamic>> topPeople;
  final Map<String, double> confidenceDistribution;

  DashboardData({
    required this.totalPersons,
    required this.eventsToday,
    required this.hourlyData,
    required this.weeklyData,
    required this.topPeople,
    required this.confidenceDistribution,
  });

  factory DashboardData.fromEvents(int totalPersons, List<CustomEvent> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last24h = now.subtract(const Duration(hours: 24));
    final last7days = now.subtract(const Duration(days: 7));

    // Eventos de hoy
    final eventsToday = events.where((e) => e.timestamp.isAfter(today)).length;

    // Datos por hora (últimas 24h)
    final hourlyData = <int, int>{};
    for (int i = 0; i < 24; i++) {
      hourlyData[i] = 0;
    }
    for (final event in events.where((e) => e.timestamp.isAfter(last24h))) {
      final hour = event.timestamp.hour;
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }

    // Datos semanales
    final weeklyData = <int, int>{};
    for (int i = 0; i < 7; i++) {
      weeklyData[i] = 0;
    }
    for (final event in events.where((e) => e.timestamp.isAfter(last7days))) {
      final dayOfWeek = event.timestamp.weekday - 1; // 0 = Lunes
      weeklyData[dayOfWeek] = (weeklyData[dayOfWeek] ?? 0) + 1;
    }

    // Top personas (última semana)
    final personCounts = <int, Map<String, dynamic>>{};
    for (final event in events.where((e) => e.timestamp.isAfter(last7days))) {
      if (!personCounts.containsKey(event.personId)) {
        personCounts[event.personId] = {
          'name': event.personName,
          'documentId': event.documentId,
          'count': 0,
        };
      }
      personCounts[event.personId]!['count']++;
    }
    final topPeople = personCounts.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // Distribución de confianza
    final eventsWithConfidence = events.where((e) => e.confidence != null).toList();
    final confidences = eventsWithConfidence.map((e) => e.confidence!).toList();
    final high = confidences.where((c) => c >= 0.8).length;
    final medium = confidences.where((c) => c >= 0.65 && c < 0.8).length;
    final low = confidences.where((c) => c < 0.65).length;
    final total = confidences.isEmpty ? 1 : confidences.length;
    final avgConfidence = confidences.isEmpty
        ? 0.0
        : confidences.reduce((a, b) => a + b) / confidences.length * 100;

    return DashboardData(
      totalPersons: totalPersons,
      eventsToday: eventsToday,
      hourlyData: hourlyData,
      weeklyData: weeklyData,
      topPeople: topPeople.take(5).toList(),
      confidenceDistribution: {
        'high': (high / total) * 100,
        'medium': (medium / total) * 100,
        'low': (low / total) * 100,
        'average': avgConfidence,
      },
    );
  }
}
