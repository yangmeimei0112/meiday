import 'package:flutter/material.dart';
import '../../domain/entities/availability_slot.dart';

class AvailabilityHeatmapOverlay extends StatelessWidget {
  final List<AvailabilitySlot> slots;
  final double hourHeight;

  const AvailabilityHeatmapOverlay({
    super.key,
    required this.slots,
    required this.hourHeight,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _HeatmapPainter(slots: slots, hourHeight: hourHeight),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<AvailabilitySlot> slots;
  final double hourHeight;

  _HeatmapPainter({required this.slots, required this.hourHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final slot in slots) {
      final startMinutes = (slot.startTime.hour * 60) + slot.startTime.minute;
      int endMinutes = (slot.endTime.hour * 60) + slot.endTime.minute;
      if (endMinutes == 0 && slot.endTime.isAfter(slot.startTime)) {
        endMinutes = 24 * 60;
      }
      final top = (startMinutes / 60.0) * hourHeight;
      final bottom = (endMinutes / 60.0) * hourHeight;
      final height = bottom - top;

      if (height <= 0) continue;

      paint.color = slot.color;
      final rect = Rect.fromLTWH(0, top, size.width, height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.slots != slots || oldDelegate.hourHeight != hourHeight;
  }
}
