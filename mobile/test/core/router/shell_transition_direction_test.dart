import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/layout/device_form.dart';
import 'package:com_a4ding_livecalc/core/router/shell_transition.dart';

void main() {
  group('页面切换方向（竖条导航 → 上下滑动）', () {
    test('edgeRail：切到更靠下的目的地从下方滑入（dx=0, dy=+1）', () {
      expect(
        shellPageSlideBegin(
            mode: ShellMode.edgeRail, toEarlierTab: false, isRtl: false),
        const Offset(0, 1),
      );
    });

    test('edgeRail：切回更靠上的目的地从上方滑入（dx=0, dy=-1）', () {
      expect(
        shellPageSlideBegin(
            mode: ShellMode.edgeRail, toEarlierTab: true, isRtl: false),
        const Offset(0, -1),
      );
    });

    test('edgeRail 在 RTL 下同样上下滑动（竖条不随语言翻转）', () {
      expect(
        shellPageSlideBegin(
            mode: ShellMode.edgeRail, toEarlierTab: false, isRtl: true),
        const Offset(0, 1),
      );
    });

    test('bottomBar：仍为左右滑动（LTR 靠后 → 右侧滑入）', () {
      expect(
        shellPageSlideBegin(
            mode: ShellMode.bottomBar, toEarlierTab: false, isRtl: false),
        const Offset(1, 0),
      );
    });

    test('bottomBar RTL：方向镜像', () {
      expect(
        shellPageSlideBegin(
            mode: ShellMode.bottomBar, toEarlierTab: false, isRtl: true),
        const Offset(-1, 0),
      );
    });

    test('sideRail（平板左 rail）：保持左右滑动', () {
      expect(
        shellPageSlideBegin(
            mode: ShellMode.sideRail, toEarlierTab: true, isRtl: false),
        const Offset(-1, 0),
      );
    });
  });
}
