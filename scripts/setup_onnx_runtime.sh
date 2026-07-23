#!/bin/bash
#
# setup_onnx_runtime.sh
# VTM 项目 — 下载 ONNX Runtime XCFramework + Objective-C 源码
#
# 用法:
#   cd VTM-ios/VTM
#   bash scripts/setup_onnx_runtime.sh
#
# 下载来源:
#   onnxruntime-c    (XCFramework 二进制): https://download.onnxruntime.ai/pod-archive-onnxruntime-c-1.26.0.zip
#   onnxruntime-objc  (Objective-C 封装源码): https://download.onnxruntime.ai/pod-archive-onnxruntime-objc-1.26.0.zip
#

set -euo pipefail

VERSION="1.26.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORKS_DIR="$PROJECT_DIR/Frameworks"
ONNX_DIR="$PROJECT_DIR/Services/ONNXRuntime"
TEMP_DIR="$PROJECT_DIR/.tmp_onnx"

C_URL="https://download.onnxruntime.ai/pod-archive-onnxruntime-c-${VERSION}.zip"
OBJC_URL="https://download.onnxruntime.ai/pod-archive-onnxruntime-objc-${VERSION}.zip"

echo "========================================"
echo " VTM: ONNX Runtime ${VERSION} Setup"
echo "========================================"
echo ""

# ── 清理旧的临时目录 ──
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$ONNX_DIR"

# ── 下载 onnxruntime-c (包含 onnxruntime.xcframework) ──
echo "[1/4] 下载 onnxruntime-c (XCFramework 二进制, ~54MB)..."
C_ZIP="$TEMP_DIR/onnxruntime-c.zip"
curl -fSL --progress-bar -o "$C_ZIP" "$C_URL"
echo "  ✓ 下载完成"

echo "[2/4] 解压 onnxruntime-c..."
unzip -qo "$C_ZIP" -d "$TEMP_DIR/onnxruntime-c"
echo "  ✓ 解压完成"

# 复制 XCFramework 到 Frameworks/
if [ -d "$TEMP_DIR/onnxruntime-c/onnxruntime.xcframework" ]; then
    rm -rf "$FRAMEWORKS_DIR/onnxruntime.xcframework"
    cp -R "$TEMP_DIR/onnxruntime-c/onnxruntime.xcframework" "$FRAMEWORKS_DIR/"
    echo "  ✓ onnxruntime.xcframework → Frameworks/"
else
    echo "  ✗ 错误: 未找到 onnxruntime.xcframework"
    echo "  解压内容:"
    ls -la "$TEMP_DIR/onnxruntime-c/"
    exit 1
fi

# ── 下载 onnxruntime-objc (Objective-C 封装源码) ──
echo "[3/4] 下载 onnxruntime-objc (Objective-C 封装源码)..."
OBJC_ZIP="$TEMP_DIR/onnxruntime-objc.zip"
curl -fSL --progress-bar -o "$OBJC_ZIP" "$OBJC_URL"
echo "  ✓ 下载完成"

echo "[4/4] 解压 onnxruntime-objc..."
unzip -qo "$OBJC_ZIP" -d "$TEMP_DIR/onnxruntime-objc"
echo "  ✓ 解压完成"

# 复制 objectivec/ 目录到 Services/ONNXRuntime/
OBJC_SRC="$TEMP_DIR/onnxruntime-objc/objectivec"
if [ -d "$OBJC_SRC" ]; then
    rm -rf "$ONNX_DIR"
    mkdir -p "$ONNX_DIR"
    cp -R "$OBJC_SRC" "$ONNX_DIR/"
    echo "  ✓ objectivec/ → Services/ONNXRuntime/"
else
    echo "  ✗ 错误: 未找到 objectivec/ 目录"
    echo "  解压内容:"
    ls -la "$TEMP_DIR/onnxruntime-objc/"
    exit 1
fi

# ── 清理 ──
rm -rf "$TEMP_DIR"

echo ""
echo "========================================"
echo " ONNX Runtime ${VERSION} 安装完成!"
echo "========================================"
echo ""
echo "  框架位置: Frameworks/onnxruntime.xcframework"
echo "  源码位置: Services/ONNXRuntime/"
echo ""
echo "  下一步: 用 XcodeGen 重新生成项目"
echo "    cd VTM-ios/VTM && xcodegen generate"
echo ""
