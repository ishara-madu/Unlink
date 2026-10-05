#!/bin/bash
set -e

# ==============================================================================
# Unlink - Release Packaging Script (Universal 2 Binary + DMG + Zip)
# ==============================================================================

echo "🚀 Building Unlink for Universal 2 (Apple Silicon + Intel)..."

# 1. Compile both architectures
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx

# 2. Package App Bundle
rm -rf build
mkdir -p build/Unlink.app/Contents/{MacOS,Resources}
cp Resources/Info.plist build/Unlink.app/Contents/
cp Resources/AppIcon.icns build/Unlink.app/Contents/Resources/

# 3. Create Universal Binary using lipo
echo "📦 Combining architectures with lipo..."
lipo -create -output build/Unlink.app/Contents/MacOS/Unlink \
  .build/arm64-apple-macosx/release/Unlink \
  .build/x86_64-apple-macosx/release/Unlink

echo "✅ Universal Binary verified:"
file build/Unlink.app/Contents/MacOS/Unlink

# 4. Create Standalone Zip
echo "📦 Creating Unlink.zip..."
(cd build && zip -q -r -y Unlink.zip Unlink.app)

# 5. Create DMG (Drag to Applications Installer)
echo "💿 Creating Unlink.dmg..."
mkdir -p build/dmg_staging
cp -R build/Unlink.app build/dmg_staging/
ln -s /Applications build/dmg_staging/Applications
hdiutil create -volname "Unlink" -srcfolder build/dmg_staging -ov -format UDZO build/Unlink.dmg
rm -rf build/dmg_staging

# 6. Generate SHA-256 Checksums
echo "🔒 Generating Checksums..."
(cd build && shasum -a 256 Unlink.dmg Unlink.zip > checksums.txt)

echo "🎉 Release files ready in build/:"
ls -lh build/Unlink.dmg build/Unlink.zip build/checksums.txt
cat build/checksums.txt
