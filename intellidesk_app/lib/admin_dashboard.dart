import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiService>(context, listen: false).fetchCases();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Critical'),
            Tab(text: 'High'),
            Tab(text: 'Routine'),
          ],
        ),
      ),
      body: Consumer<ApiService>(
        builder: (context, api, child) {
          if (api.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
          }
          if (api.hasError) {
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
                      Text(api.errorMessage ?? 'Unknown Network Error', 
                           textAlign: TextAlign.center,
                           style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => api.fetchCases(),
                        child: const Text('Retry Connection'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final critical = api.cases.where((c) => c['urgency'] == 'Critical' && c['status'] == 'Pending').toList();
          final high = api.cases.where((c) => c['urgency'] == 'High' && c['status'] == 'Pending').toList();
          final routine = api.cases.where((c) => c['urgency'] == 'Routine' && c['status'] == 'Pending').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              CaseList(cases: critical),
              CaseList(cases: high),
              CaseList(cases: routine),
            ],
          );
        },
      ),
    );
  }
}

class CaseList extends StatelessWidget {
  final List<dynamic> cases;
  const CaseList({super.key, required this.cases});

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return const Center(child: Text('No pending cases in this queue.', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: cases.length,
      itemBuilder: (context, index) {
        final c = cases[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              c['student']['name'] ?? 'Unknown Student', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Category: ${c['category']}', style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 4),
                Text('Assessment: ${c['aiAssessment'] ?? "N/A"}', maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF1E3A8A)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CaseDetailScreen(caseData: c)),
              );
            },
          ),
        );
      },
    );
  }
}

class CaseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> caseData;
  
  const CaseDetailScreen({super.key, required this.caseData});

  @override
  Widget build(BuildContext context) {
    final student = caseData['student'] ?? {};
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Case Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Student Information', [
              'Name: ${student['name']}',
              'Contact: ${student['contact']}',
            ]),
            const SizedBox(height: 20),
            _buildSection('Student Request (Raw)', [
              caseData['description'] ?? '',
            ]),
            const SizedBox(height: 20),
            _buildSection('AI Assessment', [
              'Urgency: ${caseData['urgency']}',
              'Category: ${caseData['category']}',
              'Summary: ${caseData['aiAssessment']}',
            ]),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await Provider.of<ApiService>(context, listen: false).updateCaseStatus(caseData['id'], 'deny');
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Deny Request', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      await Provider.of<ApiService>(context, listen: false).updateCaseStatus(caseData['id'], 'approve');
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Approve Request', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
          const Divider(),
          ...lines.map((l) => Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(l, style: const TextStyle(fontSize: 15, height: 1.5)),
          )),
        ],
      ),
    );
  }
}
