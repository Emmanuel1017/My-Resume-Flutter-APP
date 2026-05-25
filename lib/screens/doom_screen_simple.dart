import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simplified DOOM screen - launches external DOOM player
class DoomScreenSimple extends StatelessWidget {
  const DoomScreenSimple({super.key});

  Future<void> _launchDoom(BuildContext context, String game) async {
    final wadUrl = game == 'doom1'
        ? 'https://raw.githubusercontent.com/Emmanuel1017/Angular-Resume/master/src/assets/doom/doom.jsdos'
        : 'https://raw.githubusercontent.com/Emmanuel1017/Angular-Resume/master/src/assets/doom/doom2.jsdos';

    // Use dos.zone player
    final playerUrl = 'https://dos.zone/player/?bundleUrl=$wadUrl';

    final uri = Uri.parse(playerUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch DOOM')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        title: const Text('DOOM'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'CAN IT RUN DOOM?',
              style: TextStyle(
                color: Color(0xFFc41e1e),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _launchDoom(context, 'doom1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc41e1e),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text(
                'PLAY DOOM',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _launchDoom(context, 'doom2'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc41e1e),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text(
                'PLAY DOOM II',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
