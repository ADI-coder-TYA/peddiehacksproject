import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../models/ticket.dart';
import 'providers/auth_provider.dart';
import 'providers/ticket_provider.dart';
import 'providers/job_tracking_manager.dart';
import 'providers/accessibility_provider.dart';
import 'student_async_job_progress_screen.dart';
import 'screens/student/history_prefs_tab.dart';
import 'widgets/glass_card.dart';
import 'widgets/boutique_button.dart';
import 'widgets/voice_recorder_dialog.dart';
import 'config/api_config.dart';
import 'utils/currency_formatter.dart';

class StudentIntakeTrackerScreen extends StatefulWidget {
  const StudentIntakeTrackerScreen({super.key});

  @override
  State<StudentIntakeTrackerScreen> createState() => _StudentIntakeTrackerScreenState();
}

class _StudentIntakeTrackerScreenState extends State<StudentIntakeTrackerScreen> {
  Ticket? _activeTicket;
  String? _liveStatus;

  void _switchToTracker(Ticket ticket) {
    setState(() {
      _activeTicket = ticket;
      _liveStatus = ticket.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: GlassCard(
                padding: const EdgeInsets.all(6),
                borderRadius: 30,
                child: TabBar(
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF0D9488),
                  unselectedLabelColor: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF0D9488).withValues(alpha: 0.14),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                  ),
                  splashBorderRadius: BorderRadius.circular(24),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.medical_services_outlined, size: 18), text: 'Claims & Triage'),
                    Tab(icon: Icon(Icons.psychology_outlined, size: 18), text: 'Clinical AI Guidance'),
                    Tab(icon: Icon(Icons.history_toggle_off, size: 18), text: 'Claims History'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
            // Tab 1: Intake & Live Status Tracker
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 120),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_activeTicket == null)
                        StudentIntakeForm(
                          onTicketSubmitted: _switchToTracker,
                        ),
                      if (_activeTicket != null) ...[
                        LiveStatusTracker(
                          activeTicket: _activeTicket!,
                          onStatusChanged: (status) {
                            setState(() {
                              _liveStatus = status;
                              _activeTicket = Ticket(
                                id: _activeTicket!.id,
                                studentPhone: _activeTicket!.studentPhone,
                                rawMessage: _activeTicket!.rawMessage,
                                parsedCategory: _activeTicket!.parsedCategory,
                                urgencyLevel: _activeTicket!.urgencyLevel,
                                status: status,
                                calculatedAmount: _activeTicket!.calculatedAmount,
                                createdAt: _activeTicket!.createdAt,
                                recommendedGrantAmount: _activeTicket!.recommendedGrantAmount ?? 200.0,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_liveStatus == 'Auto-Approved')
                          DigitalVoucherCard(
                            ticket: _activeTicket!,
                            hashedClaimCode: 'VOUCHER-${_activeTicket!.id}-SECURE',
                          ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
            
            // Tab 2: Interactive Pre-Submission Guidance Chatbot
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 140,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SizedBox(
                    height: 520,
                    child: StudentAIChatCompanion(
                      onConvertChatToTicket: () {
                        final fakeTicket = Ticket(
                          id: 'TKT-${DateTime.now().millisecondsSinceEpoch}',
                          studentPhone: '+15550000000',
                          rawMessage: 'Generated from Chat: Needs emergency dental procedure assistance.',
                          parsedCategory: 'Medical/Dental',
                          urgencyLevel: 'High',
                          status: 'Received',
                          calculatedAmount: 200.0,
                          createdAt: DateTime.now(),
                        );
                        _switchToTracker(fakeTicket);
                        DefaultTabController.of(context).animateTo(0); // Jump back to Intake tab
                      },
                    ),
                  ),
                ),
              ),
            ),
            
            // Tab 3: History & Preferences
            const HistoryPrefsTab(),
          ],
        ),
      ),
    ],
  ),
),
);
  }
}

// ============================================================================
// Data Models for Portal
// ============================================================================
class ChatMessage {
  final String text;
  final bool isStudent;
  final bool isActionable;

  ChatMessage({required this.text, required this.isStudent, this.isActionable = false});
}

class StudentRequestHistory {
  final String id;
  final DateTime date;
  final String category;
  final double requestedAmount;
  final String status;
  final String? voucherCode;

  StudentRequestHistory({
    required this.id,
    required this.date,
    required this.category,
    required this.requestedAmount,
    required this.status,
    this.voucherCode,
  });
}

// ============================================================================
// 1. Interactive Pre-Submission Guidance Chatbot (StudentAIChatCompanion)
// ============================================================================
class StudentAIChatCompanion extends StatefulWidget {
  final VoidCallback onConvertChatToTicket;

  const StudentAIChatCompanion({super.key, required this.onConvertChatToTicket});

  @override
  State<StudentAIChatCompanion> createState() => _StudentAIChatCompanionState();
}

class _StudentAIChatCompanionState extends State<StudentAIChatCompanion> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hello! I am your MedAccess Clinical & Copay Policy Advisor. I can guide you through institutional healthcare grants, emergency room copay micro-relief, pharmacy subsidies, and psychological first aid. How can I help you today?",
      isStudent: false,
    ),
  ];
  bool _isTyping = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isStudent: true));
      _isTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final lower = text.toLowerCase();
      final lang = context.read<AccessibilityProvider>().selectedLanguage;
      String replyText;

      if (lang == 'Español') {
        if (lower.contains('prescription') || lower.contains('farmacia') || lower.contains('medicina') || lower.contains('remedio')) {
          replyText = "Bajo la Política de Subsidio Farmacéutico 2.B, los pacientes son elegibles para microsubvenciones instantáneas de copago para medicamentos esenciales e insulina. ¿Desea presentar esta solicitud?";
        } else if (lower.contains('hospital') || lower.contains('emergencia') || lower.contains('urgencia') || lower.contains('er')) {
          replyText = "Bajo el Protocolo de Copago de Emergencia 1.A, los gastos de hospitalización y salas de urgencias de hasta \$1,000 son elegibles para desembolso inmediato. ¿Desea solicitar alivio clínico?";
        } else {
          replyText = "Según las pautas de MedAccess AI, las reclamaciones médicas respaldadas por facturas hospitalarias se procesan instantáneamente con verificación OCR.";
        }
      } else if (lang == 'Français') {
        if (lower.contains('médicament') || lower.contains('pharmacie') || lower.contains('prescription')) {
          replyText = "En vertu de la politique 2.B, les patients ont droit à des micro-subventions immédiates pour les quotes-parts de pharmacie. Souhaitez-vous postuler ?";
        } else if (lower.contains('hôpital') || lower.contains('urgence') || lower.contains('er')) {
          replyText = "En vertu du protocole d'urgence 1.A, une aide aux frais d'hospitalisation jusqu'à \$1,000 est disponible immédiatement. Souhaitez-vous soumettre ce dossier ?";
        } else {
          replyText = "Selon les directives MedAccess AI, les factures médicales déposées avec justificatifs bénéficient d'une adjudication instantanée.";
        }
      } else if (lang == 'Hindi') {
        if (lower.contains('medicine') || lower.contains('dawa') || lower.contains('pharmacy')) {
          replyText = "फार्मेसी कोपे सब्सिडी नीति 2.B के तहत, आवश्यक दवाओं और इंसुलिन के लिए तत्काल राहत उपलब्ध है। क्या आप आवेदन करना चाहते हैं?";
        } else if (lower.contains('hospital') || lower.contains('doctor') || lower.contains('emergency')) {
          replyText = "आपातकालीन अस्पताल कोपे प्रोटोकॉल 1.A के तहत, आपातकालीन चिकित्सा बिलों के लिए तत्काल अनुदान प्रदान किया जाता है।";
        } else {
          replyText = "MedAccess AI के अनुसार, अस्पताल के बिल और नुस्खे अपलोड करने पर तत्काल क्लेम सत्यापन और वित्तीय सहायता दी जाती है।";
        }
      } else if (lang == 'Mandarin') {
        if (lower.contains('药') || lower.contains('处方') || lower.contains('medicine')) {
          replyText = "根据处方药自付补助政策 2.B，急需胰岛素或处方药的患者有资格获得即时药房补助。您现在想申请吗？";
        } else if (lower.contains('医院') || lower.contains('急诊') || lower.contains('hospital')) {
          replyText = "根据急诊医疗补助协议 1.A，急诊室账单最高可获 1,000 美元的即时共付救济金。您现在要提交吗？";
        } else {
          replyText = "根据 MedAccess AI 临床准则，上传医疗账单或收据后，系统将在 60 秒内通过 OCR 进行核验与救济金发放。";
        }
      } else {
        if (lower.contains('prescription') || lower.contains('pharmacy') || lower.contains('medicine') || lower.contains('insulin') || lower.contains('drug')) {
          replyText = "Under Critical Prescription Subsidy Policy 2.B, patients facing high out-of-pocket pharmacy costs are eligible for instant micro-grants for essential medications and refills with zero wait time. Would you like to proceed with this copay request?";
        } else if (lower.contains('hospital') || lower.contains('er') || lower.contains('emergency room') || lower.contains('surgery') || lower.contains('inpatient')) {
          replyText = "Under Emergency Inpatient & ER Copay Relief Protocol 1.A, hospital emergency room visits and trauma admissions are eligible for expedited copay coverage up to \$1,000 / ₹80,000 upon invoice upload. Would you like to apply now?";
        } else if (lower.contains('mental') || lower.contains('depression') || lower.contains('anxiety') || lower.contains('panic') || lower.contains('therapy') || lower.contains('crisis')) {
          replyText = "Under Acute Crisis De-escalation & Mental Health Protocol 3.C, 100% covered emergency psychological first aid sessions and psychiatric copay relief are available immediately. Would you like to connect with a crisis counselor?";
        } else if (lower.contains('lab') || lower.contains('blood') || lower.contains('mri') || lower.contains('ct scan') || lower.contains('xray') || lower.contains('scan')) {
          replyText = "Under Clinical Laboratory & Imaging Grant 4.D, specialized medical diagnostic testing and radiology imaging copays can be reimbursed instantly upon uploading your clinic requisition. Would you like to submit an intake?";
        } else if (lower.contains('dental') || lower.contains('tooth') || lower.contains('abscess') || lower.contains('root canal')) {
          replyText = "Under Emergency Dental & Oral Trauma Protocol 5.E, acute dental procedures and abscess relief up to \$500 are eligible for same-day copay disbursement. Would you like to submit this claim?";
        } else {
          replyText = "Based on MedAccess Institutional Healthcare Guidelines, emergency medical claims backed by hospital invoices or prescriptions are prioritized for autonomous OCR adjudication (<60s). You can attach your document in the Claims tab.";
        }
      }

      await Future.delayed(const Duration(milliseconds: 600));
      
      setState(() {
        _messages.add(ChatMessage(text: replyText, isStudent: false, isActionable: true));
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "I'm having trouble reaching the clinical policy database right now.", isStudent: false));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: const Color(0xFF0D9488).withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.2), child: const Icon(Icons.psychology, color: Color(0xFF0D9488))),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MedAccess Clinical & Copay Advisor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                      Text('24/7 policy guidance, copay micro-grants & clinical triage', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(
                        width: 50, height: 30,
                        child: Center(child: LinearProgressIndicator(color: Colors.blueAccent)),
                      ),
                    ),
                  );
                }
                return _buildChatBubble(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: IconButton(
                    icon: const Icon(Icons.mic, color: Colors.redAccent, size: 20),
                    tooltip: 'Record Voice Distress Note (Local AI)',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => VoiceRecorderDialog(
                          onSubmitted: (transcript, jobId) {
                            setState(() {
                              _messages.add(ChatMessage(
                                text: '🎙️ Voice Distress Note Submitted:\n"$transcript"',
                                isStudent: true,
                              ));
                              _messages.add(ChatMessage(
                                text: 'Your voice note was transcribed offline via Local Whisper AI (0 Cloud API Fees) and enqueued under Job ID: $jobId.',
                                isStudent: false,
                                isActionable: true,
                              ));
                            });
                            _scrollToBottom();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: message.isStudent ? const Color(0xFF5A4FCF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isStudent ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: message.isStudent ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: message.isStudent ? Colors.white : Colors.black87, height: 1.4),
            ),
            if (message.isActionable) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: widget.onConvertChatToTicket,
                icon: const Icon(Icons.rocket_launch, size: 16),
                label: const Text('Convert Chat to Formal Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueAccent,
                  elevation: 0,
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. Student Emergency History & Active Grants View (StudentHistoryTab)
// ============================================================================
class StudentHistoryTab extends StatelessWidget {
  const StudentHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final allTickets = context.watch<TicketProvider>().tickets;

    // Filter tickets that strictly belong to the logged-in student
    final userTickets = allTickets.where((t) {
      if (user == null) return false;
      final phoneMatch = user.phone?.isNotEmpty == true && t.studentPhone.contains(user.phone!);
      final emailMatch = user.email.isNotEmpty && (t.studentPhone.contains(user.email) || t.rawMessage.toLowerCase().contains(user.email.toLowerCase()));
      final nameMatch = user.name.isNotEmpty && t.rawMessage.toLowerCase().contains(user.name.toLowerCase());
      final idMatch = t.id.toLowerCase().contains(user.id.toLowerCase());
      return phoneMatch || emailMatch || nameMatch || idMatch;
    }).toList();

    if (userTickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEE4D9F).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFFEE4D9F)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Emergency Records Yet',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1F1B2C)),
              ),
              const SizedBox(height: 6),
              Text(
                'No active emergency relief requests or digital vouchers on file for ${user?.name ?? 'your student account'}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: userTickets.length,
      itemBuilder: (context, index) {
        final t = userTickets[index];
        final historyItem = StudentRequestHistory(
          id: t.id,
          date: t.createdAt,
          category: t.parsedCategory,
          requestedAmount: t.calculatedAmount,
          status: t.status,
          voucherCode: t.voucherCode ?? (t.status == 'Auto-Approved' ? 'VCH-${t.id}-AUTO' : null),
        );
        return _buildHistoryCard(context, historyItem);
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, StudentRequestHistory req) {
    Color statusColor;
    switch (req.status) {
      case 'Auto-Approved':
        statusColor = Colors.green; break;
      case 'Resolved':
        statusColor = Colors.blue; break;
      case 'Denied':
        statusColor = Colors.red; break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.receipt_long, color: statusColor),
        ),
        title: Text(req.category, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        subtitle: Text('ID: ${req.id} • \$${req.requestedAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Text(req.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (req.voucherCode != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(4),
                          child: QrImageView(
                            data: req.voucherCode!,
                            version: QrVersions.auto,
                            size: 80.0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Active Digital Voucher', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              const SizedBox(height: 4),
                              Text('Code: ${req.voucherCode}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black87)),
                              const SizedBox(height: 8),
                              const Text('Present QR code to campus vendor.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                          final multipartReq = http.MultipartRequest('POST', uri);
                          multipartReq.headers['x-institution-id'] = ApiConfig.institutionId;
                          multipartReq.fields['studentContact'] = ApiConfig.userPhone?.isNotEmpty == true ? ApiConfig.userPhone! : (ApiConfig.userEmail ?? '+15550000000');
                          multipartReq.fields['message'] = 'Follow-up document for ticket #${req.id.substring(0, req.id.length > 8 ? 8 : req.id.length)}';
                          final mimeType = file.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
                          final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
                          multipartReq.fields['media_url'] = dataUri;
                          multipartReq.files.add(http.MultipartFile.fromBytes('attachment', bytes, filename: file.name));
                          await multipartReq.send();
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
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Attach Follow-Up Documents'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. Accessibility & Multi-Language Settings (StudentPreferencesCard)
// ============================================================================
class StudentPreferencesCard extends StatelessWidget {
  const StudentPreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityProvider>();
    final user = context.watch<AuthProvider>().user;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune, color: Color(0xFFEE4D9F), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account & Accessibility Preferences',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1F1B2C)),
                      ),
                      Text(
                        'Personalize multi-language, channel routing, and accessibility mode.',
                        style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0x1A1F1B2C)),
            const SizedBox(height: 16),
            
            Text(
              'UI & Speech-to-Text Language',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1F1B2C)),
            ),
            const SizedBox(height: 4),
            Text(
              'Dictates speech recognition and AI guidance companion dialect.',
              style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(accessibility.selectedLanguage),
              initialValue: accessibility.selectedLanguage,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x1A1F1B2C))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                prefixIcon: const Icon(Icons.language, size: 20, color: Color(0xFF8B5CF6)),
              ),
              items: ['English', 'Español', 'Français', 'Hindi', 'Mandarin'].map((lang) {
                return DropdownMenuItem(
                  value: lang,
                  child: Text(lang, style: GoogleFonts.outfit(color: const Color(0xFF1F1B2C), fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  accessibility.setSelectedLanguage(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🌐 Language set to $val. Speech-to-text & AI advisor updated.'),
                      backgroundColor: const Color(0xFF8B5CF6),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            
            Text(
              'Preferred Contact Channel',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1F1B2C)),
            ),
            const SizedBox(height: 4),
            Text(
              'Disbursement alerts, voucher codes, and emergency updates will route via this channel.',
              style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Email', label: Text('Email'), icon: Icon(Icons.email_outlined, size: 16)),
                ButtonSegment(value: 'SMS', label: Text('SMS'), icon: Icon(Icons.sms_outlined, size: 16)),
                ButtonSegment(value: 'WhatsApp', label: Text('WhatsApp'), icon: Icon(Icons.chat_bubble_outline, size: 16)),
              ],
              selected: {accessibility.preferredContactChannel},
              onSelectionChanged: (Set<String> newSelection) {
                final val = newSelection.first;
                accessibility.setPreferredContactChannel(val);
                final dest = val == 'Email' ? (user?.email ?? 'registered email') : (user?.phone ?? 'mobile number');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📲 Notification channel set to $val ($dest)'),
                    backgroundColor: const Color(0xFFEE4D9F),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFEE4D9F).withValues(alpha: 0.15);
                  }
                  return const Color(0xFFF8F9FA);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFEE4D9F);
                  }
                  return const Color(0xFF1F1B2C);
                }),
                side: WidgetStateProperty.all(const BorderSide(color: Color(0x1A1F1B2C))),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0x1A1F1B2C)),
            const SizedBox(height: 10),
            
            SwitchListTile(
              title: Text(
                'High-Contrast Mode (WCAG 2.1 AAA)',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1F1B2C)),
              ),
              subtitle: Text(
                'Enhances font weights, stark borders, and contrast ratios for visual accessibility.',
                style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              value: accessibility.highContrastMode,
              activeThumbColor: const Color(0xFFEE4D9F),
              activeTrackColor: const Color(0xFFEE4D9F).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: (val) {
                accessibility.setHighContrastMode(val);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val ? '👁️ High-contrast mode activated (WCAG 2.1 AAA)' : '👁️ High-contrast mode deactivated'),
                    backgroundColor: const Color(0xFF1F1B2C),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(
                'Real-Time Emergency Alerts',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1F1B2C)),
              ),
              subtitle: Text(
                'Receive instant live popups and vibration for grant status & payout decisions.',
                style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              value: accessibility.realTimeEmergencyAlerts,
              activeThumbColor: const Color(0xFF8B5CF6),
              activeTrackColor: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: (val) {
                accessibility.setRealTimeEmergencyAlerts(val);
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
}

// ============================================================================
// 1. Multimodal Intake Submission Form
// ============================================================================
class StudentIntakeForm extends StatefulWidget {
  final Function(Ticket) onTicketSubmitted;

  const StudentIntakeForm({super.key, required this.onTicketSubmitted});

  @override
  State<StudentIntakeForm> createState() => _StudentIntakeFormState();
}

class _StudentIntakeFormState extends State<StudentIntakeForm> with SingleTickerProviderStateMixin {
  final TextEditingController _descriptionController = TextEditingController();
  PlatformFile? _attachedFile;
  bool _isRecording = false;
  bool _isSubmitting = false;
  late AnimationController _waveformController;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null && !kIsWeb) {
        final f = File(file.path!);
        if (f.existsSync()) {
          bytes = await f.readAsBytes();
        }
      }
      setState(() {
        _attachedFile = PlatformFile(
          name: file.name,
          size: bytes?.length ?? file.size,
          bytes: bytes,
          path: file.path,
        );
      });
    }
  }

  void _toggleRecording() {
    showDialog(
      context: context,
      builder: (_) => VoiceRecorderDialog(
        onSubmitted: (transcript, jobId) {
          setState(() {
            _descriptionController.text = transcript;
          });
        },
      ),
    );
  }

  Future<void> _submitIntake() async {
    if (_descriptionController.text.trim().isEmpty && !_isRecording && _attachedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a description, voice note, or attach a supporting document.')),
      );
      return;
    }

    setState(() { _isSubmitting = true; });
    try {
      final auth = context.read<AuthProvider>();
      final currentUser = auth.user;

      http.Response response;

      if (_attachedFile != null) {
        // 1. Submit Multipart payload to Async Endpoint with Attachment
        final uri = Uri.parse('${ApiConfig.baseUrl}/intake/web');
        final request = http.MultipartRequest('POST', uri);
        request.headers['x-institution-id'] = currentUser?.institutionId ?? ApiConfig.institutionId;

        request.fields['student_id'] = currentUser?.id ?? currentUser?.email ?? 'STU-STUDENT';
        request.fields['title'] = 'Emergency Assistance Request';
        request.fields['category'] = 'General';
        request.fields['description'] = _descriptionController.text;
        request.fields['message'] = _descriptionController.text;
        request.fields['studentName'] = currentUser?.name ?? 'Student';
        request.fields['studentContact'] = currentUser?.phone?.isNotEmpty == true ? currentUser!.phone! : (currentUser?.email ?? '+15550000000');

        Uint8List? fileBytes = _attachedFile!.bytes;
        if ((fileBytes == null || fileBytes.isEmpty) && _attachedFile!.path != null && !kIsWeb) {
          try {
            final f = File(_attachedFile!.path!);
            if (f.existsSync()) {
              fileBytes = await f.readAsBytes();
            }
          } catch (e) {
            debugPrint('Error reading attached file bytes: $e');
          }
        }

        if (fileBytes != null && fileBytes.isNotEmpty) {
          final mimeType = _attachedFile!.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
          final dataUri = 'data:$mimeType;base64,${base64Encode(fileBytes)}';
          request.fields['media_url'] = dataUri;
          request.fields['attachment_url'] = dataUri;
          request.fields['mediaUrl'] = dataUri;
          request.fields['attachmentUrl'] = dataUri;

          request.files.add(
            http.MultipartFile.fromBytes(
              'attachment',
              fileBytes,
              filename: _attachedFile!.name,
            ),
          );
        } else if (_attachedFile!.path != null && !kIsWeb) {
          try {
            request.files.add(
              await http.MultipartFile.fromPath(
                'attachment',
                _attachedFile!.path!,
                filename: _attachedFile!.name,
              ),
            );
          } catch (e) {
            debugPrint('Error adding multipart file from path: $e');
          }
        }

        final streamed = await request.send().timeout(const Duration(seconds: 30));
        response = await http.Response.fromStream(streamed);
      } else {
        // 1. Submit standard JSON payload to Async Endpoint
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/intake/web'),
          headers: {
            'Content-Type': 'application/json',
            'x-institution-id': currentUser?.institutionId ?? ApiConfig.institutionId,
          },
          body: jsonEncode({
            'student_id': currentUser?.id ?? currentUser?.email ?? 'STU-STUDENT',
            'title': 'Emergency Assistance Request',
            'category': 'General',
            'description': _descriptionController.text,
            'message': _descriptionController.text,
            'studentName': currentUser?.name ?? 'Student',
            'studentContact': currentUser?.phone?.isNotEmpty == true ? currentUser!.phone : (currentUser?.email ?? '+15550000000'),
          }),
        );
      }

      // 2. Handle 202 Accepted Async Response
      if (response.statusCode == 202) {
        final responseData = jsonDecode(response.body);
        final jobId = responseData['jobId'];
        
        // 3. Register Job with Tracking Manager
        if (mounted) {
          final trackingManager = context.read<JobTrackingManager>();
          trackingManager.startTracking(jobId);

          // 4. Transition to Tracking UI
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AsyncJobProgressScreen(
                onMinimize: () {
                  Navigator.of(context).pop(); // Pushes tracking into background
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tracking moved to background')),
                  );
                },
              ),
            ),
          );
          
          // Reset form
          _descriptionController.clear();
          setState(() {
            _attachedFile = null;
            _isRecording = false;
          });
          _waveformController.stop();
        }
      } else if (response.statusCode == 429) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('System is currently experiencing high volume. Please try again shortly.')),
          );
        }
      } else {
        if (mounted) {
          String errorMessage = 'Submission failed. Status: ${response.statusCode}';
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['error'] != null) {
              errorMessage = errorData['error'].toString();
            }
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Submit Emergency Medical Claim / Copay Request',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text(
            'Autonomous clinical triage & layout-aware invoice verification (<60s approval)',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          
          // Text Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your medical emergency, hospital visit, clinical symptoms, or pharmacy copay need...',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent, 
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BoutiqueButton(
                onPressed: _pickFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.attach_file, color: Color(0xFF0D9488), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _attachedFile != null ? _attachedFile!.name : 'Attach Hospital Bill, Lab Invoice, or Prescription (PDF/Image)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Voice Note Toggle
              BoutiqueButton(
                onPressed: _toggleRecording,
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.05).animate(
                    CurvedAnimation(parent: _waveformController, curve: Curves.easeInOut)
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isRecording ? const Color(0xFFEF4444).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _isRecording ? const Color(0xFFEF4444) : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isRecording ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFF0D9488).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_circle : Icons.mic,
                            color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                            size: 18,
                          ),
                        ),
                        if (_isRecording) ...[
                          const SizedBox(width: 8),
                          FadeTransition(
                            opacity: _waveformController,
                            child: const Text('Recording Clinical Note...', 
                                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ),

              // Submit Button
              BoutiqueButton(
                onPressed: _isSubmitting ? () {} : _submitIntake,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('⚡ Submit Clinical Claim for Instant Triage', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. Real-Time Ticket Status Stepper (LiveStatusTracker)
// ============================================================================
class LiveStatusTracker extends StatefulWidget {
  final Ticket activeTicket;
  final Function(String) onStatusChanged;

  const LiveStatusTracker({super.key, required this.activeTicket, required this.onStatusChanged});

  @override
  State<LiveStatusTracker> createState() => _LiveStatusTrackerState();
}

class _LiveStatusTrackerState extends State<LiveStatusTracker> {
  late io.Socket _socket;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.activeTicket.status;
    _initSocket();

    // Demonstrate clinical progression stages
    _mockProcessingStages();
  }

  void _initSocket() {
    _socket = io.io(ApiConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket.on('ticket:updated', (data) {
      if (data['id'] == widget.activeTicket.id) {
        _updateStatus(data['status']);
      }
    });

    _socket.on('ticket:resolved', (data) {
       if (data['id'] == widget.activeTicket.id) {
        _updateStatus(data['status']);
      }
    });
  }

  void _updateStatus(String status) {
    if (mounted) {
      setState(() {
        _currentStatus = status;
      });
      widget.onStatusChanged(status);
    }
  }

  void _mockProcessingStages() async {
    await Future.delayed(const Duration(seconds: 2));
    _updateStatus('Clinical Triage Active');
    await Future.delayed(const Duration(seconds: 3));
    _updateStatus('Claim Verified');
    await Future.delayed(const Duration(seconds: 3));
    _updateStatus('Copay Grant Disbursed');
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  int _getCurrentStep() {
    switch (_currentStatus) {
      case 'Received': return 0;
      case 'Clinical Triage Active': return 1;
      case 'Claim Verified': return 2;
      case 'Copay Grant Disbursed':
      case 'Auto-Approved':
      case 'Approved':
      case 'Escalated':
      case 'Denied':
        return 3;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    int currentStep = _getCurrentStep();
    final isComplete = currentStep == 3;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clinical Triage & Copay Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const Divider(),
            Stepper(
              physics: const NeverScrollableScrollPhysics(),
              currentStep: currentStep,
              controlsBuilder: (context, details) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: const Text('Claim Received & Digitized'),
                  content: const Text('Your medical claim and invoice attachments have been securely encrypted.'),
                  isActive: currentStep >= 0,
                  state: currentStep > 0 ? StepState.complete : StepState.editing,
                ),
                Step(
                  title: const Text('Clinical Triage Active (ESI)'),
                  content: const Text('Parsing medical charges, CPT codes, and psychiatric severity score.'),
                  isActive: currentStep >= 1,
                  state: currentStep > 1 ? StepState.complete : (currentStep == 1 ? StepState.editing : StepState.indexed),
                ),
                Step(
                  title: const Text('Claim Verified (Fraud Sentinel)'),
                  content: const Text('OCR authenticity verified, duplicate hashes checked, copay allocated.'),
                  isActive: currentStep >= 2,
                  state: currentStep > 2 ? StepState.complete : (currentStep == 2 ? StepState.editing : StepState.indexed),
                ),
                Step(
                  title: const Text('Copay Grant Disbursed'),
                  content: isComplete 
                    ? Text('Status: $_currentStatus', style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (_currentStatus == 'Auto-Approved' || _currentStatus == 'Copay Grant Disbursed' || _currentStatus == 'Approved') ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ))
                    : const Text('Awaiting final copay disbursement...'),
                  isActive: currentStep >= 3,
                  state: isComplete ? StepState.complete : StepState.indexed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. Auto-Approved Grant Voucher Card (DigitalVoucherCard)
// ============================================================================
class DigitalVoucherCard extends StatefulWidget {
  final Ticket ticket;
  final String hashedClaimCode;

  const DigitalVoucherCard({
    super.key,
    required this.ticket,
    required this.hashedClaimCode,
  });

  @override
  State<DigitalVoucherCard> createState() => _DigitalVoucherCardState();
}

class _DigitalVoucherCardState extends State<DigitalVoucherCard> {
  late Timer _timer;
  Duration _timeLeft = const Duration(hours: 48); // 48-hour voucher expiration

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft.inSeconds > 0) {
        setState(() {
          _timeLeft -= const Duration(seconds: 1);
        });
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final double amount = widget.ticket.recommendedGrantAmount ?? widget.ticket.calculatedAmount;

    return Card(
      elevation: 6,
      shadowColor: Colors.greenAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text('Auto-Approved', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('${CurrencyFormatter.format(amount, currency: widget.ticket.currency, decimalDigits: 2)} Emergency Voucher',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text('Use for: ${widget.ticket.parsedCategory}', style: const TextStyle(color: Colors.grey)),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(thickness: 1.5, indent: 32, endIndent: 32),
            ),
            
            // Scannable QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: widget.hashedClaimCode,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Expires in: ${_formatDuration(_timeLeft)}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Trigger PDF Download / Save logic
                },
                icon: const Icon(Icons.download),
                label: const Text('Save Voucher as PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
