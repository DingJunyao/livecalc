#!/usr/bin/env bash
#
# 生成不带签名的 iOS .ipa（用于自签安装 / 自用分发）
#
# 用法:
#   scripts/build-unsigned-ipa.sh [选项]
#
# 选项:
#   --profile         用 profile 模式构建（默认 release）
#   --debug           用 debug 模式构建
#   --clean           构建前 flutter clean
#   --no-pub          跳过 flutter pub get / 代码生成
#   --output DIR      输出目录（默认 mobile/build/ios/ipa）
#   --flutter PATH    指定 flutter 可执行文件
#   -h, --help        显示帮助
#
# 产物: <output>/livecalc-<version>+<build>-unsigned.ipa
#
# 注意: 未签名 IPA 不能直接安装，需要用 Sideloadly / AltStore / eSign 等
#       工具以你自己的 Apple ID 重签后再装（免费账号 7 天有效）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"
MODE="release"
DO_CLEAN=0
DO_PUB=1
OUT=""
FLUTTER_BIN="${FLUTTER_BIN:-}"

usage() { sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) MODE="profile"; shift ;;
    --debug) MODE="debug"; shift ;;
    --clean) DO_CLEAN=1; shift ;;
    --no-pub) DO_PUB=0; shift ;;
    --output) OUT="${2:-}"; shift 2 ;;
    --flutter) FLUTTER_BIN="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
  esac
done

die() { echo "错误: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "只能在 macOS 上构建 iOS 包"
command -v xcodebuild >/dev/null || die "未找到 xcodebuild，请先安装 Xcode"
[[ -d "$MOBILE" ]] || die "找不到 mobile 目录: $MOBILE"

if [[ -z "$FLUTTER_BIN" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(command -v flutter)"
  elif [[ -x "$HOME/flutter/bin/flutter" ]]; then
    FLUTTER_BIN="$HOME/flutter/bin/flutter"
  else
    die "未找到 flutter，可用 --flutter 指定路径"
  fi
fi
FLUTTER_DIR="$(cd "$(dirname "$FLUTTER_BIN")" && pwd)"
DART_BIN="$FLUTTER_DIR/dart"
[[ -x "$DART_BIN" ]] || DART_BIN="$FLUTTER_BIN"

# CocoaPods：本机用 conda 安装的 ruby 3.3 承载，pod 不在默认 PATH 里。
if ! command -v pod >/dev/null 2>&1; then
  for candidate in \
    "$HOME/miniforge/envs/ios/share/rubygems/bin" \
    "$HOME/.gem/ruby/3.3.0/bin" \
    /opt/homebrew/bin \
    /usr/local/bin; do
    if [[ -x "$candidate/pod" ]]; then
      export PATH="$candidate:$PATH"
      break
    fi
  done
fi
if [[ -d "$HOME/miniforge/envs/ios/share/rubygems" ]]; then
  export GEM_HOME="${GEM_HOME:-$HOME/miniforge/envs/ios/share/rubygems}"
  export GEM_PATH="${GEM_PATH:-$GEM_HOME:$HOME/miniforge/envs/ios/lib/ruby/gems/3.3.0}"
fi
command -v pod >/dev/null 2>&1 || die "未找到 CocoaPods（pod）。见 agent_doc 里的 iOS 构建说明"

echo "== 环境 =="
xcodebuild -version | head -n 2 || true
"$FLUTTER_BIN" --version 2>&1 | head -n 3 || true
pod --version 2>&1 | tail -n 1 || true
XCODE_MAJOR="$(xcodebuild -version 2>/dev/null | head -n 1 | sed -E 's/^Xcode ([0-9]+).*/\1/')"
if [[ "${XCODE_MAJOR:-0}" -lt 27 ]]; then
  echo "提示: 当前 Xcode ${XCODE_MAJOR:-?}（< 27），构建出的包不是 iPhone Duo 优化版；"
  echo "      装到 iPhone Duo 上展开内屏会居中显示、四周留白。Duo 适配需 Xcode 27.1+。"
fi
echo

cd "$MOBILE"

if [[ $DO_CLEAN -eq 1 ]]; then
  echo "== flutter clean =="
  "$FLUTTER_BIN" clean
fi

if [[ $DO_PUB -eq 1 ]]; then
  echo "== flutter pub get =="
  "$FLUTTER_BIN" pub get

  # mobile/.gitignore 忽略 *.g.dart，全新克隆后必须先跑 build_runner，
  # 否则 xcodebuild 里的 Dart 编译会因缺少 Drift 生成代码而失败。
  if [[ ! -f lib/core/database/app_database.g.dart ]]; then
    echo "== 生成代码（缺少 app_database.g.dart）=="
    "$DART_BIN" run build_runner build --delete-conflicting-outputs
  fi
fi

echo "== flutter build ios --$MODE --no-codesign =="
"$FLUTTER_BIN" build ios --"$MODE" --no-codesign

APP=""
for candidate in \
  "build/ios/iphoneos/Runner.app" \
  "build/ios/Release-iphoneos/Runner.app" \
  "build/ios/Debug-iphoneos/Runner.app" \
  "build/ios/Profile-iphoneos/Runner.app"; do
  if [[ -d "$candidate" ]]; then APP="$candidate"; break; fi
done
[[ -n "$APP" ]] || die "构建产物不存在（找不到 Runner.app）"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist" 2>/dev/null || echo 0)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist" 2>/dev/null || echo 0)"
[[ -n "$OUT" ]] || OUT="$MOBILE/build/ios/ipa"
mkdir -p "$OUT"
IPA="$OUT/livecalc-${VERSION}+${BUILD}-unsigned.ipa"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"

echo "== 打包 Payload =="
ditto "$APP" "$STAGE/Payload/Runner.app"
rm -f "$IPA"
ditto -c -k --sequesterRsrc --keepParent "$STAGE/Payload" "$IPA"

echo
echo "== 完成 =="
echo "IPA:    $IPA"
echo "大小:   $(du -h "$IPA" | cut -f1)"
echo "SHA256: $(shasum -a 256 "$IPA" | cut -d' ' -f1)"
echo
echo "安装提示: 该包未签名，不能直接装到 iPhone。"
echo "  - 用 Sideloadly / AltStore / eSign 等工具，以你自己的 Apple ID 重签后安装（免费账号 7 天有效）"
echo "  - 有付费开发者账号时，也可用 Xcode 打开 mobile/ios/Runner.xcworkspace，选 Team 后 Run/Archive"
