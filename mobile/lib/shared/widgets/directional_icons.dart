import 'package:flutter/material.dart';

class DirectionalIcons {
  const DirectionalIcons._();

  static IconData backArrow(BuildContext context) {
    return _isRtl(context) ? Icons.arrow_forward : Icons.arrow_back;
  }

  static IconData forwardArrow(BuildContext context) {
    return _isRtl(context) ? Icons.arrow_back : Icons.arrow_forward;
  }

  static IconData forwardChevron(BuildContext context) {
    return _isRtl(context) ? Icons.chevron_left : Icons.chevron_right;
  }

  static bool _isRtl(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }
}
