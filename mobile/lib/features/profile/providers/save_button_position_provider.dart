import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 保存按钮位置：右上角（AppBar action）/ 页面下方（底部按钮条）。
///
/// 仅存本机 SharedPreferences，不上云端（每台设备的操作习惯不同）。
enum SaveButtonPosition { topRight, bottom }

/// SharedPreferences 里存的值（稳定字符串，勿随手改）
const String kSaveButtonPositionTop = 'top';
const String kSaveButtonPositionBottom = 'bottom';

SaveButtonPosition saveButtonPositionFromStorage(String? raw) {
  return raw == kSaveButtonPositionBottom
      ? SaveButtonPosition.bottom
      : SaveButtonPosition.topRight;
}

String saveButtonPositionToStorage(SaveButtonPosition position) {
  return position == SaveButtonPosition.bottom
      ? kSaveButtonPositionBottom
      : kSaveButtonPositionTop;
}

class SaveButtonPositionNotifier extends StateNotifier<SaveButtonPosition> {
  SaveButtonPositionNotifier() : super(SaveButtonPosition.topRight);

  static const _key = 'mobile.save_button_position';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = saveButtonPositionFromStorage(prefs.getString(_key));
  }

  Future<void> setPosition(SaveButtonPosition position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, saveButtonPositionToStorage(position));
    state = position;
  }
}

final saveButtonPositionProvider =
    StateNotifierProvider<SaveButtonPositionNotifier, SaveButtonPosition>((ref) {
  return SaveButtonPositionNotifier();
});
