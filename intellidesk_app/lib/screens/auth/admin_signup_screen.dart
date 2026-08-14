import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../widgets/boutique_background.dart';
import '../../widgets/glass_card.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _instituteNameCtrl = TextEditingController(text: 'Stanford University');
  final TextEditingController _adminNameCtrl = TextEditingController(text: 'Dr. Sarah Chen');
  final TextEditingController _adminEmailCtrl = TextEditingController(text: 'admin@stanford.edu');
  final TextEditingController _passwordCtrl = TextEditingController(text: 'admin123');
  final TextEditingController _instCodeCtrl = TextEditingController(text: 'inst-stanford-01');
  final TextEditingController _defaultStudentPasswordCtrl = TextEditingController(text: 'Student@123');

  final TextEditingController _csvRawCtrl = TextEditingController();
  List<Map<String, String>> _parsedStudents = [];
  String? _csvFileName;

  static const String sampleCsvTemplate = '''id,institution_id,phone,name,email,created_at
STU-2026-001,edu-admin-123,+15550000001,Alex Johnson,alex@university.edu,2026-01-01T00:00:00Z
STU-2026-002,edu-admin-123,+15550000002,Jordan Miller,jordan@university.edu,2026-01-01T00:00:00Z
STU-2026-003,edu-admin-123,+15550000003,Taylor Swift,taylor@university.edu,2026-01-01T00:00:00Z''';

  @override
  void initState() {
    super.initState();
    // Load sample CSV data by default for smooth demo testing
    _csvRawCtrl.text = sampleCsvTemplate;
    _parseCsvText(sampleCsvTemplate);
  }

  @override
  void dispose() {
    _instituteNameCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _instCodeCtrl.dispose();
    _defaultStudentPasswordCtrl.dispose();
    _csvRawCtrl.dispose();
    super.dispose();
  }

  void _parseCsvText(String rawText) {
    if (rawText.trim().isEmpty) {
      setState(() {
        _parsedStudents = [];
      });
      return;
    }

    final lines = LineSplitter.split(rawText).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    final List<Map<String, String>> roster = [];
    final header = lines.first.toLowerCase().split(',').map((h) => h.trim()).toList();
    final hasHeader = header.any((h) => ['id', 'student_id', 'email', 'name', 'first_name', 'last_name', 'phone', 'institution_id', 'department'].contains(h));
    final dataLines = hasHeader ? lines.sublist(1) : lines;

    int idIdx = header.indexWhere((h) => h == 'id' || h == 'student_id' || h == 'studentid');
    int instIdx = header.indexWhere((h) => h == 'institution_id' || h == 'institutionid');
    int phoneIdx = header.indexWhere((h) => h == 'phone' || h == 'phone_number' || h == 'contact');
    int nameIdx = header.indexWhere((h) => h == 'name' || h == 'student_name' || h == 'full_name');
    int firstNameIdx = header.indexWhere((h) => h == 'first_name' || h == 'firstname');
    int lastNameIdx = header.indexWhere((h) => h == 'last_name' || h == 'lastname');
    int emailIdx = header.indexWhere((h) => h == 'email' || h == 'student_email');
    int deptIdx = header.indexWhere((h) => h == 'department' || h == 'branch' || h == 'dept' || h == 'major' || h == 'stream' || h == 'course');

    if (!hasHeader) {
      idIdx = 0;
      emailIdx = 1;
      phoneIdx = 2;
      nameIdx = 3;
    }

    for (int i = 0; i < dataLines.length; i++) {
      final parts = dataLines[i].split(',').map((p) => p.trim()).toList();
      if (parts.isEmpty || (parts.length == 1 && parts[0].isEmpty)) continue;

      final studentId = idIdx >= 0 && idIdx < parts.length && parts[idIdx].isNotEmpty ? parts[idIdx] : 'STU-${1000 + i + 1}';
      final email = emailIdx >= 0 && emailIdx < parts.length && parts[emailIdx].isNotEmpty ? parts[emailIdx] : (parts.length > 1 ? parts[1] : 'student_${i + 1}@university.edu');
      final phone = phoneIdx >= 0 && phoneIdx < parts.length ? parts[phoneIdx] : '';
      
      String name = '';
      if (nameIdx >= 0 && nameIdx < parts.length && parts[nameIdx].isNotEmpty) {
        name = parts[nameIdx];
      } else if (firstNameIdx >= 0 && firstNameIdx < parts.length) {
        final first = parts[firstNameIdx];
        final last = lastNameIdx >= 0 && lastNameIdx < parts.length ? parts[lastNameIdx] : '';
        name = '$first $last'.trim();
      }
      if (name.isEmpty) {
        name = email.contains('@') ? email.split('@')[0].replaceAll('.', ' ') : 'Student ${i + 1}';
      }

      final instId = instIdx >= 0 && instIdx < parts.length ? parts[instIdx] : _instCodeCtrl.text.trim();
      final dept = deptIdx >= 0 && deptIdx < parts.length ? parts[deptIdx] : 'General Academics';

      roster.add({
        'student_id': studentId,
        'studentId': studentId,
        'id': studentId,
        'name': name,
        'email': email,
        'phone': phone,
        'branch': dept,
        'department': dept,
        'institution_id': instId,
      });
    }

    setState(() {
      _parsedStudents = roster;
    });
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _csvFileName = file.name;
        });

        String content = '';
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          content = utf8.decode(file.bytes!);
        } else if (file.path != null && !kIsWeb) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            content = await ioFile.readAsString();
          }
        }

        if (content.trim().isNotEmpty) {
          _csvRawCtrl.text = content;
          _parseCsvText(content);
        }
      }
    } catch (e) {
      debugPrint('CSV pick error: $e');
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_parsedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload or paste a valid student CSV roster before submitting.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.registerInstitution(
      instituteName: _instituteNameCtrl.text.trim(),
      adminName: _adminNameCtrl.text.trim(),
      adminEmail: _adminEmailCtrl.text.trim(),
      password: _passwordCtrl.text,
      defaultStudentPassword: _defaultStudentPasswordCtrl.text.trim(),
      institutionId: _instCodeCtrl.text.trim(),
      students: _parsedStudents.cast<Map<String, dynamic>>(),
      csvContent: _csvRawCtrl.text,
    );

    if (success && mounted) {
      _showSuccessDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 28),
            SizedBox(width: 10),
            Text('Institution Registered!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_instituteNameCtrl.text} (${_instCodeCtrl.text}) has been successfully created.',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F1B2C)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
              ),
              child: Text(
                '🎉 ${_parsedStudents.length} Students imported & provisioned successfully!\n\nAll imported students can now sign in using their email or Student ID.',
                style: const TextStyle(color: Color(0xFF15803D), fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Back to main portal
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F1B2C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Enter Administrator Command Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Institute Sign Up & Student Roster Import', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BoutiqueBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: GlassCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.domain_add, color: Color(0xFF8B5CF6), size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Institution Setup & Batch Provisioning',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F1B2C),
                                    ),
                                  ),
                                  Text(
                                    'Register your institute and import student CSV roster for instant login',
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
                        const SizedBox(height: 24),

                        // Section 1: Institution & Admin Info
                        Text(
                          '1. INSTITUTE & ADMIN CREDENTIALS',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, formConstraints) {
                            final isNarrow = formConstraints.maxWidth < 500;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _instituteNameCtrl,
                                    decoration: _buildInputDeco('Institute Name', Icons.account_balance),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _instCodeCtrl,
                                    decoration: _buildInputDeco('Institution Code / ID', Icons.tag),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _adminNameCtrl,
                                    decoration: _buildInputDeco('Admin Full Name', Icons.person_outline),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _adminEmailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _buildInputDeco('Admin Official Email', Icons.email_outlined),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _defaultStudentPasswordCtrl,
                                    decoration: _buildInputDeco('Default Student Password (for CSV roster)', Icons.key),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _instituteNameCtrl,
                                        decoration: _buildInputDeco('Institute Name', Icons.account_balance),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _instCodeCtrl,
                                        decoration: _buildInputDeco('Institution Code / ID', Icons.tag),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _adminNameCtrl,
                                        decoration: _buildInputDeco('Admin Full Name', Icons.person_outline),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _adminEmailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: _buildInputDeco('Admin Official Email', Icons.email_outlined),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _defaultStudentPasswordCtrl,
                                  decoration: _buildInputDeco('Default Student Password (assigned to all CSV provisioned students)', Icons.key),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Section 2: CSV Roster Import
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '2. IMPORT STUDENT ROSTER (CSV)',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6), letterSpacing: 0.5),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _csvRawCtrl.text = sampleCsvTemplate;
                                _parseCsvText(sampleCsvTemplate);
                              },
                              icon: const Icon(Icons.file_download_outlined, size: 14),
                              label: const Text('Load Sample CSV', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // CSV Upload Dropzone Button
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickCsvFile,
                                icon: const Icon(Icons.upload_file, color: Color(0xFFEE4D9F)),
                                label: Text(
                                  _csvFileName != null ? 'File: $_csvFileName' : 'Upload CSV File (FilePicker)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFFEE4D9F), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Raw CSV Text Field
                        TextFormField(
                          controller: _csvRawCtrl,
                          maxLines: 4,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Paste CSV content here (student_id, email, phone)',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: _parseCsvText,
                        ),
                        const SizedBox(height: 24),

                        // Section 3: Interactive Parsed Roster Preview
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'PARSED STUDENT ROSTER PREVIEW',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_parsedStudents.length} Students Ready',
                                style: GoogleFonts.outfit(color: const Color(0xFFEE4D9F), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Roster Table Preview
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x1A1F1B2C)),
                            ),
                            child: _parsedStudents.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No students parsed. Upload or paste CSV above.', style: TextStyle(color: Color(0xFF94A3B8))),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: _parsedStudents.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0x1A1F1B2C)),
                                    itemBuilder: (ctx, idx) {
                                      final s = _parsedStudents[idx];
                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                          child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                                        ),
                                        title: Text(
                                          s['name'] ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        subtitle: Text(
                                          '${s['email']} • ID: ${s['studentId']}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            s['phone']?.isNotEmpty == true ? s['phone']! : (s['department'] ?? 'Valid'),
                                            style: const TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Submit Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F1B2C),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.how_to_reg, size: 20),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Register Institute & Provision Students',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF8B5CF6), size: 18),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
    );
  }
}
