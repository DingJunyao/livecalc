import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/router/shell_transition.dart';

void main() {
  test('LTR：切到更靠后的 tab 从右滑入，切回更早的 tab 从左滑入', () {
    expect(
      shellTabSlideBegin(toEarlierTab: false, isRtl: false),
      const Offset(1.0, 0.0),
    );
    expect(
      shellTabSlideBegin(toEarlierTab: true, isRtl: false),
      const Offset(-1.0, 0.0),
    );
  });

  test('RTL：tab 视觉顺序相反，滑动方向镜像', () {
    expect(
      shellTabSlideBegin(toEarlierTab: false, isRtl: true),
      const Offset(-1.0, 0.0),
    );
    expect(
      shellTabSlideBegin(toEarlierTab: true, isRtl: true),
      const Offset(1.0, 0.0),
    );
  });
}
