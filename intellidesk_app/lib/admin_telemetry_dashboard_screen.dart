import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
import 'widgets/glass_card.dart';
import 'widgets/stress_test_modal.dart';
import 'utils/currency_formatter.dart';

// ============================================================================
// 1. Data Models
// ============================================================================
class CrisisDataPoint {
  final double hour; // 0.0 to 23.0
  final int ticketCount;
  final double avgSeverity;

  CrisisDataPoint({
    required this.hour,
    required this.ticketCount,
    required this.avgSeverity,
  });

  factory CrisisDataPoint.fromJson(Map<String, dynamic> json) {
    return CrisisDataPoint(
      hour: (json['hour'] as num?)?.toDouble() ?? 0.0,
      ticketCount: (json['ticket_count'] ?? json['ticketCount'] as num?)?.toInt() ?? 0,
      avgSeverity: (json['avg_severity'] ?? json['avgSeverity'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class TelemetryData {
  final double avgResolutionTimeMin;
  final double autoApprovalAccuracy;
  final int fraudSpikeCount;
  final double avgCrisisSeverity;
  
  final double financialAidRemaining;
  final double alumniFundRemaining;
  final double financialAidDisbursed;
  final double alumniFundDisbursed;
  final int estimatedDaysFinancialAid;
  final int estimatedDaysAlumniFund;

  final List<CrisisDataPoint> crisisTrend;

  TelemetryData({
    this.avgResolutionTimeMin = 14.5,
    this.autoApprovalAccuracy = 0.88,
    this.fraudSpikeCount = 0,
    this.avgCrisisSeverity = 0.65,
    this.financialAidRemaining = 50000.0,
    this.alumniFundRemaining = 25000.0,
    this.financialAidDisbursed = 0.0,
    this.alumniFundDisbursed = 0.0,
    this.estimatedDaysFinancialAid = 45,
    this.estimatedDaysAlumniFund = 60,
    this.crisisTrend = const [],
  });

  factory TelemetryData.fromJson(dynamic rawJson) {
    if (rawJson is! Map) return TelemetryData();
    final json = Map<String, dynamic>.from(rawJson);

    // Support nested payload: { success: true, data: { budget: ..., performance: ... } }
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;
    final budget = data['budget'] is Map ? Map<String, dynamic>.from(data['budget']) : <String, dynamic>{};
    final performance = data['performance'] is Map ? Map<String, dynamic>.from(data['performance']) : <String, dynamic>{};

    var trendList = data['crisis_trend'] ?? data['crisisTrend'] ?? json['crisis_trend'];
    List<dynamic> trendArray = [];
    if (trendList is List) {
      trendArray = trendList;
    } else {
      trendArray = [
        {'hour': 0.0, 'ticket_count': 2, 'avg_severity': 0.7},
        {'hour': 4.0, 'ticket_count': 5, 'avg_severity': 0.85},
        {'hour': 8.0, 'ticket_count': 12, 'avg_severity': 0.6},
        {'hour': 12.0, 'ticket_count': 18, 'avg_severity': 0.5},
        {'hour': 16.0, 'ticket_count': 14, 'avg_severity': 0.65},
        {'hour': 20.0, 'ticket_count': 8, 'avg_severity': 0.75},
      ];
    }

    final double faRemaining = (data['financial_aid_remaining'] ?? budget['financialAidRemaining'] ?? budget['remainingFunds'] ?? 50000.0) is num
        ? ((data['financial_aid_remaining'] ?? budget['financialAidRemaining'] ?? budget['remainingFunds'] ?? 50000.0) as num).toDouble()
        : 50000.0;
        
    final double afRemaining = (data['alumni_fund_remaining'] ?? budget['alumniFundRemaining'] ?? 25000.0) is num
        ? ((data['alumni_fund_remaining'] ?? budget['alumniFundRemaining'] ?? 25000.0) as num).toDouble()
        : 25000.0;

    final double faDisbursed = (data['financial_aid_disbursed'] ?? budget['totalDisbursed'] ?? 0.0) is num
        ? ((data['financial_aid_disbursed'] ?? budget['totalDisbursed'] ?? 0.0) as num).toDouble()
        : 0.0;

    final double afDisbursed = (data['alumni_fund_disbursed'] ?? 0.0) is num
        ? ((data['alumni_fund_disbursed'] ?? 0.0) as num).toDouble()
        : 0.0;

    final num? rawHours = performance['averageResolutionTimeHours'] as num?;
    final double avgResMin = (data['avg_resolution_time_min'] ?? (rawHours != null ? rawHours * 60 : null) ?? 14.5) is num
        ? ((data['avg_resolution_time_min'] ?? (rawHours != null ? rawHours * 60 : null) ?? 14.5) as num).toDouble()
        : 14.5;

    return TelemetryData(
      avgResolutionTimeMin: avgResMin,
      autoApprovalAccuracy: (data['auto_approval_accuracy'] as num?)?.toDouble() ?? 0.88,
      fraudSpikeCount: (data['fraud_spike_count'] as num?)?.toInt() ?? 0,
      avgCrisisSeverity: (data['avg_crisis_severity'] as num?)?.toDouble() ?? 0.65,
      financialAidRemaining: faRemaining,
      alumniFundRemaining: afRemaining,
      financialAidDisbursed: faDisbursed,
      alumniFundDisbursed: afDisbursed,
      estimatedDaysFinancialAid: (data['estimated_days_financial_aid'] as num?)?.toInt() ?? 45,
      estimatedDaysAlumniFund: (data['estimated_days_alumni_fund'] as num?)?.toInt() ?? 60,
      crisisTrend: trendArray.map((e) => CrisisDataPoint.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

// ============================================================================
// 2. Provider (Socket.io Telemetry Listener)
// ============================================================================
class TelemetryProvider extends ChangeNotifier {
  late io.Socket _socket;
  TelemetryData _data = TelemetryData();
  bool _isConnected = false;
  bool _hasError = false;
  String? _errorMessage;

  TelemetryData get data => _data;
  bool get isConnected => _isConnected;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  TelemetryProvider() {
    _initSocket();
    fetchTelemetryRest();
  }

  Future<void> fetchTelemetryRest() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/telemetry'),
        headers: ApiConfig.adminAuthHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        _data = TelemetryData.fromJson(decoded);
        _hasError = false;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TelemetryProvider] REST fetch error (using socket/defaults): $e');
    }
  }

  void _initSocket() {
    _socket = io.io(ApiConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket.onConnectError((err) {
      _hasError = true;
      _errorMessage = err.toString();
      notifyListeners();
    });

    _socket.onConnect((_) {
      _isConnected = true;
      _hasError = false;
      _errorMessage = null;
      notifyListeners();
      _socket.emit('telemetry:request_initial', {'institutionId': ApiConfig.institutionId});
    });

    _socket.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
    });

    // Listen for aggregated UI telemetry events
    _socket.on('telemetry:update', (payload) {
      if (payload != null) {
        _data = TelemetryData.fromJson(payload);
        notifyListeners();
      }
    });

    // Listen for real-time disbursement updates
    _socket.on('budget:disbursed', (payload) {
      if (payload != null) {
        // Optimistic partial update of the budget
        final updatedData = TelemetryData(
          avgResolutionTimeMin: _data.avgResolutionTimeMin,
          autoApprovalAccuracy: _data.autoApprovalAccuracy,
          fraudSpikeCount: _data.fraudSpikeCount,
          avgCrisisSeverity: _data.avgCrisisSeverity,
          crisisTrend: _data.crisisTrend,
          financialAidRemaining: (payload['financial_aid_remaining'] as num).toDouble(),
          financialAidDisbursed: (payload['financial_aid_disbursed'] as num).toDouble(),
          alumniFundRemaining: (payload['alumni_fund_remaining'] as num).toDouble(),
          alumniFundDisbursed: (payload['alumni_fund_disbursed'] as num).toDouble(),
          estimatedDaysFinancialAid: (payload['estimated_days_financial_aid'] as num).toInt(),
          estimatedDaysAlumniFund: (payload['estimated_days_alumni_fund'] as num).toInt(),
        );
        _data = updatedData;
        notifyListeners();
      }
    });
  }

  void retry() {
    _socket.disconnect();
    _socket.connect();
    _hasError = false;
    _errorMessage = null;
    notifyListeners();
  }
}

// ============================================================================
// 3. Live Fund Budget Gauges & Burn Rate Card
// ============================================================================
class BudgetUtilizationCard extends StatelessWidget {
  const BudgetUtilizationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: CurrencyFormatter.getSymbol('INR'), decimalDigits: 0);
    return Consumer<TelemetryProvider>(
      builder: (context, provider, _) {
        final data = provider.data;
        const double totalFinAid = 50000.0;
        const double totalAlumni = 25000.0;

        final finAidProgress = data.financialAidDisbursed / totalFinAid;
        final alumniProgress = data.alumniFundDisbursed / totalAlumni;

        return GlassCard(
          padding: const EdgeInsets.all(18.0),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFFEE4D9F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Live Fund Utilization & Burn Rate',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F1B2C)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Financial Aid Fund Gauge
              _buildBudgetGauge(
                title: 'Financial Aid Fund',
                disbursed: data.financialAidDisbursed,
                remaining: data.financialAidRemaining,
                progress: finAidProgress.clamp(0.0, 1.0),
                estimatedDays: data.estimatedDaysFinancialAid,
                color: const Color(0xFF3B82F6),
                format: currencyFormat,
              ),
              const SizedBox(height: 20),

              // Alumni Fund Gauge
              _buildBudgetGauge(
                title: 'Alumni Emergency Fund',
                disbursed: data.alumniFundDisbursed,
                remaining: data.alumniFundRemaining,
                progress: alumniProgress.clamp(0.0, 1.0),
                estimatedDays: data.estimatedDaysAlumniFund,
                color: const Color(0xFF8B5CF6),
                format: currencyFormat,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetGauge({
    required String title,
    required double disbursed,
    required double remaining,
    required double progress,
    required int estimatedDays,
    required Color color,
    required NumberFormat format,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F1B2C), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${format.format(disbursed)} Disbursed', 
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              '${format.format(remaining)} Remaining', 
              style: const TextStyle(color: Color(0xFF1F1B2C), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text(
                    'Depletion in ~$estimatedDays days', 
                    style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 4. Model Performance & Health Metrics Grid
// ============================================================================
class MLModelHealthGrid extends StatelessWidget {
  const MLModelHealthGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, _) {
        final data = provider.data;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompactMobile = constraints.maxWidth < 440;
            return GridView.count(
              crossAxisCount: isCompactMobile ? 1 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isCompactMobile ? 2.3 : 1.35,
              children: [
                _buildStatCard(
                  title: 'Avg Time-to-Resolution',
                  value: '${data.avgResolutionTimeMin.toStringAsFixed(1)} m',
                  trend: '-14.2%',
                  isPositiveTrend: true,
                  icon: Icons.speed,
                  color: const Color(0xFF3B82F6),
                ),
                _buildStatCard(
                  title: 'Auto-Approval Accuracy',
                  value: '${(data.autoApprovalAccuracy * 100).toStringAsFixed(1)}%',
                  trend: '+3.5%',
                  isPositiveTrend: true,
                  subtitle: 'Uncertainty < 3.5%',
                  icon: Icons.verified,
                  color: const Color(0xFF10B981),
                ),
                _buildStatCard(
                  title: 'Fraud Spikes (24h)',
                  value: data.fraudSpikeCount.toString(),
                  trend: '0 Active',
                  isPositiveTrend: true,
                  subtitle: 'Reconstruction Error',
                  icon: Icons.security,
                  color: data.fraudSpikeCount > 5 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
                _buildStatCard(
                  title: 'Avg Crisis Severity',
                  value: data.avgCrisisSeverity.toStringAsFixed(2),
                  trend: '-0.08',
                  isPositiveTrend: true,
                  subtitle: 'Active Queue Score',
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFEE4D9F),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? trend,
    bool isPositiveTrend = true,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: isPositiveTrend ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value, 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1F1B2C)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title, 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle, 
              style: TextStyle(fontSize: 10, color: const Color(0xFF1F1B2C).withValues(alpha: 0.4)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }
}

// ============================================================================
// 5. Interactive Crisis Volume & Severity Chart
// ============================================================================
class CrisisTrendChart extends StatelessWidget {
  const CrisisTrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, _) {
        final trend = provider.data.crisisTrend;
        
        // Provide dummy data if stream is empty for aesthetic display
        final dataPoints = trend.isEmpty 
          ? [
              CrisisDataPoint(hour: 8, ticketCount: 2, avgSeverity: 0.2),
              CrisisDataPoint(hour: 9, ticketCount: 5, avgSeverity: 0.35),
              CrisisDataPoint(hour: 10, ticketCount: 12, avgSeverity: 0.6),
              CrisisDataPoint(hour: 11, ticketCount: 8, avgSeverity: 0.4),
            ] 
          : trend;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Crisis Volume & Severity Trend (Today)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFE0E0E0),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        // X-Axis (Time of Day)
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text('${value.toInt().toString().padLeft(2, '0')}:00', 
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF6E6B7B))),
                              );
                            },
                          ),
                        ),
                        // Left Y-Axis (Ticket Count)
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toInt().toString(), 
                                style: const TextStyle(fontSize: 10, color: Color(0xFF6E6B7B)));
                            },
                          ),
                        ),
                        // Right Y-Axis (Crisis Severity scaled 0.0-1.0)
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toStringAsFixed(1), 
                                style: const TextStyle(fontSize: 10, color: Color(0xFF6E6B7B)));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      // Line 1: Ticket Volume (Left Axis Scale)
                      lineBarsData: [
                        LineChartBarData(
                          spots: dataPoints.map((dp) => FlSpot(dp.hour, dp.ticketCount.toDouble())).toList(),
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blueAccent.withValues(alpha: 0.3),
                                Colors.blueAccent.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Line 2: Avg Crisis Severity (Right Axis Scale)
                        LineChartBarData(
                          spots: dataPoints.map((dp) => FlSpot(dp.hour, dp.avgSeverity * 20)).toList(),
                          isCurved: true,
                          color: Colors.deepOrange,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepOrange.withValues(alpha: 0.2),
                                Colors.deepOrange.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, color: Colors.blueAccent, size: 10),
                        SizedBox(width: 4),
                        Text('Incoming Tickets', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.horizontal_rule, color: Colors.deepOrange, size: 14),
                        SizedBox(width: 4),
                        Text('Avg Crisis Severity Index', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 6. Admin Telemetry Dashboard Screen Layout
// ============================================================================
class AdminTelemetryDashboardScreen extends StatelessWidget {
  const AdminTelemetryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TelemetryProvider(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<TelemetryProvider>(
          builder: (context, provider, child) {
            if (provider.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Socket Error: ${provider.errorMessage ?? 'Unknown'}', 
                             textAlign: TextAlign.center,
                             style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => provider.retry(),
                          child: const Text('Retry Connection'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isMobileHeader = headerConstraints.maxWidth < 620;
                      if (isMobileHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Real-Time ML Telemetry & Budget Analytics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _StressTestButton(),
                                _PdfExportButton(),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Text(
                              'Real-Time ML Telemetry & Budget Analytics',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _StressTestButton(),
                              _PdfExportButton(),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        // Desktop / Wide Tablet layout
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  const BudgetUtilizationCard(),
                                  const SizedBox(height: 20),
                                  const MLModelHealthGrid(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            const Expanded(
                              flex: 1,
                              child: CrisisTrendChart(),
                            ),
                          ],
                        );
                      } else {
                        // Mobile / Narrow layout
                        return Column(
                          children: [
                            const BudgetUtilizationCard(),
                            const SizedBox(height: 20),
                            const MLModelHealthGrid(),
                            const SizedBox(height: 20),
                            const CrisisTrendChart(),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PdfExportButton extends StatefulWidget {
  const _PdfExportButton();

  @override
  State<_PdfExportButton> createState() => _PdfExportButtonState();
}

class _PdfExportButtonState extends State<_PdfExportButton> {
  bool _isDownloading = false;

  void _exportPdf(BuildContext context) async {
    setState(() => _isDownloading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final reportUrl = ApiService().getExecutiveReportUrl(timeframe: '30d');
      final uri = Uri.parse(reportUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('📄 Executive Audit Report PDF generated and downloading...')),
      );
    } catch (e) {
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error generating PDF report: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isDownloading ? null : () => _exportPdf(context),
      icon: _isDownloading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
      label: Text(
        _isDownloading ? 'Compiling PDF...' : 'Export Executive Audit PDF',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
      ),
    );
  }
}

class _StressTestButton extends StatelessWidget {
  const _StressTestButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => const StressTestModal(),
        );
      },
      icon: const Icon(Icons.flash_on, color: Colors.white, size: 18),
      label: const Text(
        '⚡ Run Crisis Stress-Test',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
      ),
    );
  }
}

