import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/ticket_provider.dart';
import '../../models/ticket.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/glass_card.dart';

class AdminComplianceAuditScreen extends StatefulWidget {
  const AdminComplianceAuditScreen({super.key});

  @override
  State<AdminComplianceAuditScreen> createState() => _AdminComplianceAuditScreenState();
}

class _AdminComplianceAuditScreenState extends State<AdminComplianceAuditScreen> {
  String _searchQuery = '';
  String? _actionFilter;
  String? _actorFilter;

  void _applyFilters(String search, String? actionType, String? actorType) {
    setState(() {
      _searchQuery = search;
      _actionFilter = actionType;
      _actorFilter = actorType;
    });
  }

  AuditLog _mapTicketToAuditLog(Ticket t) {
    String actionType = 'PENDING';
    String actorType = 'AI_AGENT';
    
    if (t.status == 'Auto-Approved') {
      actionType = 'AUTO_APPROVAL';
    } else if (t.status == 'Resolved') {
      actionType = 'MANUAL_APPROVAL';
      actorType = 'ADMIN_USER';
    } else if (t.status == 'Denied') {
      actionType = 'POLICY_MATCH_FAILURE';
      actorType = 'ADMIN_USER';
    } else if (t.status == 'Escalated') {
      actionType = 'ESCALATED';
    } else if (t.anomalyScore != null && t.anomalyScore! > 0.8) {
      actionType = 'FRAUD_ALERT';
    }

    return AuditLog(
      id: 'AL-${t.id.hashCode.abs().toString().padRight(4, '0').substring(0, 4)}',
      timestamp: t.createdAt,
      ticketId: t.id,
      actorType: actorType,
      actionType: actionType,
      institutionId: 'INST-USW', 
      policyContext: t.policyMatchReason ?? 'No matched policy context.',
      thoughtProcess: t.thoughtProcess ?? 'N/A',
      studentRequest: t.rawMessage,
      requestedAmount: t.calculatedAmount,
      disbursedAmount: (t.status == 'Resolved' || t.status == 'Auto-Approved') ? t.calculatedAmount : 0.0,
      crisisSeverityIndex: t.crisisSeverityIndex,
      grantConfidenceScore: t.grantConfidenceScore ?? 0.0,
      dropoutRiskScore: t.dropoutRiskScore,
    );
  }

  void _showInspector(AuditLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
          child: Align(
            alignment: Alignment.centerRight,
            child: AuditDetailInspectorModal(
              log: log,
              onClose: () => Navigator.pop(context),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<TicketProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEE4D9F)));
          }

          final allLogs = provider.tickets.map(_mapTicketToAuditLog).toList();
          final filteredLogs = allLogs.where((log) {
            final matchesSearch = _searchQuery.isEmpty || log.ticketId.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesAction = _actionFilter == null || log.actionType == _actionFilter;
            final matchesActor = _actorFilter == null || log.actorType == _actorFilter;
            return matchesSearch && matchesAction && matchesActor;
          }).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.verified_user_outlined, color: Color(0xFFEE4D9F), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compliance Audit Trail & Policy Inspector', 
                            style: TextStyle(color: Color(0xFF1F1B2C), fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.4),
                          ),
                          Text(
                            'Immutable forensic logging for AI grant decisions & policy verifications',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AuditFilterToolbar(
                  onFiltersChanged: _applyFilters,
                  onExport: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exporting Compliance Report to CSV...'),
                        backgroundColor: Color(0xFF1F1B2C),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AuditTrailTableView(
                    logs: filteredLogs,
                    onInspect: _showInspector,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 1. Audit Log Data Model
// ============================================================================
class AuditLog {
  final String id;
  final DateTime timestamp;
  final String ticketId;
  final String actorType;
  final String actionType;
  final String institutionId;
  final String policyContext;
  final String thoughtProcess;
  final String studentRequest;
  final double requestedAmount;
  final double disbursedAmount;
  final double crisisSeverityIndex;
  final double grantConfidenceScore;
  final double dropoutRiskScore;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.ticketId,
    required this.actorType,
    required this.actionType,
    required this.institutionId,
    required this.policyContext,
    required this.thoughtProcess,
    required this.studentRequest,
    required this.requestedAmount,
    required this.disbursedAmount,
    required this.crisisSeverityIndex,
    required this.grantConfidenceScore,
    required this.dropoutRiskScore,
  });
}

// ============================================================================
// 2. Filter & Compliance Export Toolbar (AuditFilterToolbar)
// ============================================================================
class AuditFilterToolbar extends StatefulWidget {
  final Function(String search, String? actionType, String? actorType) onFiltersChanged;
  final VoidCallback onExport;

  const AuditFilterToolbar({
    super.key,
    required this.onFiltersChanged,
    required this.onExport,
  });

  @override
  State<AuditFilterToolbar> createState() => _AuditFilterToolbarState();
}

class _AuditFilterToolbarState extends State<AuditFilterToolbar> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedAction;
  String? _selectedActor;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onFiltersChanged(_searchController.text, _selectedAction, _selectedActor);
  }

  Widget _buildSegmentButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Text(text, style: TextStyle(color: isActive ? Colors.black87 : Colors.black54, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search Input
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _notifyChange(),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Search Ticket ID',
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            
            // Action Type Filter
            Container(
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                hint: const Text('All Actions'),
                initialValue: _selectedAction,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Actions')),
                  DropdownMenuItem(value: 'AUTO_APPROVAL', child: Text('Auto-Approval')),
                  DropdownMenuItem(value: 'MANUAL_APPROVAL', child: Text('Manual Approval')),
                  DropdownMenuItem(value: 'POLICY_MATCH_FAILURE', child: Text('Policy Failure')),
                  DropdownMenuItem(value: 'FRAUD_ALERT', child: Text('Fraud Alert')),
                ],
                onChanged: (val) {
                  setState(() => _selectedAction = val);
                  _notifyChange();
                },
              ),
            ),

            // Actor Toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSegmentButton('AI Agent', _selectedActor == null || _selectedActor == 'AI_AGENT', () {
                    setState(() {
                      if (_selectedActor == 'AI_AGENT') {
                        _selectedActor = null;
                      } else {
                        _selectedActor = 'AI_AGENT';
                      }
                    });
                    _notifyChange();
                  }),
                  _buildSegmentButton('Admin', _selectedActor == null || _selectedActor == 'ADMIN_USER', () {
                    setState(() {
                      if (_selectedActor == 'ADMIN_USER') {
                        _selectedActor = null;
                      } else {
                        _selectedActor = 'ADMIN_USER';
                      }
                    });
                    _notifyChange();
                  }),
                ],
              ),
            ),

            // Export Button
            ElevatedButton.icon(
              onPressed: widget.onExport,
              icon: const Icon(Icons.download, color: Colors.white, size: 18),
              label: const Text('Export Compliance Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B52A3),
                elevation: 2,
                shadowColor: const Color(0xFF6B52A3).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. Paginated Audit Log Table (AuditTrailTableView)
// ============================================================================
class AuditTrailTableView extends StatelessWidget {
  final List<AuditLog> logs;
  final Function(AuditLog) onInspect;

  const AuditTrailTableView({super.key, required this.logs, required this.onInspect});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMM d, yyyy - HH:mm:ss');

    return ListView.separated(
      padding: const EdgeInsets.only(top: 16.0, bottom: 140.0),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = logs[index];
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          borderRadius: 16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return _buildMobileLayout(log, formatter);
              } else {
                return _buildDesktopLayout(log, formatter);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(AuditLog log, DateFormat formatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.ticketId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F1B2C)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(log.timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildActionBadge(log.actionType),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActorBadge(log.actorType),
                  const SizedBox(height: 4),
                  Text(
                    log.institutionId,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => onInspect(log),
              icon: const Icon(Icons.policy, size: 18, color: Color(0xFFEE4D9F)),
              label: const Text('Inspect', style: TextStyle(color: Color(0xFF1F1B2C), fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(AuditLog log, DateFormat formatter) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatter.format(log.timestamp),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                log.ticketId,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F1B2C)),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActorBadge(log.actorType),
              const SizedBox(height: 4),
              Text(
                log.institutionId,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildActionBadge(log.actionType),
          ),
        ),
        TextButton.icon(
          onPressed: () => onInspect(log),
          icon: const Icon(Icons.policy, size: 18, color: Color(0xFFEE4D9F)),
          label: const Text('Inspect', style: TextStyle(color: Color(0xFF1F1B2C), fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }

  Widget _buildActorBadge(String actor) {
    final isAi = actor == 'AI_AGENT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAi ? Colors.purple.shade50 : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAi ? Icons.smart_toy : Icons.person, size: 14, color: isAi ? Colors.purple : Colors.teal),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              actor,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAi ? Colors.purple.shade700 : Colors.teal.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bg, text;
    switch (action) {
      case 'FRAUD_ALERT':
        bg = Colors.red.shade50; text = Colors.red.shade800;
        break;
      case 'POLICY_MATCH_FAILURE':
        bg = Colors.orange.shade50; text = Colors.orange.shade900;
        break;
      case 'AUTO_APPROVAL':
        bg = Colors.green.shade50; text = Colors.green.shade900;
        break;
      default:
        bg = Colors.blue.shade50; text = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        action.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ============================================================================
// 4. Policy Match & Adjudication Diff Inspector (AuditDetailInspectorModal)
// ============================================================================
class AuditDetailInspectorModal extends StatelessWidget {
  final AuditLog log;
  final VoidCallback onClose;

  const AuditDetailInspectorModal({super.key, required this.log, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audit Inspection: ${log.ticketId}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('Recorded at: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.black54), onPressed: onClose),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ML Telemetry Snapshot
                  const Text('Machine Learning Snapshot at Execution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTelemetryCard('Crisis Severity', log.crisisSeverityIndex, Colors.deepOrange),
                      const SizedBox(width: 12),
                      _buildTelemetryCard('Grant Confidence', log.grantConfidenceScore, Colors.green),
                      const SizedBox(width: 12),
                      _buildTelemetryCard('Attrition Risk', log.dropoutRiskScore, Colors.purple),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(),
                  ),

                  // Financial Breakdown
                  const Text('Financial Adjudication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Requested', style: TextStyle(color: Colors.blueGrey)),
                            Text(CurrencyFormatter.format(log.requestedAmount, decimalDigits: 2), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                        const Icon(Icons.arrow_forward, color: Colors.blueGrey),
                        Column(
                          children: [
                            const Text('Disbursed', style: TextStyle(color: Colors.blueGrey)),
                            Text(CurrencyFormatter.format(log.disbursedAmount, decimalDigits: 2), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: log.disbursedAmount == 0 ? Colors.red : Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(),
                  ),

                  // Policy Diff
                  const Text('Adjudication Diff Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 16),
                  
                  _buildDiffBlock('Student Request (Ground Truth)', log.studentRequest, Icons.format_quote),
                  const SizedBox(height: 16),
                  _buildDiffBlock('Vector Matched Policy Clause', log.policyContext, Icons.gavel, bgColor: Colors.amber.shade50, borderColor: Colors.amber.shade200),
                  const SizedBox(height: 16),
                  _buildDiffBlock('AI Thought Process', log.thoughtProcess, Icons.psychology, bgColor: Colors.purple.shade50, borderColor: Colors.purple.shade200),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(String title, double score, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(score.toStringAsFixed(3), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffBlock(String title, String content, IconData icon, {Color? bgColor, Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey.shade50,
        border: Border.all(color: borderColor ?? Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: borderColor != null ? borderColor.withValues(alpha: 0.2) : Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(content, style: const TextStyle(height: 1.5, fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
