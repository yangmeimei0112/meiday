import 'package:flutter/material.dart';
import '../../domain/entities/event_attachment.dart';

class FullScreenImageViewer extends StatelessWidget {
  final EventAttachment attachment;

  const FullScreenImageViewer({
    super.key,
    required this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          attachment.fileName,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image, size: 100, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  attachment.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${attachment.formattedSize} • ${attachment.fileType}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
