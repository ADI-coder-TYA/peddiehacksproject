// ============================================================
//  IntelliDesk EduAccess — Student Crisis Chat Screen
//  A compassionate, multi-turn Conversational Crisis Counselor UI
//  with real-time PFA, interactive tap-to-call hotline cards,
//  and async grant triage status.
// ============================================================

import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_provider.dart';

// ─────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────

class StudentCrisisChatScreen extends StatefulWidget {
  const StudentCrisisChatScreen({super.key});

  @override
  State<StudentCrisisChatScreen> createState() =>
      _StudentCrisisChatScreenState();
}

class _StudentCrisisChatScreenState extends State<StudentCrisisChatScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // ── Pending attachment ───────────────────────────────────────
  AttachmentData? _pendingAttachment;

  // ── ImagePicker / FilePicker ─────────────────────────────────
  final ImagePicker _imagePicker = ImagePicker();

  // ─────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Scroll to bottom whenever messages change.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage([String? prefilledText]) async {
    final text = prefilledText ?? _textCtrl.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    final attachment = _pendingAttachment;
    _textCtrl.clear();
    setState(() => _pendingAttachment = null);

    await context.read<ChatProvider>().sendMessage(
          text: text,
          attachment: attachment,
        );
    _scrollToBottom();
  }

  Future<void> _pickFromCamera() async {
    Navigator.pop(context); // close bottom sheet
    try {
      final XFile? photo =
          await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _pendingAttachment = AttachmentData(
          fileName: photo.name,
          mimeType: 'image/jpeg',
          bytes: bytes,
        );
      });
    } catch (e) {
      _showError('Camera unavailable: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    Navigator.pop(context);
    try {
      final XFile? photo =
          await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _pendingAttachment = AttachmentData(
          fileName: photo.name,
          mimeType: 'image/jpeg',
          bytes: bytes,
        );
      });
    } catch (e) {
      _showError('Gallery unavailable: $e');
    }
  }

  Future<void> _pickDocument() async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null && !kIsWeb) {
        final f = File(file.path!);
        if (f.existsSync()) {
          bytes = await f.readAsBytes();
        }
      }
      if (bytes == null || bytes.isEmpty) {
        _showError('Could not load file contents');
        return;
      }
      setState(() {
        _pendingAttachment = AttachmentData(
          fileName: file.name,
          mimeType: _mimeFromExtension(file.extension ?? ''),
          bytes: bytes!,
        );
      });
    } catch (e) {
      _showError('Could not pick file: $e');
    }
  }

  String _mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentBottomSheet(
        onCamera: _pickFromCamera,
        onGallery: _pickFromGallery,
        onDocument: _pickDocument,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Seamless boutique background
      body: SafeArea(
        child: Column(
          children: [
            _buildBoutiqueHeader(context),
            // Status hint bar (e.g., "Assessing emergency guidelines...")
            _StatusHintBar(),
            // Messages list
            Expanded(
              child: _MessagesList(
                scrollController: _scrollCtrl,
                onQuickPrompt: (prompt) => _sendMessage(prompt),
              ),
            ),
            // Pending attachment preview
            if (_pendingAttachment != null)
              _AttachmentPreview(
                attachment: _pendingAttachment!,
                onRemove: () => setState(() => _pendingAttachment = null),
              ),
            // Input bar
            _InputBar(
              controller: _textCtrl,
              focusNode: _focusNode,
              onSend: () => _sendMessage(),
              onAttach: _showAttachmentSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoutiqueHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: Color(0x1A1F1B2C), width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'MedAccess 24/7 Clinical & Psychological First Aid',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CLINICAL PFA ACTIVE',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF059669),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Immediate emotional stabilization, medical guidance & emergency copay triage',
                    style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          Consumer<ChatProvider>(
            builder: (context, provider, child) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
              onSelected: (value) {
                if (value == 'clear') provider.clearChat();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'clear', child: Text('Clear clinical chat')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATUS HINT BAR
// ─────────────────────────────────────────────────────────────

class _StatusHintBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hint = context.watch<ChatProvider>().statusHint;
    if (hint == null) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFF0D9488).withValues(alpha: 0.9),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            hint,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MESSAGES LIST
// ─────────────────────────────────────────────────────────────

class _MessagesList extends StatelessWidget {
  final ScrollController scrollController;
  final ValueChanged<String> onQuickPrompt;

  const _MessagesList({
    required this.scrollController,
    required this.onQuickPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<ChatProvider>().messages;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return _ChatBubble(message: msg);
            },
          ),
        ),
        if (messages.length <= 2)
          _QuickActionPrompts(onSelect: onQuickPrompt),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  QUICK ACTION PROMPTS
// ─────────────────────────────────────────────────────────────

class _QuickActionPrompts extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _QuickActionPrompts({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'Need emergency copay relief for ER hospital bill (\$650)',
      'Experiencing acute panic attacks & severe psychiatric distress',
      'Prescription insulin & maintenance pharmacy copay subsidy (\$180)',
      'Need clinical triage & urgent doctor consultation micro-grant',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final p = prompts[idx];
          return ActionChip(
            label: Text(
              p,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: const Color(0xFF0D9488),
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            side: const BorderSide(color: Color(0x330D9488)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => onSelect(p),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CHAT BUBBLE
// ─────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  bool get _isStudent => message.sender == MessageSender.student;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            _isStudent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isStudent) ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: _isStudent
                    ? const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _isStudent
                    ? null
                    : (message.isCrisisResponse
                        ? const Color(0xFFFFF1F2)
                        : Colors.white.withValues(alpha: 0.95)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(_isStudent ? 20 : 4),
                  bottomRight: Radius.circular(_isStudent ? 4 : 20),
                ),
                border: Border.all(
                  color: _isStudent
                      ? const Color(0xFFEE4D9F).withValues(alpha: 0.3)
                      : (message.isCrisisResponse
                          ? const Color(0xFFFDA4AF)
                          : Colors.white),
                  width: message.isCrisisResponse ? 1.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F1B2C).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildContent(context),
            ),
          ),
          if (_isStudent) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Loading state — animated typing indicator
    if (message.isLoading) {
      return const _TypingIndicator();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Crisis banner if critical life-safety
        if (message.isCrisisResponse) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.health_and_safety, color: Color(0xFFDC2626), size: 14),
                const SizedBox(width: 6),
                Text(
                  'CRITICAL LIFE-SAFETY PROTOCOL ACTIVE',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFDC2626),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Attachment thumbnail (image or file icon)
        if (message.attachment != null) ...[
          _AttachmentThumbnail(attachment: message.attachment!),
          const SizedBox(height: 8),
        ],

        // Main text
        if (message.text.isNotEmpty)
          SelectableText(
            message.text,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: _isStudent ? Colors.white : const Color(0xFF1F1B2C),
              height: 1.45,
            ),
          ),

        // Emergency Resource Contact Cards
        if (message.resources != null && message.resources!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EmergencyResourcesList(resources: message.resources!),
        ],

        // Ticket Confirmation Action Buttons
        if (message.requiresConfirmation) ...[
          const SizedBox(height: 10),
          const _TicketConfirmationButtons(),
        ],

        // Voucher code card
        if (message.voucherCode != null) ...[
          const SizedBox(height: 10),
          _VoucherCard(code: message.voucherCode!),
        ],

        // Timestamp
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.bottomRight,
          child: Text(
            DateFormat('HH:mm').format(message.timestamp),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _isStudent ? Colors.white70 : Colors.black38,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TICKET CONFIRMATION BUTTONS
// ─────────────────────────────────────────────────────────────

class _TicketConfirmationButtons extends StatelessWidget {
  const _TicketConfirmationButtons();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: Color(0xFF8B5CF6), size: 16),
              const SizedBox(width: 6),
              Text(
                'Open Emergency Welfare Ticket?',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<ChatProvider>().sendMessage(
                          text: "Yes, please submit an emergency welfare ticket",
                          confirmTicket: true,
                        );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
                  label: Text(
                    'Yes, Submit Ticket',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<ChatProvider>().sendMessage(
                          text: "No, just seeking advice for now",
                        );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  child: Text(
                    'Just Advice',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EMERGENCY RESOURCES LIST (Interactive Hotline Cards)
// ─────────────────────────────────────────────────────────────

class _EmergencyResourcesList extends StatelessWidget {
  final List<EmergencyResource> resources;
  const _EmergencyResourcesList({required this.resources});

  Future<void> _launchCaller(String actionUrl) async {
    try {
      final uri = Uri.parse(actionUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Could not launch caller for $actionUrl');
      }
    } catch (e) {
      debugPrint('Error launching caller: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 16),
            const SizedBox(width: 6),
            Text(
              'Immediate 24/7 Crisis Helplines',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...resources.map((res) => _buildResourceCard(context, res)),
      ],
    );
  }

  Widget _buildResourceCard(BuildContext context, EmergencyResource res) {
    final isIndiaHotline = res.number.contains('14416') || res.name.contains('Tele-MANAS');
    final isVandrevala = res.name.contains('Vandrevala');
    final isEscort = res.name.contains('Escort') || res.name.contains('Campus');

    Color badgeColor = const Color(0xFFDC2626);
    IconData icon = Icons.phone_in_talk;
    if (isIndiaHotline) {
      badgeColor = const Color(0xFF2563EB);
      icon = Icons.support_agent;
    } else if (isVandrevala) {
      badgeColor = const Color(0xFF7C3AED);
      icon = Icons.favorite;
    } else if (isEscort) {
      badgeColor = const Color(0xFF059669);
      icon = Icons.security;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: badgeColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.name,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F1B2C),
                      ),
                    ),
                    Text(
                      res.category,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (res.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              res.description,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF475569),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton.icon(
              onPressed: () => _launchCaller(res.actionUrl),
              icon: const Icon(Icons.call, size: 14, color: Colors.white),
              label: Text(
                'Tap to Call ${res.number}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TYPING INDICATOR  (three animated dots)
// ─────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Counselor is typing',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF8B5CF6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          ...List.generate(3, (i) {
            final delay = i * 0.3;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  VOUCHER CARD
// ─────────────────────────────────────────────────────────────

class _VoucherCard extends StatelessWidget {
  final String code;
  const _VoucherCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFEE4D9F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_pharmacy, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'Welfare Voucher',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Voucher code copied!'),
                      backgroundColor: const Color(0xFF8B5CF6),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                child: const Tooltip(
                  message: 'Copy code',
                  child: Icon(Icons.copy, color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Present at Student Services counter',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ATTACHMENT THUMBNAIL (inside bubble)
// ─────────────────────────────────────────────────────────────

class _AttachmentThumbnail extends StatelessWidget {
  final AttachmentData attachment;
  const _AttachmentThumbnail({required this.attachment});

  bool get _isImage =>
      attachment.mimeType.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          attachment.bytes,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const _FileChip(label: 'Image'),
        ),
      );
    }
    return _FileChip(label: attachment.fileName);
  }
}

class _FileChip extends StatelessWidget {
  final String label;
  const _FileChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 16, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PENDING ATTACHMENT PREVIEW (above input bar)
// ─────────────────────────────────────────────────────────────

class _AttachmentPreview extends StatelessWidget {
  final AttachmentData attachment;
  final VoidCallback onRemove;
  const _AttachmentPreview({required this.attachment, required this.onRemove});

  bool get _isImage => attachment.mimeType.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    attachment.bytes,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description, color: Color(0xFF8B5CF6)),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${(attachment.bytes.length / 1024).toStringAsFixed(1)} KB',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: Colors.black45,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  INPUT BAR
// ─────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final isSending = context.watch<ChatProvider>().isSending;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text input + attach button ──────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0x1A1F1B2C)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F1B2C).withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attach button
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: IconButton(
                      onPressed: isSending ? null : onAttach,
                      icon: const Icon(Icons.attach_file),
                      color: const Color(0xFF8B5CF6),
                      tooltip: 'Attach document or photo',
                    ),
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !isSending,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFF1F1B2C),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Share what you are experiencing...',
                        hintStyle: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Send button ─────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isSending
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFEE4D9F), Color(0xFF8B5CF6)],
                    ),
              color: isSending ? Colors.grey.shade400 : null,
              shape: BoxShape.circle,
              boxShadow: isSending
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFEE4D9F).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: isSending ? null : onSend,
                customBorder: const CircleBorder(),
                child: Center(
                  child: isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ATTACHMENT BOTTOM SHEET
// ─────────────────────────────────────────────────────────────

class _AttachmentBottomSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onDocument;

  const _AttachmentBottomSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attach Supporting Evidence',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          Text(
            'Hospital bill, doctor\'s note, accommodation letter…',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SheetOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: const Color(0xFF075E54),
                onTap: onCamera,
              ),
              _SheetOption(
                icon: Icons.photo_library,
                label: 'Gallery',
                color: const Color(0xFF128C7E),
                onTap: onGallery,
              ),
              _SheetOption(
                icon: Icons.picture_as_pdf,
                label: 'Document',
                color: const Color(0xFF25D366),
                onTap: onDocument,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(60), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
