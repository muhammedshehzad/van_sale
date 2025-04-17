import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


// SoundManager class definition
class SoundManager {
  static void initialize() {
    // Initialize sound resources here
  }

  static void playSuccess() {
    // Play success sound
  }

  static void playError() {
    // Play error sound
  }

  static void playWarning() {
    // Play warning sound
  }

  static void playCancel() {
    // Play cancel sound
  }
}

// AnimatedQuantityButton widget definition
class AnimatedQuantityButton extends StatelessWidget {
  final double quantity;
  final Function(double) onQuantityChanged;
  final double min;
  final double max;
  final bool disabled;

  const AnimatedQuantityButton({
    Key? key,
    required this.quantity,
    required this.onQuantityChanged,
    required this.min,
    required this.max,
    this.disabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove),
          onPressed: disabled || quantity <= min
              ? null
              : () => onQuantityChanged(quantity - 1),
        ),
        Text(
          quantity.toStringAsFixed(2),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: disabled || quantity >= max
              ? null
              : () => onQuantityChanged(quantity + 1),
        ),
      ],
    );
  }
}