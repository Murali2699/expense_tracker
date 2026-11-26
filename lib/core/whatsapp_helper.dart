import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

class WhatsAppHelper {
  WhatsAppHelper._();

  static const _clipboardChannel = MethodChannel(
    'in.muralikrishnan.expense_tracker/clipboard',
  );

  static Rect _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.maybeSizeOf(context);
    if (size != null && !size.isEmpty) {
      return Rect.fromLTWH(size.width / 2 - 1, size.height / 2 - 1, 2, 2);
    }
    return const Rect.fromLTWH(0, 0, 100, 100);
  }

  static Future<void> sendReminder(
    BuildContext context, {
    required String phoneNumber,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final origin = _shareOrigin(context);
    try {
      final result = await ApiClient.instance.sendWhatsAppReminder(phoneNumber);

      if (result.mode == 'cloud_api' && result.sent) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('WhatsApp reminder sent with UPI & QR!'),
          ),
        );
        return;
      }

      if (result.hasQr) {
        final qrFile = await ApiClient.instance.downloadQrToTempFile();
        if (qrFile != null) {
          if (Platform.isIOS) {
            await _clipboardChannel.invokeMethod<bool>(
              'copyImage',
              {'path': qrFile.path},
            );
            messenger.showSnackBar(
              const SnackBar(
                content: Text('UPI QR copied — paste in WhatsApp chat if needed.'),
              ),
            );
          } else {
            await Share.shareXFiles(
              [XFile(qrFile.path)],
              text: result.message,
              sharePositionOrigin: origin,
            );
            return;
          }
        }
      }

      final uri = Uri.parse(
        'https://wa.me/${result.phoneNumber}?text=${Uri.encodeComponent(result.message)}',
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
