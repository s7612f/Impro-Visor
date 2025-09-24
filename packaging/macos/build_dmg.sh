#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"

APP_NAME="Impro-Visor"
OUTPUT_DIR="${PROJECT_ROOT}/build/distributions"
REQUESTED_VERSION=""
SKIP_CLEAN="false"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --app-version <version>   Override the application version embedded in the DMG name.
  --dest <path>             Directory where the DMG should be written (default: build/distributions).
  --skip-clean              Do not run 'ant clean' before building the distribution.
  -h, --help                Show this help message.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-version)
      [[ $# -ge 2 ]] || { echo "Missing value for --app-version" >&2; exit 1; }
      REQUESTED_VERSION="$2"
      shift 2
      ;;
    --dest)
      [[ $# -ge 2 ]] || { echo "Missing value for --dest" >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --skip-clean)
      SKIP_CLEAN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

command -v ant >/dev/null 2>&1 || { echo "ant is required to build the distribution." >&2; exit 1; }
command -v jpackage >/dev/null 2>&1 || { echo "jpackage is required to create the DMG." >&2; exit 1; }

if [[ "${SKIP_CLEAN}" != "true" ]]; then
  ant clean
fi

ant dist

DEFAULT_VERSION=""
if [[ -n "${REQUESTED_VERSION}" ]]; then
  APP_VERSION="${REQUESTED_VERSION}"
else
  if [[ -x /usr/libexec/PlistBuddy && -f packaging/Info.plist ]]; then
    DEFAULT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" packaging/Info.plist 2>/dev/null || true)
  fi
  if [[ -z "${DEFAULT_VERSION}" ]]; then
    if [[ -f src/imp/ImproVisor.java ]]; then
      DEFAULT_VERSION=$(grep -E "public static final String version" src/imp/ImproVisor.java | sed -E 's/.*"([^"]+)".*/\1/' || true)
    fi
  fi
  APP_VERSION="${DEFAULT_VERSION:-10.2}"
fi

mkdir -p "${OUTPUT_DIR}"

APP_IMAGE_DIR="improvisor1020"
if [[ ! -d "${APP_IMAGE_DIR}" ]]; then
  echo "Expected distribution directory '${APP_IMAGE_DIR}' was not created." >&2
  exit 1
fi

DMG_BASENAME="${APP_NAME}-${APP_VERSION}"
ARCH_NAME="$(uname -m)"
TARGET_DMG="${OUTPUT_DIR}/${DMG_BASENAME}-macOS-${ARCH_NAME}.dmg"

rm -f "${OUTPUT_DIR}/${APP_NAME}-${APP_VERSION}.dmg" "${TARGET_DMG}"

jpackage \
  --type dmg \
  --name "${APP_NAME}" \
  --input "${APP_IMAGE_DIR}" \
  --main-jar improvisor.jar \
  --main-class imp.ImproVisor \
  --app-version "${APP_VERSION}" \
  --icon packaging/ImproVisor.icns \
  --dest "${OUTPUT_DIR}" \
  --java-options "-Dimprovisor.install.root=\$APPDIR/app" \
  --vendor "Impro-Visor Project" \
  --mac-package-name "${APP_NAME}" \
  --mac-package-identifier "com.improvisor.app"

if [[ -f "${OUTPUT_DIR}/${APP_NAME}-${APP_VERSION}.dmg" ]]; then
  mv "${OUTPUT_DIR}/${APP_NAME}-${APP_VERSION}.dmg" "${TARGET_DMG}"
fi

echo "Created DMG: ${TARGET_DMG}"
