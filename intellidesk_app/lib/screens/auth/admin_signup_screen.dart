import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/boutique_background.dart';
import '../../widgets/glass_card.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _instituteNameCtrl = TextEditingController();
  final TextEditingController _adminNameCtrl = TextEditingController();
  final TextEditingController _adminEmailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _instCodeCtrl = TextEditingController();
  final TextEditingController _specialtyCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _defaultStudentPasswordCtrl = TextEditingController();
  final TextEditingController _fundPoolCtrl = TextEditingController();

  final TextEditingController _csvRawCtrl = TextEditingController();
  List<Map<String, String>> _parsedStudents = [];
  String? _csvFileName;
  bool _obscurePassword = true;

  static const String sampleCsvTemplate = '''id,institution_id,phone,name,email,emergency_contact
PAT-2026-001,inst-001,+91 98765 43210,Alex Rivera,alex.rivera@campushealth.edu,+91 98765 43211
PAT-2026-002,inst-001,+91 98111 22334,Jordan Miller,jordan.miller@campushealth.edu,+91 98111 22335
PAT-2026-003,inst-001,+91 99223 34455,Taylor Chen,taylor.chen@campushealth.edu,+91 99223 34456''';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _instituteNameCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _instCodeCtrl.dispose();
    _specialtyCtrl.dispose();
    _phoneCtrl.dispose();
    _defaultStudentPasswordCtrl.dispose();
    _fundPoolCtrl.dispose();
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
    final hasHeader = header.any((h) => ['id', 'patient_id', 'student_id', 'email', 'name', 'full_name', 'phone', 'emergency_contact', 'institution_id'].contains(h));
    final dataLines = hasHeader ? lines.sublist(1) : lines;

    int idIdx = header.indexWhere((h) => h == 'id' || h == 'patient_id' || h == 'student_id');
    int phoneIdx = header.indexWhere((h) => h == 'phone' || h == 'phone_number' || h == 'contact');
    int nameIdx = header.indexWhere((h) => h == 'name' || h == 'patient_name' || h == 'full_name');
    int emailIdx = header.indexWhere((h) => h == 'email' || h == 'patient_email');
    int emergencyIdx = header.indexWhere((h) => h == 'emergency_contact' || h == 'emergency');

    if (!hasHeader) {
      idIdx = 0;
      emailIdx = 1;
      phoneIdx = 2;
      nameIdx = 3;
    }

    for (int i = 0; i < dataLines.length; i++) {
      final parts = dataLines[i].split(',').map((p) => p.trim()).toList();
      if (parts.isEmpty || (parts.length == 1 && parts[0].isEmpty)) continue;

      final studentId = idIdx >= 0 && idIdx < parts.length && parts[idIdx].isNotEmpty ? parts[idIdx] : 'PAT-${1000 + i + 1}';
      final email = emailIdx >= 0 && emailIdx < parts.length && parts[emailIdx].isNotEmpty ? parts[emailIdx] : (parts.length > 1 ? parts[1] : 'patient_${i + 1}@campushealth.edu');
      final phone = phoneIdx >= 0 && phoneIdx < parts.length ? parts[phoneIdx] : '';
      
      String name = '';
      if (nameIdx >= 0 && nameIdx < parts.length && parts[nameIdx].isNotEmpty) {
        name = parts[nameIdx];
      } else {
        name = 'Patient ${i + 1}';
      }

      final emergency = emergencyIdx >= 0 && emergencyIdx < parts.length ? parts[emergencyIdx] : '';

      roster.add({
        'studentId': studentId,
        'email': email,
        'phone': phone,
        'name': name,
        'emergency': emergency,
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
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        }

        if (content.isNotEmpty) {
          _csvRawCtrl.text = content;
          _parseCsvText(content);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading CSV: $e')),
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final success = await auth.signupAdminWithRoster(
      instituteName: _instituteNameCtrl.text.trim(),
      adminName: _adminNameCtrl.text.trim(),
      adminEmail: _adminEmailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      institutionCode: _instCodeCtrl.text.trim(),
      department: _specialtyCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      initialFundPool: double.tryParse(_fundPoolCtrl.text.trim()) ?? 150000.0,
      defaultStudentPassword: _defaultStudentPasswordCtrl.text.trim(),
      rosterStudents: _parsedStudents,
    );

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Onboarding failed. Please retry.'),
          backgroundColor: AppTheme.emergencyRed,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.primaryBrand, size: 28),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Healthcare Facility Provisioned!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_instituteNameCtrl.text.trim()} successfully registered on MedAccess AI.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSlate,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Facility ID: ${_instCodeCtrl.text.trim()}', style: const TextStyle(fontSize: 12)),
                  Text('• Clinical Admin: ${_adminEmailCtrl.text.trim()}', style: const TextStyle(fontSize: 12)),
                  Text('• Provisioned Patients: ${_parsedStudents.length}', style: const TextStyle(fontSize: 12)),
                  Text('• Health Fund Pool: ₹${_fundPoolCtrl.text.trim()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Enter Clinical War Room'),
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
        backgroundColor: AppTheme.primaryBrand,
        foregroundColor: Colors.white,
        title: Text(
          'Healthcare Facility & Patient Onboarding',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
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
                                color: AppTheme.primaryBrand.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.local_hospital, color: AppTheme.primaryBrand, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Healthcare Facility Provisioning',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Register your hospital/clinic and import patient CSV roster for instant emergency access',
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
                          '1. HEALTHCARE FACILITY & CLINICAL ADMIN CREDENTIALS',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBrand,
                            letterSpacing: 0.5,
                          ),
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
                                    decoration: _buildInputDeco('Healthcare Facility Name', Icons.local_hospital_outlined, hintText: 'e.g. Apex Health & Medical Center'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _instCodeCtrl,
                                    decoration: _buildInputDeco('Facility Code / ID', Icons.tag, hintText: 'e.g. inst-001 or metro-health'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _adminNameCtrl,
                                    decoration: _buildInputDeco('Chief Medical Officer / Admin Name', Icons.person_outline, hintText: 'e.g. Dr. Sarah Chen, MD'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _specialtyCtrl,
                                    decoration: _buildInputDeco('Clinical Specialty & Department', Icons.medical_services_outlined, hintText: 'e.g. Emergency Medicine & Trauma Care'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _adminEmailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _buildInputDeco('Official Medical Email', Icons.email_outlined, hintText: 'e.g. admin@campushealth.edu'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: _buildInputDeco('Official Admin Phone', Icons.phone_outlined, hintText: 'e.g. +91 98111 22334'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: _obscurePassword,
                                    decoration: _buildInputDeco(
                                      'Admin Password',
                                      Icons.lock_outline,
                                      hintText: 'Enter secure admin password (min 6 chars)',
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 18),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _defaultStudentPasswordCtrl,
                                    decoration: _buildInputDeco('Default Patient Password (for CSV roster)', Icons.key, hintText: 'e.g. Patient@123'),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _fundPoolCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: _buildInputDeco('Initial Health Fund Pool (₹)', Icons.account_balance_wallet_outlined, hintText: 'e.g. 150000'),
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
                                        decoration: _buildInputDeco('Healthcare Facility Name', Icons.local_hospital_outlined, hintText: 'e.g. Apex Health & Medical Center'),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _instCodeCtrl,
                                        decoration: _buildInputDeco('Facility Code / ID', Icons.tag, hintText: 'e.g. inst-001 or metro-health'),
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
                                        decoration: _buildInputDeco('CMO / Admin Full Name', Icons.person_outline, hintText: 'e.g. Dr. Sarah Chen, MD'),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _specialtyCtrl,
                                        decoration: _buildInputDeco('Clinical Specialty & Department', Icons.medical_services_outlined, hintText: 'e.g. Emergency Medicine & Trauma Care'),
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
                                        controller: _adminEmailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: _buildInputDeco('Official Medical Email', Icons.email_outlined, hintText: 'e.g. admin@campushealth.edu'),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: _buildInputDeco('Official Admin Phone', Icons.phone_outlined, hintText: 'e.g. +91 98111 22334'),
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
                                        controller: _passwordCtrl,
                                        obscureText: _obscurePassword,
                                        decoration: _buildInputDeco(
                                          'Admin Password',
                                          Icons.lock_outline,
                                          hintText: 'Enter secure password (min 6 chars)',
                                          suffixIcon: IconButton(
                                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 18),
                                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                          ),
                                        ),
                                        validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _defaultStudentPasswordCtrl,
                                        decoration: _buildInputDeco('Default Patient Password', Icons.key, hintText: 'e.g. Patient@123'),
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
                                        controller: _fundPoolCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: _buildInputDeco('Initial Health Fund Pool (₹)', Icons.account_balance_wallet_outlined, hintText: 'e.g. 150000'),
                                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                  ],
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
                                '2. IMPORT PATIENT ROSTER (CSV)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBrand,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _csvRawCtrl.text = sampleCsvTemplate;
                                _parseCsvText(sampleCsvTemplate);
                              },
                              icon: const Icon(Icons.file_download_outlined, size: 14, color: AppTheme.primaryBrand),
                              label: const Text('Load Sample CSV', style: TextStyle(fontSize: 11, color: AppTheme.primaryBrand)),
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
                                icon: const Icon(Icons.upload_file, color: AppTheme.primaryBrand),
                                label: Text(
                                  _csvFileName != null ? 'File: $_csvFileName' : 'Upload Patient CSV (FilePicker)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBrand),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppTheme.primaryBrand, width: 1.5),
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
                            hintText: 'Paste CSV content (patient_id, name, email, phone, emergency_contact)',
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
                                'PARSED PATIENT ROSTER PREVIEW',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFBF1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_parsedStudents.length} Patients Ready',
                                style: GoogleFonts.outfit(color: AppTheme.primaryBrand, fontWeight: FontWeight.bold, fontSize: 12),
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
                                      child: Text('No patients parsed. Upload or paste CSV above.', style: TextStyle(color: Color(0xFF94A3B8))),
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
                                          backgroundColor: AppTheme.primaryBrand.withValues(alpha: 0.15),
                                          child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBrand)),
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
                                            s['phone']?.isNotEmpty == true ? s['phone']! : 'Verified',
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
                              backgroundColor: AppTheme.primaryBrand,
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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.health_and_safety, size: 20),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Provision Healthcare Facility & Patient Roster',
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

  InputDecoration _buildInputDeco(String label, IconData icon, {String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.primaryBrand, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1A1F1B2C))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1A1F1B2C))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryBrand, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
