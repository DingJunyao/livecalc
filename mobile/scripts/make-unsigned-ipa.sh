#!/usr/bin/env bash
# 把 `flutter build ios --release --no-codesign` 产出的 Runner.app 打成**未签名 IPA**。
#
# 未签名 IPA 不能直接双击/直接装：要么用 Sideloadly / AltStore / Apple Configurator 之类
# 工具拿自己的 Apple ID 重签后安装，要么交给有企业证书的人重签分发。
# 需要「装到设备就能跑」的 IPA 请走 `flutter build ipa`（必须先配好签名 Team）。
#
# 用法：
#   scripts/make-unsigned-ipa.sh            # 先重新做一次不签名 release 构建，保证 ipa 里是最新代码
#   scripts/make-unsigned-ipa.sh --reuse    # 跳过编译，直接用已有的 Runner.app（上次构建的产物）
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/ios/iphoneos/Runner.app"
OUT_DIR="build/ios/ipa"

REUSE=0
if [[ "${1:-}" == "--reuse" ]]; then
  REUSE=1
fi

if [[ "$REUSE" != "1" || ! -d "$APP" ]]; then
  export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
  export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"
  flutter build ios --release --no-codesign
fi

# IPA 文件名带版本号，便于区分（pubspec: 1.0.0+1 -> 1.0.0-1）
VERSION="$(awk '/^version:/{print $2}' pubspec.yaml | tr '+' '-')"
IPA="$OUT_DIR/livecalc-${VERSION}-unsigned.ipa"

rm -rf "$OUT_DIR/Payload"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP" "$OUT_DIR/Payload/Runner.app"

# 未签名包里的空签名目录、包内 .DS_Store、扩展属性都会让重签工具报错，先清掉
rm -rf "$OUT_DIR/Payload/Runner.app/_CodeSignature" \
       "$OUT_DIR/Payload/Runner.app/embedded.mobileprovision"
find "$OUT_DIR/Payload/Runner.app" -name .DS_Store -delete 2>/dev/null || true
xattr -cr "$OUT_DIR/Payload/Runner.app" 2>/dev/null || true

rm -f "$IPA"
# -y 保留符号链接（Framework 里的版本链接），否则 App 启动即崩
(cd "$OUT_DIR" && zip -qry "$(basename "$IPA")" Payload)
rm -rf "$OUT_DIR/Payload"

echo "✓ 未签名 IPA: $(pwd)/$IPA"
ls -lh "$IPA"
