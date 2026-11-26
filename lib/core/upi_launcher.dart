import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class UpiAppOption {
  const UpiAppOption(this.name, this.scheme, this.icon);
  final String name;
  final String scheme;
  final IconData icon;
}

const List<UpiAppOption> kUpiApps = [
  UpiAppOption('PhonePe', 'phonepe://', Icons.account_balance_wallet_rounded),
  UpiAppOption('Google Pay', 'tez://', Icons.payment_rounded),
  UpiAppOption('Paytm', 'paytmmp://', Icons.qr_code_2_rounded),
  UpiAppOption('Super.money', 'supermoney://', Icons.bolt_rounded),
  UpiAppOption('BHIM', 'bhim://', Icons.account_balance_rounded),
  UpiAppOption('CRED', 'credpay://', Icons.credit_card_rounded),
];

class UpiLauncher {
  UpiLauncher._();

  static Future<void> showPaySheet(
    BuildContext context, {
    required String payeeName,
    required String phoneOrUpi,
    required double amount,
  }) async {
    final copyTarget = phoneOrUpi.trim();
    if (copyTarget.isEmpty) {
      await _showAlert(
        context,
        title: 'Phone / UPI Missing',
        message: 'Please edit this entry and add their phone number or UPI ID first.',
      );
      return;
    }

    final installed = <UpiAppOption>[];
    for (final app in kUpiApps) {
      if (await canLaunchUrl(Uri.parse(app.scheme))) {
        installed.add(app);
      }
    }

    if (!context.mounted) return;
    if (installed.isEmpty) {
      await _showAlert(
        context,
        title: 'App Not Installed',
        message: 'No UPI payment app is installed. Please install PhonePe, Google Pay, or Paytm.',
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: copyTarget));
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pay ₹${amount.toStringAsFixed(2)} to $payeeName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Copied "$copyTarget" to clipboard. Paste it in your UPI app to avoid bank intent blocks.',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              ...installed.map(
                (app) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openApp(context, app);
                    },
                    icon: Icon(app.icon, size: 18),
                    label: Text('Open ${app.name}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentSoft,
                      foregroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.accent),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openApp(BuildContext context, UpiAppOption app) async {
    final launched = await launchUrl(
      Uri.parse(app.scheme),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      await _showAlert(
        context,
        title: 'App Not Installed',
        message: '${app.name} is not installed. Please install the app.',
      );
    }
  }

  static Future<void> _showAlert(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF032318),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
