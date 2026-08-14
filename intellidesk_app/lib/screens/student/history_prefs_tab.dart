import 'dart:convert' show base64Encode;
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../models/ticket.dart';
import '../../utils/currency_formatter.dart';

class HistoryPrefsTab extends StatelessWidget {
  const HistoryPrefsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesProvider>();
    final isHighContrast = prefs.isHighContrast;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 140),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreferencesCard(context, prefs, isHighContrast),
              const SizedBox(height: 28),
              _buildHistorySectionHeader(context, isHighContrast),
              const SizedBox(height: 14),
              _buildLiveHistoryList(context, isHighContrast),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context, PreferencesProvider prefs, bool isHighContrast) {
    final user = context.watch<AuthProvider>().user;

    return Card(
      elevation: isHighContrast ? 0 : 2,
      color: isHighContrast ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isHighContrast
            ? const BorderSide(color: Color(0xFF00E5FF), width: 2.5)
            : const BorderSide(color: Color(0x12000000), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune,
                    color: isHighContrast ? Colors.black : const Color(0xFFEE4D9F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account & Accessibility Preferences',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dynamic WCAG contrast, multi-language speech, and notifications.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isHighContrast ? const Color(0xFF334155) : const Color(0x1A1F1B2C),
            ),
            const SizedBox(height: 18),

            // 1. Language Dropdown
            Text(
              'UI & Speech-to-Text Language',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dictates AI guidance dialect and Whisper offline speech recognition.',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(prefs.selectedLanguage),
              initialValue: prefs.selectedLanguage,
              dropdownColor: isHighContrast ? const Color(0xFF1E293B) : Colors.white,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0x1A1F1B2C),
                    width: isHighContrast ? 2 : 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: isHighContrast ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
                prefixIcon: Icon(
                  Icons.language,
                  size: 20,
                  color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFF8B5CF6),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English (en)')),
                DropdownMenuItem(value: 'es', child: Text('Español (es)')),
                DropdownMenuItem(value: 'hi', child: Text('Hindi - हिन्दी (hi)')),
                DropdownMenuItem(value: 'zh', child: Text('Mandarin - 中文 (zh)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  prefs.setLanguage(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🌐 Language set to ${prefs.languageDisplayName}. Speech model updated.'),
                      backgroundColor: const Color(0xFF8B5CF6),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // 2. Preferred Contact Channel
            Text(
              'Preferred Contact Channel',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Disbursement alerts, emergency vouchers, and policy updates will route here.',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'EMAIL', label: Text('Email'), icon: Icon(Icons.email_outlined, size: 16)),
                ButtonSegment(value: 'SMS', label: Text('SMS'), icon: Icon(Icons.sms_outlined, size: 16)),
                ButtonSegment(value: 'WHATSAPP', label: Text('WhatsApp'), icon: Icon(Icons.chat_bubble_outline, size: 16)),
              ],
              selected: {prefs.preferredChannel},
              onSelectionChanged: (Set<String> newSelection) {
                final val = newSelection.first;
                prefs.setContactChannel(val);
                final dest = val == 'EMAIL' ? (user?.email ?? 'email') : (user?.phone ?? 'mobile');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📲 Notification routing updated to $val ($dest)'),
                    backgroundColor: const Color(0xFFEE4D9F),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isHighContrast
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFFEE4D9F).withValues(alpha: 0.15);
                  }
                  return isHighContrast ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isHighContrast ? Colors.black : const Color(0xFFEE4D9F);
                  }
                  return isHighContrast ? Colors.white : const Color(0xFF1F1B2C);
                }),
                side: WidgetStateProperty.all(
                  BorderSide(
                    color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0x1A1F1B2C),
                    width: isHighContrast ? 2 : 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isHighContrast ? const Color(0xFF334155) : const Color(0x1A1F1B2C),
            ),
            const SizedBox(height: 10),

            // 3. High-Contrast Switch
            SwitchListTile(
              title: Text(
                'High-Contrast Mode (WCAG 2.1 AAA)',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
                ),
              ),
              subtitle: Text(
                'Enhances stark borders, vivid cyan accents, and high-visibility typography.',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
              ),
              value: prefs.isHighContrast,
              activeThumbColor: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFFEE4D9F),
              activeTrackColor: isHighContrast ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : const Color(0xFFEE4D9F).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
              onChanged: (val) {
                prefs.toggleHighContrast(val);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val ? '👁️ High-contrast mode activated (WCAG 2.1 AAA)' : '👁️ Standard mode restored'),
                    backgroundColor: const Color(0xFF1F1B2C),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),

            // 4. Real-Time Alerts Switch
            SwitchListTile(
              title: Text(
                'Real-Time Emergency Alerts',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
                ),
              ),
              subtitle: Text(
                'Instant push and socket notifications for grant adjudication decisions.',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
              ),
              value: prefs.realTimeAlerts,
              activeThumbColor: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFF8B5CF6),
              activeTrackColor: isHighContrast ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
              onChanged: (val) {
                prefs.toggleEmergencyAlerts(val);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val ? '🔔 Real-time alerts enabled' : '🔕 Real-time alerts muted'),
                    backgroundColor: const Color(0xFF8B5CF6),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySectionHeader(BuildContext context, bool isHighContrast) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt_long,
                color: isHighContrast ? Colors.black : const Color(0xFFEE4D9F),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Emergency Requests & Vouchers',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
              ),
            ),
          ],
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFFEE4D9F),
          ),
          tooltip: 'Refresh Records',
          onPressed: () {
            context.read<TicketProvider>().init();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Syncing latest emergency requests & vouchers...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLiveHistoryList(BuildContext context, bool isHighContrast) {
    final user = context.watch<AuthProvider>().user;
    final allTickets = context.watch<TicketProvider>().tickets;

    // Filter strictly for the logged-in student
    final studentTickets = allTickets.where((t) {
      if (user == null) return false;
      final phoneMatch = user.phone?.isNotEmpty == true && t.studentPhone.contains(user.phone!);
      final emailMatch = user.email.isNotEmpty && (t.studentPhone.contains(user.email) || t.rawMessage.toLowerCase().contains(user.email.toLowerCase()));
      final nameMatch = user.name.isNotEmpty && t.rawMessage.toLowerCase().contains(user.name.toLowerCase());
      final idMatch = t.id.toLowerCase().contains(user.id.toLowerCase());
      return phoneMatch || emailMatch || nameMatch || idMatch;
    }).toList();

    if (studentTickets.isEmpty) {
      return Card(
        color: isHighContrast ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0x12000000),
            width: isHighContrast ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHighContrast ? const Color(0xFF1E293B) : const Color(0xFFEE4D9F).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFFEE4D9F),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Emergency Records Yet',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No active emergency relief requests or digital vouchers on file for ${user?.name ?? 'your student account'}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: studentTickets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ticket = studentTickets[index];
        return _buildTicketCard(context, ticket, isHighContrast);
      },
    );
  }

  Widget _buildTicketCard(BuildContext context, Ticket ticket, bool isHighContrast) {
    Color statusColor;
    String displayStatus = ticket.status;

    switch (ticket.status) {
      case 'Auto-Approved':
      case 'Approved':
        statusColor = const Color(0xFF10B981);
        displayStatus = 'Approved';
        break;
      case 'Resolved':
        statusColor = const Color(0xFF3B82F6);
        break;
      case 'Escalated':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'Denied':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF8B5CF6);
        displayStatus = 'Pending';
    }

    final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(ticket.createdAt);
    final voucherCode = ticket.voucherCode ?? (ticket.status == 'Auto-Approved' ? 'VCH-${ticket.id.substring(0, 8).toUpperCase()}' : null);

    return Card(
      elevation: isHighContrast ? 0 : 2,
      color: isHighContrast ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0x12000000),
          width: isHighContrast ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.receipt_outlined, color: statusColor),
        ),
        title: Text(
          ticket.parsedCategory,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isHighContrast ? Colors.white : const Color(0xFF1F1B2C),
          ),
        ),
        subtitle: Builder(
          builder: (context) {
            final double displayAmt = (ticket.recommendedGrantAmount != null && ticket.recommendedGrantAmount! > 0)
                ? ticket.recommendedGrantAmount!
                : ticket.calculatedAmount;
            return Text(
              '$formattedDate • ${CurrencyFormatter.format(displayAmt, currency: ticket.currency, decimalDigits: 2)}',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              ),
            );
          },
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            displayStatus,
            style: GoogleFonts.outfit(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Divider(
            height: 1,
            color: isHighContrast ? const Color(0xFF334155) : const Color(0x1A1F1B2C),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Matched policy clause
                if (ticket.policyMatchReason != null && ticket.policyMatchReason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isHighContrast ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gavel, size: 14, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 6),
                            Text(
                              'Adjudication Reasoning & Policy Match',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isHighContrast ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.policyMatchReason!,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Digital Voucher Card if available
                if (voucherCode != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHighContrast ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isHighContrast ? const Color(0xFF10B981) : const Color(0xFFA7F3D0),
                        width: isHighContrast ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(6),
                          child: QrImageView(
                            data: voucherCode,
                            version: QrVersions.auto,
                            size: 72.0,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Emergency Voucher',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isHighContrast ? Colors.white : const Color(0xFF065F46),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Code: $voucherCode',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isHighContrast ? const Color(0xFF34D399) : const Color(0xFF047857),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Scan directly at campus vendor or bursar desk.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isHighContrast ? const Color(0xFFCBD5E1) : const Color(0xFF065F46).withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Document Attachment
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                      withData: true,
                    );
                    if (res != null && res.files.isNotEmpty && context.mounted) {
                      final file = res.files.first;
                      Uint8List? bytes = file.bytes;
                      if ((bytes == null || bytes.isEmpty) && file.path != null && !kIsWeb) {
                        final f = File(file.path!);
                        if (f.existsSync()) {
                          bytes = await f.readAsBytes();
                        }
                      }
                      if (bytes != null && bytes.isNotEmpty) {
                        try {
                          final uri = Uri.parse('${ApiConfig.baseUrl}/intake/web');
                          final req = http.MultipartRequest('POST', uri);
                          req.headers['x-institution-id'] = ApiConfig.institutionId;
                          req.fields['studentContact'] = ticket.studentPhone;
                          req.fields['message'] = 'Additional receipt/document for ticket #${ticket.id.substring(0, 8)}';
                          final mimeType = file.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
                          final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
                          req.fields['media_url'] = dataUri;
                          req.files.add(http.MultipartFile.fromBytes('attachment', bytes, filename: file.name));
                          await req.send();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Document "${file.name}" uploaded to receipts bucket & processed!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload notice: $e')),
                            );
                          }
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Attach Additional Receipts / Documents'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isHighContrast ? const Color(0xFF00E5FF) : const Color(0xFF1F1B2C),
                    side: BorderSide(
                      color: isHighContrast ? const Color(0xFF00E5FF) : const Color(0x2A1F1B2C),
                      width: isHighContrast ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
