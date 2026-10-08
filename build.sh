#!/usr/bin/env bash
# Jev Jarvis (iOS) 缓存友好构建脚本
#
# 作用：
#   1. 把所有构建缓存 / 派生数据写到 D 盘（Windows D 分区在 macOS Boot Camp 下的 /Volumes/D），
#      不占用 Mac 系统卷（等效 C 盘）。
#   2. 把运行时缓存根 JEV_CACHE_ROOT 注入构建/运行环境，App 内 JevPaths 据此落盘。
#
# 用法（在 Mac 上）：
#   ./build.sh sim       # 构建到模拟器（不签名，CODE_SIGNING_ALLOWED=NO）
#   ./build.sh device    # 构建到真机（需连设备 + 自动签名）
#   ./build.sh archive   # 仅归档为 .xcarchive（不出 IPA）
#   ./build.sh ipa       # 归档 + 导出 IPA（iOS 打包成品，需签名）
#   ./build.sh paths     # 仅打印当前解析出的缓存路径，不构建
#
# 可用环境变量覆盖缓存根：
#   JEV_CACHE_ROOT=/Volumes/D/jev-ios-cache ./build.sh sim
#
# iOS 打包（出 IPA）一步到位：
#   JEV_TEAM_ID=你的团队ID ./build.sh ipa
#   导出产物: $JEV_CACHE_ROOT/Build/IPA/JevJarvis.ipa
#   （JEV_TEAM_ID 不传则用 project.yml 的默认团队，通常为上游团队，需自行替换）
#
# 免费账号模式（未付 $99，仅装自己设备测试）：
#   JEV_FREE_ACCOUNT=1 JEV_TEAM_ID=你的团队ID ./build.sh ipa
#   会自动去掉 App Group 能力（免费账号无法启用），主 App 可正常跑、可装自己手机；
#   代价：主 App 与键盘扩展之间的共享配置不可用（键盘扩展读不到共享数据）。
#   付 $99 升级后去掉 JEV_FREE_ACCOUNT 即可恢复 App Group 共享。

set -euo pipefail

# —— 缓存根（D 盘）——
export JEV_CACHE_ROOT="${JEV_CACHE_ROOT:-/Volumes/D/jev-ios-cache}"
DERIVED_DATA="$JEV_CACHE_ROOT/DerivedData"

echo "==> 缓存根: $JEV_CACHE_ROOT"

# —— Team ID（签名用）——
# 优先级：环境变量 JEV_TEAM_ID > 本机 Apple Development 证书 OU 自动识别 > 上游占位 75LZ93U5CF。
# 苹果规定：证书 Subject 的 OU(Organizational Unit) 字段即团队 ID（Team ID），故可直接从本机证书读出，
# 免去手抄。免费账号只要你已用 Apple ID 登录过 Xcode 并签过一次名，本机就会有 Apple Development 证书。
if [ -z "${JEV_TEAM_ID:-}" ]; then
  JEV_TEAM_ID="$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Za-z0-9]\{10\}\).*/\1/p' | head -n 1 || true)"
fi
if [ -z "${JEV_TEAM_ID:-}" ]; then
  JEV_TEAM_ID="75LZ93U5CF"
  echo "!! 未能自动识别团队 ID，暂用上游占位 75LZ93U5CF。"
  echo "   请先在本机 Xcode 用你的 Apple ID 登录并完成一次签名，或显式 export JEV_TEAM_ID=你的团队ID。"
else
  echo "==> 团队 ID: $JEV_TEAM_ID"
fi
export JEV_TEAM_ID

# —— 免费账号模式：去掉 App Group 能力，使免费 Apple ID 也能装到自己设备 ——
# 免费账号无法启用 App Group，不去掉会签名报 entitlement 不匹配。
# 设为 1 即走免费路径（键盘与主 App 之间共享配置将不可用，但主 App 可正常跑）。
if [ "${JEV_FREE_ACCOUNT:-0}" = "1" ]; then
  export JEV_APP_ENTITLEMENTS="App/JevJarvis.free.entitlements"
  export JEV_KB_ENTITLEMENTS="Keyboard/JevKeyboard.free.entitlements"
  echo "==> 免费账号模式 (JEV_FREE_ACCOUNT=1): 不使用 App Group，键盘共享不可用"
else
  export JEV_APP_ENTITLEMENTS="App/JevJarvis.entitlements"
  export JEV_KB_ENTITLEMENTS="Keyboard/JevKeyboard.entitlements"
fi

if [ ! -d "/Volumes/D" ]; then
  echo "!! 警告: 当前 Mac 未挂载 /Volumes/D (Windows D 盘)。"
  echo "   缓存将写到 $JEV_CACHE_ROOT —— 若该路径仍在系统卷上，等于仍在 C 盘等价位置。"
  echo "   请确认已通过 Boot Camp 挂载 Windows D 盘，或修改 JEV_CACHE_ROOT 到外置盘。"
fi

# 预建目录并放开权限
mkdir -p "$JEV_CACHE_ROOT/DerivedData" \
         "$JEV_CACHE_ROOT/Build/Products" \
         "$JEV_CACHE_ROOT/Build/Intermediates" \
         "$JEV_CACHE_ROOT/Build/Precompiled" \
         "$JEV_CACHE_ROOT/runtime" \
         "$JEV_CACHE_ROOT/logs"
chmod -R u+rwx "$JEV_CACHE_ROOT" 2>/dev/null || true

if [ "${1:-sim}" = "paths" ]; then
  echo "==> 解析出的缓存路径:"
  echo "    DerivedData      : $DERIVED_DATA"
  echo "    构建产物          : $JEV_CACHE_ROOT/Build/Products"
  echo "    中间产物          : $JEV_CACHE_ROOT/Build/Intermediates"
  echo "    预编译            : $JEV_CACHE_ROOT/Build/Precompiled"
  echo "    运行时缓存        : $JEV_CACHE_ROOT/runtime"
  echo "    调试日志          : $JEV_CACHE_ROOT/logs/jev-diag.log"
  exit 0
fi

# 生成 xcodeproj（需要 xcodegen: brew install xcodegen）
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
else
  echo "!! 未找到 xcodegen，跳过生成（若 JevJarvis.xcodeproj 已存在则直接用）。"
  echo "   安装: brew install xcodegen"
fi

ACTION="${1:-sim}"
case "$ACTION" in
  sim)
    xcodebuild \
      -project JevJarvis.xcodeproj \
      -scheme JevJarvis \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$DERIVED_DATA" \
      SYMROOT="$JEV_CACHE_ROOT/Build/Products" \
      OBJROOT="$JEV_CACHE_ROOT/Build/Intermediates" \
      SHARED_PRECOMPS_DIR="$JEV_CACHE_ROOT/Build/Precompiled" \
      CODE_SIGNING_ALLOWED=NO \
      build
    ;;
  device)
    xcodebuild \
      -project JevJarvis.xcodeproj \
      -scheme JevJarvis \
      -sdk iphoneos \
      -destination 'generic/platform=iOS' \
      -derivedDataPath "$DERIVED_DATA" \
      SYMROOT="$JEV_CACHE_ROOT/Build/Products" \
      OBJROOT="$JEV_CACHE_ROOT/Build/Intermediates" \
      SHARED_PRECOMPS_DIR="$JEV_CACHE_ROOT/Build/Precompiled" \
      -allowProvisioningUpdates \
      build
    ;;
  archive)
    xcodebuild \
      -project JevJarvis.xcodeproj \
      -scheme JevJarvis \
      -sdk iphoneos \
      -destination 'generic/platform=iOS' \
      -derivedDataPath "$DERIVED_DATA" \
      -archivePath "$JEV_CACHE_ROOT/Build/JevJarvis.xcarchive" \
      SYMROOT="$JEV_CACHE_ROOT/Build/Products" \
      OBJROOT="$JEV_CACHE_ROOT/Build/Intermediates" \
      SHARED_PRECOMPS_DIR="$JEV_CACHE_ROOT/Build/Precompiled" \
      -allowProvisioningUpdates \
      archive
    ;;
  ipa)
    ARCHIVE="$JEV_CACHE_ROOT/Build/JevJarvis.xcarchive"
    IPA_OUT="$JEV_CACHE_ROOT/Build/IPA"
    # 归档（若尚未归档）
    if [ ! -d "$ARCHIVE" ]; then
      xcodebuild \
        -project JevJarvis.xcodeproj \
        -scheme JevJarvis \
        -sdk iphoneos \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$DERIVED_DATA" \
        -archivePath "$ARCHIVE" \
        SYMROOT="$JEV_CACHE_ROOT/Build/Products" \
        OBJROOT="$JEV_CACHE_ROOT/Build/Intermediates" \
        SHARED_PRECOMPS_DIR="$JEV_CACHE_ROOT/Build/Precompiled" \
        -allowProvisioningUpdates \
        archive
    fi
    # 导出 IPA（自动生成 ExportOptions.plist，团队 ID 用前面解析出的 JEV_TEAM_ID）
    TEAM_ID="$JEV_TEAM_ID"
    if [ "$TEAM_ID" = "75LZ93U5CF" ]; then
      echo "!! 注意: 团队 ID 仍为上游占位 75LZ93U5CF（未指定 JEV_TEAM_ID 且未在本机证书中识别到）。"
      echo "   请在本机 Xcode 用你的 Apple ID 登录并完成一次签名，或 export JEV_TEAM_ID=你的团队ID。"
    fi
    EXPORT_PLIST="$(mktemp -t jev-export.XXXXXX.plist)"
    cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>method</key><string>development</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>stripSwiftSymbols</key><true/>
    <key>compileBitcode</key><false/>
</dict>
</plist>
PLIST
    mkdir -p "$IPA_OUT"
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE" \
      -exportPath "$IPA_OUT" \
      -exportOptionsPlist "$EXPORT_PLIST" \
      -allowProvisioningUpdates
    rm -f "$EXPORT_PLIST"
    echo "==> IPA 已导出: $IPA_OUT/JevJarvis.ipa"
    ;;
  *)
    echo "未知参数: $ACTION (可用: sim | device | archive | ipa | paths)"
    exit 1
    ;;
esac

echo "==> 构建完成。所有派生数据位于: $DERIVED_DATA"
echo "==> 运行后调试日志: $JEV_CACHE_ROOT/logs/jev-diag.log"
