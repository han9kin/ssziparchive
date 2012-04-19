#!/bin/sh
#
#
# script to create iOS Universal Framework from iOS Statatic Library Target
#
# - Add 'Run Script Build Phase' to execute this script into the Library Target
#
# - This script will create universal framework only if the following Build Settings matches
#
#   Build Active Architecture Only = NO
#
# - The universal framework will be created in the following directory
#
#   $(BUILD_ROOT)/$(CONFIGURATION)-iphoneuniversal
#
# - Following Build Settings are recommended
#
#   Debug Information Format   = DWARF
#   Strip Linked Product       = NO
#   Public Headers Folder Path = include/$(PRODUCT_NAME)
#
#

set -e

if [[ "$ONLY_ACTIVE_ARCH" = "YES" ]]
then
    # Do nothing if Build Active Architecture Only = YES
    exit 0
fi

set +u
if [[ $UFW_MASTER_SCRIPT_RUNNING ]]
then
    # Nothing for the slave script to do
    exit 0
fi
set -u
export UFW_MASTER_SCRIPT_RUNNING=1


# Sanity check

if [[ ! -f "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" ]]
then
    echo "Framework target \"${TARGET_NAME}\" had no source files to build from. Make sure your source files have the correct target membership"
    exit 1
fi


# Gather information

if [[ "$SDK_NAME" =~ ([A-Za-z]+) ]]
then
    UFW_SDK_PLATFORM=${BASH_REMATCH[1]}
else
    echo "Could not find platform name from SDK_NAME: $SDK_NAME"
    exit 1
fi

if [[ "$SDK_NAME" =~ ([0-9]+.*$) ]]
then
    UFW_SDK_VERSION=${BASH_REMATCH[1]}
else
    echo "Could not find sdk version from SDK_NAME: $SDK_NAME"
    exit 1
fi

if [[ "$UFW_SDK_PLATFORM" = "iphoneos" ]]
then
    UFW_OTHER_PLATFORM=iphonesimulator
else
    UFW_OTHER_PLATFORM=iphoneos
fi

if [[ "$BUILT_PRODUCTS_DIR" =~ (.*)$UFW_SDK_PLATFORM$ ]]
then
    UFW_OTHER_BUILT_PRODUCTS_DIR="${BASH_REMATCH[1]}${UFW_OTHER_PLATFORM}"
    UFW_UNIVERSAL_BUILT_PRODUCTS_DIR="${BASH_REMATCH[1]}iphoneuniversal"
else
    echo "Could not find $UFW_SDK_PLATFORM in $BUILT_PRODUCTS_DIR"
    exit 1
fi


# Make sure the other platform gets built

echo "===== Build other platform ====="

echo xcodebuild -project "${PROJECT_FILE_PATH}" -target "${TARGET_NAME}" -configuration "${CONFIGURATION}" -sdk ${UFW_OTHER_PLATFORM}${UFW_SDK_VERSION} BUILD_DIR="${BUILD_DIR}" CONFIGURATION_TEMP_DIR="${PROJECT_TEMP_DIR}/${CONFIGURATION}-${UFW_OTHER_PLATFORM}" clean $ACTION
xcodebuild -project "${PROJECT_FILE_PATH}" -target "${TARGET_NAME}" -configuration "${CONFIGURATION}" -sdk ${UFW_OTHER_PLATFORM}${UFW_SDK_VERSION} BUILD_DIR="${BUILD_DIR}" CONFIGURATION_TEMP_DIR="${PROJECT_TEMP_DIR}/${CONFIGURATION}-${UFW_OTHER_PLATFORM}" clean $ACTION


# Build universal framework

UFW_WRAPPER_NAME="${PRODUCT_NAME}.framework"
UFW_CONTENTS_DIR="${UFW_WRAPPER_NAME}/Versions/A"

echo "===== Build universal framework ====="

echo rm -rf "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}"
rm -rf "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}"

echo mkdir -p "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}"
mkdir -p "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}"

echo "${PLATFORM_DEVELOPER_BIN_DIR}/libtool" -static "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" "${UFW_OTHER_BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" -o "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/${PRODUCT_NAME}"
"${PLATFORM_DEVELOPER_BIN_DIR}/libtool" -static "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" "${UFW_OTHER_BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" -o "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/${PRODUCT_NAME}"

if [[ -d "${BUILT_PRODUCTS_DIR}/${PUBLIC_HEADERS_FOLDER_PATH}" ]]
then
    echo cp -R "${BUILT_PRODUCTS_DIR}/${PUBLIC_HEADERS_FOLDER_PATH}" "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/Headers"
    cp -R "${BUILT_PRODUCTS_DIR}/${PUBLIC_HEADERS_FOLDER_PATH}" "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/Headers"
else
    echo mkdir -p "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/Headers"
    mkdir -p "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/Headers"
fi

echo mkdir -p "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/Resources"
mkdir -p "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/Resources"

cat > "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_CONTENTS_DIR}/Resources/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildMachineOSBuild</key>
	<string>${MAC_OS_X_PRODUCT_BUILD_VERSION}</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>ios.framework.static.${PRODUCT_NAME}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${PRODUCT_NAME}</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>DTCompiler</key>
	<string>${GCC_VERSION}</string>
	<key>DTPlatformBuild</key>
	<string>${XCODE_PRODUCT_BUILD_VERSION}</string>
	<key>DTPlatformVersion</key>
	<string>GM</string>
	<key>DTSDKBuild</key>
	<string>${MAC_OS_X_PRODUCT_BUILD_VERSION}</string>
	<key>DTSDKName</key>
	<string>${SDK_NAME}</string>
	<key>DTXcode</key>
	<string>${XCODE_VERSION_ACTUAL}</string>
	<key>DTXcodeBuild</key>
	<string>${XCODE_PRODUCT_BUILD_VERSION}</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © $(date +%Y) nobody. All rights reserved.</string>
</dict>
</plist>
EOF

echo ln -sf A "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/Versions/Current"
ln -sf A "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/Versions/Current"
echo ln -sf Versions/Current/Headers "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/Headers"
ln -sf Versions/Current/Headers "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/Headers"
echo ln -sf Versions/Current/Resources "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/Resources"
ln -sf Versions/Current/Resources "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/Resources"
echo ln -sf "Versions/Current/${PRODUCT_NAME}" "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/${PRODUCT_NAME}"
ln -sf "Versions/Current/${PRODUCT_NAME}" "${UFW_UNIVERSAL_BUILT_PRODUCTS_DIR}/${UFW_WRAPPER_NAME}/${PRODUCT_NAME}"
