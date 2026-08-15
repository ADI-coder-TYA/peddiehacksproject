// ============================================================
//  MedAccess AI — Institutional Clinical Policies & Vector KB
//  Allows hospital and campus administrators to upload clinical
//  policies with categories and coverage limits, embedding them
//  into the Supabase vector store for auto-adjudication.
// ============================================================

import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import '../../widgets/glass_card.dart';
import '../../config/api_config.dart';
import '../../utils/currency_formatter.dart';

// ─── Model ───────────────────────────────────────────────────

class KnowledgeDocument {
  final String id;
  final String fileName;
  final String documentName;
  final String category;
  final double maxCoverageLimit;
  final int chunkCount;
  final DateTime uploadedAt;

  const KnowledgeDocument({
    required this.id,
    required this.fileName,
    required this.documentName,
    this.category = 'Medical Emergency & Inpatient Care',
    this.maxCoverageLimit = 50000.0,
    required this.chunkCount,
    required this.uploadedAt,
  });

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) {
    return KnowledgeDocument(
      id: json['id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? 'Unknown',
      documentName: json['document_name'] as String? ?? 'Unknown',
      category: json['category'] as String? ?? 'Medical Emergency & Inpatient Care',
      maxCoverageLimit: (json['max_coverage_limit'] as num?)?.toDouble() ?? 50000.0,
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 0,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────

class AdminKnowledgeBaseScreen extends StatefulWidget {
  const AdminKnowledgeBaseScreen({super.key});

  @override
  State<AdminKnowledgeBaseScreen> createState() => _AdminKnowledgeBaseScreenState();
}

class _AdminKnowledgeBaseScreenState extends State<AdminKnowledgeBaseScreen> {
  String get _uploadEndpoint => '${ApiConfig.baseUrl}/admin/knowledge/upload';
  String get _listEndpoint => '${ApiConfig.baseUrl}/admin/knowledge/list';

  List<KnowledgeDocument> _documents = [];
  bool _isLoadingList = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _uploadStatusMessage;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  final List<String> _categories = [
    'All',
    'Medical Emergency & Inpatient Care',
    'Prescription & Pharmacy Copay',
    'Diagnostic, Lab & Imaging Relief',
    'Mental Health & Tele-Counseling',
    'General Healthcare Welfare Pool',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoadingList = true;
      _errorMessage = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse(_listEndpoint),
            headers: ApiConfig.adminAuthHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _documents = data
              .map((e) => KnowledgeDocument.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      } else {
        setState(() => _errorMessage = 'Failed to load documents (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      setState(() => _isLoadingList = false);
    }
  }

  void _showUploadMetadataModal(PlatformFile file) {
    final defaultDocName = file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').replaceAll(RegExp(r'[-_]'), ' ');
    final nameCtrl = TextEditingController(text: defaultDocName);
    final limitCtrl = TextEditingController(text: '100000');
    String selectedCategory = 'Medical Emergency & Inpatient Care';

    if (file.name.toLowerCase().contains('trauma') || file.name.toLowerCase().contains('emergency')) {
      selectedCategory = 'Medical Emergency & Inpatient Care';
      limitCtrl.text = '250000';
    } else if (file.name.toLowerCase().contains('pharm') || file.name.toLowerCase().contains('prescription')) {
      selectedCategory = 'Prescription & Pharmacy Copay';
      limitCtrl.text = '75000';
    } else if (file.name.toLowerCase().contains('diag') || file.name.toLowerCase().contains('imaging') || file.name.toLowerCase().contains('lab')) {
      selectedCategory = 'Diagnostic, Lab & Imaging Relief';
      limitCtrl.text = '50000';
    } else if (file.name.toLowerCase().contains('mental') || file.name.toLowerCase().contains('counsel')) {
      selectedCategory = 'Mental Health & Tele-Counseling';
      limitCtrl.text = '60000';
    }

    final formKey = GlobalKey<FormState>();

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
                        child: const Icon(Icons.picture_as_pdf, color: Color(0xFF0D9488), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Index Clinical Policy PDF',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${file.name} • ${(file.size / 1024).toStringAsFixed(1)} KB',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Policy Title
                  Text(
                    'OFFICIAL POLICY NAME',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Emergency & Acute Inpatient Trauma Policy',
                      prefixIcon: const Icon(Icons.drive_file_rename_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Policy name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Clinical Category Dropdown
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

                  // Maximum Coverage Cap
                  Text(
                    'MAXIMUM COVERAGE BENEFIT (₹)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D9488), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: limitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '100000',
                      prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Coverage limit is required';
                      final numVal = double.tryParse(v);
                      if (numVal == null || numVal <= 0) return 'Must be a positive number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Preset chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [50000, 75000, 100000, 250000].map((presetAmt) {
                      return ActionChip(
                        label: Text(
                          '₹${NumberFormat.compact().format(presetAmt)}',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                        backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                        onPressed: () {
                          setModalState(() {
                            limitCtrl.text = presetAmt.toString();
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
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final docName = nameCtrl.text.trim();
                        final cat = selectedCategory;
                        final cap = double.parse(limitCtrl.text.trim());
                        Navigator.of(modalCtx).pop();
                        _uploadFile(
                          file,
                          documentName: docName,
                          category: cat,
                          maxCoverageLimit: cap,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Upload & Generate Embeddings',
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

  Future<void> _uploadFile(
    PlatformFile file, {
    required String documentName,
    required String category,
    required double maxCoverageLimit,
  }) async {
    List<int>? bytes = file.bytes;

    if (bytes == null && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (e) {
        _showSnack('Could not read file from storage: $e', isError: true);
        return;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      _showSnack('Could not read PDF bytes.', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadStatusMessage = 'Uploading "$documentName"…';
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(_uploadEndpoint);
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(ApiConfig.adminAuthHeaders);

      request.fields['documentName'] = documentName;
      request.fields['category'] = category;
      request.fields['maxCoverageLimit'] = maxCoverageLimit.toString();
      request.fields['currency'] = 'INR';

      request.files.add(
        http.MultipartFile.fromBytes(
          'pdf',
          bytes,
          filename: file.name,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      _simulateUploadProgress();

      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final chunkCount = data['chunkCount'] as int? ?? 0;
        setState(() {
          _uploadStatusMessage = null;
          _uploadProgress = 1.0;
        });
        _showSnack(
          '"$documentName" embedded into $chunkCount vector chunks ✓',
        );
        await _fetchDocuments();
      } else {
        String errStr = 'Upload failed';
        try {
          final errJson = jsonDecode(response.body);
          errStr = errJson['error'] ?? response.body;
        } catch (_) {
          errStr = response.body;
        }
        setState(() => _uploadStatusMessage = null);
        _showSnack('Upload error: $errStr', isError: true);
      }
    } catch (e) {
      _showSnack('Upload error: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _uploadStatusMessage = null;
      });
    }
  }

  void _simulateUploadProgress() async {
    final stages = [
      (0.20, 'Parsing PDF text…'),
      (0.50, 'Chunking policy sections…'),
      (0.80, 'Generating vector embeddings…'),
      (0.95, 'Indexing into knowledge base…'),
    ];
    for (final (progress, label) in stages) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!_isUploading) break;
      if (mounted) {
        setState(() {
          _uploadProgress = progress;
          _uploadStatusMessage = label;
        });
      }
    }
  }

  Future<void> _deleteDocument(String id, String name) async {
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
                'Delete Policy Document?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Remove "$name" from the institutional vector store? Associated embedding chunks will be purged.',
          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/admin/knowledge/$id'),
            headers: ApiConfig.adminAuthHeaders,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _showSnack('"$name" removed from knowledge base.');
        await _fetchDocuments();
      } else {
        _showSnack('Delete failed (${response.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _openFilePicker() async {
    if (_isUploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      _showUploadMetadataModal(result.files.first);
    } catch (e) {
      _showSnack('Could not open file picker: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<KnowledgeDocument> get _filteredDocuments {
    return _documents.where((doc) {
      final name = doc.documentName.toLowerCase();
      final cat = doc.category;
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategoryFilter == 'All' || cat == _selectedCategoryFilter;
      return matchesSearch && matchesCat;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: CurrencyFormatter.getSymbol('INR'), decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFilePicker,
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.upload_file, size: 20),
        label: Text(
          'Upload Policy PDF',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        color: const Color(0xFF0D9488),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Banner
              GlassCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, headerConstraints) {
                        final isHeaderNarrow = headerConstraints.maxWidth < 480;

                        final titleWidget = Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.menu_book, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Institutional Clinical Policies',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_documents.length} Active Policies in Vector Store',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final uploadBtn = ElevatedButton.icon(
                          onPressed: _openFilePicker,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(
                            'Upload Policy',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        );

                        if (isHeaderNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titleWidget,
                              const SizedBox(height: 14),
                              uploadBtn,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: titleWidget),
                            const SizedBox(width: 12),
                            uploadBtn,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Uploading Progress Card
              if (_isUploading) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0D9488)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _uploadStatusMessage ?? 'Processing and embedding PDF…',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 2. Search & Category Filters
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search policies by name...',
                    hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

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

              // 3. Document Cards List
              if (_isLoadingList)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                  ),
                )
              else if (_filteredDocuments.isEmpty)
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
                        child: const Icon(Icons.menu_book_outlined, size: 36, color: Color(0xFF0D9488)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No Policy Documents Found',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload official institutional healthcare guidelines (PDF) to empower automated copay evaluations.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openFilePicker,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Upload First Policy PDF'),
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
                ..._filteredDocuments.map((doc) => _buildDocumentCard(doc, currencyFmt)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(KnowledgeDocument doc, NumberFormat currencyFmt) {
    final catColor = _getCategoryColor(doc.category);
    final catIcon = _getCategoryIcon(doc.category);
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(doc.uploadedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
                        doc.documentName,
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: catColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              doc.category.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'CAP: ${currencyFmt.format(doc.maxCoverageLimit)}',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 20),
                  onPressed: () => _deleteDocument(doc.id, doc.documentName),
                  tooltip: 'Delete Document',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.data_object, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '${doc.chunkCount} Vector Chunks',
                        style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
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
