import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/job_tracking_manager.dart';
import 'widgets/glass_card.dart';

class AsyncJobProgressScreen extends StatefulWidget {
  final VoidCallback onMinimize;
  
  const AsyncJobProgressScreen({
    super.key, 
    required this.onMinimize,
  });

  @override
  State<AsyncJobProgressScreen> createState() => _AsyncJobProgressScreenState();
}

class _AsyncJobProgressScreenState extends State<AsyncJobProgressScreen> {
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services_outlined, color: Color(0xFF0D9488), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('MedAccess Clinical Triage Engine', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          tooltip: 'Minimize to background',
          onPressed: widget.onMinimize,
        ),
      ),
      body: Consumer<JobTrackingManager>(
        builder: (context, trackingManager, child) {
          if (trackingManager.currentState == JobState.idle || trackingManager.currentJobId == null) {
            return _buildIdleView();
          } else if (trackingManager.currentState == JobState.completed) {
            return _buildSuccessView(trackingManager.jobResult);
          } else if (trackingManager.currentState == JobState.failed) {
            return _buildErrorView(trackingManager.errorMessage);
          }

          return _buildProgressView(trackingManager);
        },
      ),
    );
  }

  Widget _buildIdleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: GlassCard(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  size: 54,
                  color: Color(0xFF0D9488),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Active Clinical Triage in Processing',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'When you submit an emergency medical claim or pharmacy copay request, '
                'the 4-stage MedAccess AI Pipeline (Layout-Aware OCR, Policy Matching, ESI Scoring, Instant Adjudication) '
                'will track here in real time.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onMinimize,
                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                label: const Text('Start New Request', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F1B2C),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressView(JobTrackingManager manager) {
    double percentage = 0.0;
    String statusText = 'Processing...';
    String stageText = 'Clinical Triage Active';

    switch (manager.currentState) {
      case JobState.queued:
        percentage = 0.25;
        statusText = 'Enqueuing Clinical Triage Request...';
        stageText = 'Clinical Triage Active';
        break;
      case JobState.transcription:
        percentage = 0.50;
        statusText = 'Parsing Medical Invoice & Clinical Distress...';
        stageText = 'Clinical Triage Active';
        break;
      case JobState.policyMatching:
        percentage = 0.75;
        statusText = 'Verifying Healthcare Policy & Fraud Sentinel...';
        stageText = 'Claim Verified';
        break;
      case JobState.mlScoring:
        percentage = 0.90;
        statusText = 'Calculating Emergency Copay Relief (ESI)...';
        stageText = 'Claim Verified';
        break;
      case JobState.completed:
        percentage = 1.0;
        statusText = 'Copay Grant Disbursed!';
        stageText = 'Copay Grant Disbursed';
        break;
      default:
        percentage = 0.0;
        stageText = 'Clinical Triage Active';
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    stageText,
                    style: const TextStyle(
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Triage Completion',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(percentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w100,
                    color: Color(0xFF0F172A),
                    letterSpacing: -4,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 16,
                    backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  statusText,
                  style: TextStyle(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildSuccessView(Map<String, dynamic>? result) {
    // Assuming DigitalVoucherCard implementation exists
    final isApproved = result?['status'] == 'AUTO_APPROVED' || result?['status'] == 'Auto-Approved';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isApproved ? Icons.check_circle : Icons.info,
              color: isApproved ? Colors.green : Colors.blue,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              isApproved ? 'Request Approved' : 'Under Review',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              isApproved 
                ? 'Your request has been automatically approved. A voucher has been generated.'
                : 'Your request requires manual review by the welfare team.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            // Digital Voucher Card — rendered when the backend returns a voucherCode
            if (isApproved && result?['voucherCode'] != null) ...[
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.teal.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(76),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.verified, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'DIGITAL WELFARE VOUCHER',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result!['voucherCode'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      onPressed: () {
                        final code = result['voucherCode'] as String;
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Voucher code copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Code'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Present this code at the Student Services counter\nor pharmacy to redeem your welfare grant.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String? error) {
    String displayError = "An unexpected error occurred while processing your request.";
    if (error != null) {
      if (error.contains('404 Not Found')) {
        displayError = "AI Model temporarily unavailable. Please contact support.";
      } else if (error.startsWith('{')) {
        try {
          final parsed = jsonDecode(error);
          displayError = parsed['error']['message'] ?? displayError;
        } catch (_) {}
      } else {
        // Clean up the raw string if it is not JSON
        displayError = error.replaceAll(RegExp(r'\[.*?\] '), '').trim();
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                ),
                const SizedBox(height: 24),
                Text(
                  'Processing Failed',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F1B2C),
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1B2C).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        displayError,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: const Color(0xFF1F1B2C).withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F1B2C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: widget.onMinimize, // Dismiss/Minimize
                    child: Text(
                      'Dismiss',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
