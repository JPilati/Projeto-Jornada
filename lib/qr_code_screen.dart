import 'package:flutter/material.dart';

class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'QR Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            // 🔲 BOX PRINCIPAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // 🔳 QR VISUAL
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 110,
                      color: Color(0xFFE87722),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Escanear QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Use o QR Code para consultar documentos, equipamentos ou funcionários.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFCBD5E0),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 📷 BOTÃO CÂMERA
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scanner será integrado depois.'),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('ABRIR CÂMERA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE87722),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ⌨️ BOTÃO MANUAL
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.keyboard_rounded),
              label: const Text('DIGITAR CÓDIGO MANUALMENTE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D1B2A),
                minimumSize: const Size(double.infinity, 54),
                side: const BorderSide(color: Color(0xFF0D1B2A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}