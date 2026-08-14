// ============================================================
//  IntelliDesk EduAccess — Admin Knowledge Base Settings Screen
//  Allows university administrators to upload institutional PDFs
//  (Student Handbooks, Welfare Board Guidelines) and view the
//  currently active documents in the system's vector knowledge base.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../widgets/glass_card.dart';
import '../../config/api_config.dart';

// ─── Model ───────────────────────────────────────────────────

class KnowledgeDocument {
  final String id;
  final String fileName;
  final String documentName;
  final int chunkCount;
  final DateTime uploadedAt;

  const KnowledgeDocument({
    required this.id,
    required this.fileName,
    required this.documentName,
    required this.chunkCount,
    required this.uploadedAt,
  });

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) {
    return KnowledgeDocument(
      id: json['id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? 'Unknown',
      documentName: json['document_name'] as String? ?? 'Unknown',
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
  State<AdminKnowledgeBaseScreen> createState() =>
      _AdminKnowledgeBaseScreenState();
}

class _AdminKnowledgeBaseScreenState extends State<AdminKnowledgeBaseScreen> {
  // ── Config ────────────────────────────────────────────────
  String get _uploadEndpoint => '${ApiConfig.baseUrl}/admin/knowledge/upload';
  String get _listEndpoint => '${ApiConfig.baseUrl}/admin/knowledge/list';

  // ── State ─────────────────────────────────────────────────
  List<KnowledgeDocument> _documents = [];
  bool _isLoadingList = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _uploadStatusMessage;
  String? _errorMessage;

  // Drag-and-drop
  bool _isDragTarget = false;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  // ─────────────────────────────────────────────────────────
  //  NETWORK
  // ─────────────────────────────────────────────────────────

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
        setState(() => _errorMessage =
            'Failed to load documents (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error: $e');
    } finally {
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _uploadFile(PlatformFile file) async {
    if (file.bytes == null) {
      _showSnack('Could not read file bytes.', isError: true);
      return;
    }
    if (file.extension?.toLowerCase() != 'pdf') {
      _showSnack('Only PDF files are accepted.', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadStatusMessage = 'Uploading "${file.name}"…';
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(_uploadEndpoint);
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(ApiConfig.adminAuthHeaders);
      request.files.add(
        http.MultipartFile.fromBytes(
          'pdf',
          file.bytes!,
          filename: file.name,
        ),
      );

      // Simulate chunked progress feedback
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
          '"${file.name}" processed into $chunkCount chunks and embedded ✓',
        );
        await _fetchDocuments();
      } else {
        final err = jsonDecode(response.body)['error'] ?? response.body;
        setState(() => _uploadStatusMessage = null);
        _showSnack('Upload failed: $err', isError: true);
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

  /// Simulates progressive upload feedback in the UI while awaiting the response.
  void _simulateUploadProgress() async {
    final stages = [
      (0.15, 'Uploading PDF…'),
      (0.35, 'Parsing text…'),
      (0.55, 'Chunking content…'),
      (0.80, 'Generating embeddings…'),
      (0.92, 'Saving to knowledge base…'),
    ];
    for (final (progress, label) in stages) {
      await Future.delayed(const Duration(milliseconds: 800));
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
    final confirmed = await _showDeleteConfirmation(name);
    if (!confirmed) return;

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

  // ─────────────────────────────────────────────────────────
  //  FILE PICKER INTERACTION
  // ─────────────────────────────────────────────────────────

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
      await _uploadFile(result.files.first);
    } catch (e) {
      _showSnack('Could not open file picker: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove Document'),
            content: Text(
                'Remove "$name" from the knowledge base? '
                'This will delete all associated embedding vectors.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.menu_book, color: Color(0xFFEE4D9F), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Institutional Knowledge Base',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: const Color(0xFF1F1B2C),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const Text(
                                'Vectorized handbook policies and RAG context management',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoadingList ? null : _fetchDocuments,
                    icon: Icon(
                      Icons.refresh,
                      color: const Color(0xFF1F1B2C).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            _buildHeaderSection(),
            const SizedBox(height: 20),
            _buildDropZone(),
            if (_isUploading) ...[
              const SizedBox(height: 16),
              _buildProgressCard(),
            ],
            const SizedBox(height: 28),
            _buildDocumentListSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Institutional Guardrails',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload your Student Handbooks, Welfare Board Guidelines, and other '
          'policy documents. The AI will use these to evaluate every student '
          'request against your institution\'s specific rules.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        // Info chips
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: const [
            _InfoChip(
              icon: Icons.picture_as_pdf,
              label: 'PDF format only',
              bgColor: Color(0xFFE8D3D6),
            ),
            _InfoChip(
              icon: Icons.memory,
              label: 'Auto-chunked & embedded',
              bgColor: Color(0xFFE3E0EE),
            ),
            _InfoChip(
              icon: Icons.security,
              label: 'Stored in policy_embeddings',
              bgColor: Color(0xFFDEEAF6),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropZone() {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isDragTarget = true);
        return true;
      },
      onLeave: (details) => setState(() => _isDragTarget = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragTarget = false);
        // Drag-and-drop actual file bytes are handled via platform channels;
        // on desktop flutter the file picker is the reliable cross-platform path.
        _openFilePicker();
      },
      builder: (context, candidateData, rejectedData) {
        return GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: _isDragTarget
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _isUploading ? null : _openFilePicker,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isDragTarget
                        ? const Icon(Icons.download,
                            size: 52, color: Color(0xFF3B82F6))
                        : _isUploading
                            ? const Icon(Icons.hourglass_top,
                                size: 52, color: Color(0xFF8B5CF6))
                            : const Icon(Icons.upload_file,
                                size: 52, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isDragTarget
                        ? 'Drop PDF here'
                        : _isUploading
                            ? 'Processing…'
                            : 'Drag & Drop or Click to Upload',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isDragTarget
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PDF files only • Max 50 MB',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isUploading)
                    ElevatedButton.icon(
                      onPressed: _openFilePicker,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Browse Files'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A4FCF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _uploadStatusMessage ?? 'Processing…',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
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
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_uploadProgress * 100).toStringAsFixed(0)}% complete',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Active Institutional Documents',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (_documents.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDEEAF6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_documents.length} document${_documents.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F1B2C),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'These PDFs are actively used to evaluate student requests.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 16),

        // Error banner
        if (_errorMessage != null)
          _ErrorBanner(message: _errorMessage!, onRetry: _fetchDocuments),

        // Loading state
        if (_isLoadingList && _documents.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
            ),
          ),

        // Empty state
        if (!_isLoadingList && _documents.isEmpty && _errorMessage == null)
          _EmptyDocumentsState(onUpload: _openFilePicker),

        // Document list
        if (_documents.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _documents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = _documents[index];
              return _DocumentCard(
                document: doc,
                onDelete: () => _deleteDocument(doc.id, doc.documentName),
              );
            },
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DOCUMENT CARD
// ─────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final KnowledgeDocument document;
  final VoidCallback onDelete;

  const _DocumentCard({required this.document, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // PDF icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Color(0xFFEF4444),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.documentName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  document.fileName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _MiniChip(
                      label:
                          '${document.chunkCount} chunk${document.chunkCount == 1 ? '' : 's'}',
                      bgColor: const Color(0xFFE3E0EE),
                    ),
                    _MiniChip(
                      label: DateFormat('MMM d, yyyy').format(document.uploadedAt),
                      bgColor: const Color(0xFFE2E8F0),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            tooltip: 'Remove from knowledge base',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SUPPORT WIDGETS
// ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1F1B2C)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F1B2C),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color bgColor;

  const _MiniChip({required this.label, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: const Color(0xFF1F1B2C),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      borderRadius: 12,
      backgroundColor: const Color(0xFFFFF0F0).withValues(alpha: 0.8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDocumentsState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyDocumentsState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 72,
              color: const Color(0xFF6E6B7B),
            ),
            const SizedBox(height: 16),
            Text(
              'No policy documents uploaded yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F1B2C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your Student Handbook or Welfare Guidelines\nto activate institutional guardrails.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6E6B7B),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload First Document'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF1E3A8A)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
