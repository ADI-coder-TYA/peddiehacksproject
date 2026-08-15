import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';
import '../../utils/currency_formatter.dart';

class AdminHealthFundsScreen extends StatefulWidget {
  const AdminHealthFundsScreen({super.key});

  @override
  State<AdminHealthFundsScreen> createState() => _AdminHealthFundsScreenState();
}

class _AdminHealthFundsScreenState extends State<AdminHealthFundsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _funds = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  final List<String> _categories = [
    'All',
    'Emergency Inpatient & Trauma',
    'Prescription & Pharmacy Copay',
    'Diagnostic, Lab & Imaging Relief',
    'Mental Health & Tele-Counseling',
    'General Healthcare Welfare Pool',
  ];

  @override
  void initState() {
    super.initState();
    _loadFunds();
  }

  Future<void> _loadFunds() async {
    setState(() => _isLoading = true);
    try {
      final funds = await _apiService.fetchHealthFunds();
      if (mounted) {
        setState(() {
          _funds = funds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _totalAllocated => _funds.fold(0.0, (sum, f) => sum + (num.tryParse(f['total_allocated']?.toString() ?? '0')?.toDouble() ?? 0.0));
  double get _totalDisbursed => _funds.fold(0.0, (sum, f) => sum + (num.tryParse(f['total_disbursed']?.toString() ?? '0')?.toDouble() ?? 0.0));
  double get _remainingReserves => (_totalAllocated - _totalDisbursed).clamp(0.0, double.infinity);

  List<Map<String, dynamic>> get _filteredFunds {
    return _funds.where((f) {
      final name = (f['name'] ?? '').toString().toLowerCase();
      final cat = (f['category'] ?? '').toString();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategoryFilter == 'All' || cat == _selectedCategoryFilter;
      return matchesSearch && matchesCat;
    }).toList();
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Prescription') || category.contains('Pharmacy')) {
      return Icons.medication_outlined;
    } else if (category.contains('Diagnostic') || category.contains('Lab')) {
      return Icons.biotech_outlined;
    } else if (category.contains('Mental')) {
      return Icons.psychology_outlined;
    } else if (category.contains('Trauma') || category.contains('Emergency')) {
      return Icons.emergency_outlined;
    }
    return Icons.health_and_safety_outlined;
  }

  Color _getCategoryColor(String category) {
    if (category.contains('Prescription') || category.contains('Pharmacy')) {
      return const Color(0xFF0284C7);
    } else if (category.contains('Diagnostic') || category.contains('Lab')) {
      return const Color(0xFF8B5CF6);
    } else if (category.contains('Mental')) {
      return const Color(0xFFEC4899);
    } else if (category.contains('Trauma') || category.contains('Emergency')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF0D9488);
  }

  void _showAllocateFundModal([Map<String, dynamic>? existingFund]) {
    final isEditing = existingFund != null;
    final nameCtrl = TextEditingController(text: existingFund != null ? existingFund['name'] : 'Apex Emergency Copay & Relief Pool');
    final amountCtrl = TextEditingController(text: isEditing ? '25000' : '100000');
    String selectedCategory = existingFund != null ? (existingFund['category'] ?? 'Emergency Inpatient & Trauma') : 'Emergency Inpatient & Trauma';
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isEditing ? Icons.add_circle : Icons.account_balance_wallet,
                          color: const Color(0xFF0D9488),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Top-Up Health Fund Pool' : 'Allocate New Health Fund Pool',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isEditing
                                  ? 'Inject additional capital into ${existingFund['name']}'
                                  : 'Provision institutional emergency relief reserves for copays',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Fund Name Field
                  Text(
                    'FUND POOL IDENTIFIER',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    readOnly: isEditing,
                    decoration: InputDecoration(
                      hintText: 'e.g. Trauma & Inpatient Relief Fund',
                      prefixIcon: const Icon(Icons.drive_file_rename_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Fund name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  if (!isEditing) ...[
                    Text(
                      'CLINICAL ALLOCATION CATEGORY',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _categories.where((c) => c != 'All').map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Allocation Amount Field
                  Text(
                    isEditing ? 'ADDITIONAL CAPITAL INJECTION (₹)' : 'INITIAL CAPITAL ALLOCATION (₹)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '50000',
                      prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Amount required';
                      final numVal = double.tryParse(v);
                      if (numVal == null || numVal <= 0) return 'Must be a positive number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Quick Preset Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [25000, 50000, 100000, 250000, 500000].map((quickAmt) {
                      return ActionChip(
                        label: Text(
                          '+₹${NumberFormat.compact().format(quickAmt)}',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                        backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                        onPressed: () {
                          setModalState(() {
                            amountCtrl.text = quickAmt.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSubmitting = true);
                              try {
                                final amt = double.parse(amountCtrl.text.trim());
                                final res = await _apiService.allocateHealthFund(
                                  name: nameCtrl.text.trim(),
                                  category: selectedCategory,
                                  amount: amt,
                                  currency: 'INR',
                                );

                                if (modalCtx.mounted) Navigator.of(modalCtx).pop();
                                await _loadFunds();

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'Successfully allocated fund!'),
                                      backgroundColor: const Color(0xFF0D9488),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to allocate fund: $e'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              isEditing ? 'Confirm Capital Top-Up' : 'Provision Health Fund Pool',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFund(Map<String, dynamic> fund) async {
    final fundId = fund['id']?.toString() ?? '';
    final fundName = fund['name']?.toString() ?? 'Health Fund';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Fund Pool?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$fundName"? All remaining allocated reserves will be de-provisioned.',
          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Pool'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteHealthFund(fundId);
        await _loadFunds();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "$fundName" successfully.'),
              backgroundColor: const Color(0xFF0D9488),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: CurrencyFormatter.getSymbol('INR'), decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: _loadFunds,
      color: const Color(0xFF0D9488),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Aggregate Reserves Metric Banner
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Institutional Health Fund Pools',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${_funds.length} Active Copay & Emergency Pools',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAllocateFundModal(),
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: Text(
                          'Allocate New Fund',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      if (isNarrow) {
                        return Column(
                          children: [
                            _buildSummaryMetric('Total Pool Capital', currencyFmt.format(_totalAllocated), const Color(0xFF0F172A), Icons.savings_outlined),
                            const SizedBox(height: 10),
                            _buildSummaryMetric('Total Disbursed', currencyFmt.format(_totalDisbursed), const Color(0xFFDC2626), Icons.outbox_outlined),
                            const SizedBox(height: 10),
                            _buildSummaryMetric('Remaining Reserves', currencyFmt.format(_remainingReserves), const Color(0xFF0D9488), Icons.verified_outlined),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildSummaryMetric('Total Pool Capital', currencyFmt.format(_totalAllocated), const Color(0xFF0F172A), Icons.savings_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSummaryMetric('Total Disbursed', currencyFmt.format(_totalDisbursed), const Color(0xFFDC2626), Icons.outbox_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSummaryMetric('Remaining Reserves', currencyFmt.format(_remainingReserves), const Color(0xFF0D9488), Icons.verified_outlined)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Search & Category Filters
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search health funds by name...',
                        hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        cat,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                      selectedColor: const Color(0xFF0D9488),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Fund Cards List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                ),
              )
            else if (_filteredFunds.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(32),
                borderRadius: 20,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Color(0xFF0D9488)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Health Funds Found',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Click "Allocate New Fund" above to provision emergency copay relief reserves for your patients.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAllocateFundModal(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Provision First Health Fund'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._filteredFunds.map((fund) => _buildFundCard(fund, currencyFmt)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundCard(Map<String, dynamic> fund, NumberFormat currencyFmt) {
    final name = fund['name']?.toString() ?? 'Health Fund Pool';
    final category = fund['category']?.toString() ?? 'Emergency Relief Pool';
    final allocated = num.tryParse(fund['total_allocated']?.toString() ?? '0')?.toDouble() ?? 0.0;
    final disbursed = num.tryParse(fund['total_disbursed']?.toString() ?? '0')?.toDouble() ?? 0.0;
    final remaining = (allocated - disbursed).clamp(0.0, double.infinity);
    final progress = allocated > 0 ? (disbursed / allocated).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();

    final catColor = _getCategoryColor(category);
    final catIcon = _getCategoryIcon(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(catIcon, color: catColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: catColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'topup') {
                      _showAllocateFundModal(fund);
                    } else if (val == 'delete') {
                      _confirmDeleteFund(fund);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'topup',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0D9488)),
                          SizedBox(width: 8),
                          Text('Top-Up Capital'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Delete Pool', style: TextStyle(color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Utilization Progress ($percent%)',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                Text(
                  '${currencyFmt.format(disbursed)} Disbursed',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(catColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),

            // Metrics row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Allocated Capital', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(currencyFmt.format(allocated), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remaining Reserves', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(currencyFmt.format(remaining), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488))),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAllocateFundModal(fund),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Top-Up', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFF0D9488),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
