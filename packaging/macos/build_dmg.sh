#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"

APP_NAME="Impro-Visor"
OUTPUT_DIR="${PROJECT_ROOT}/build/distributions"
REQUESTED_VERSION=""
SKIP_CLEAN="false"
DIST_DIR_NAME=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --app-version <version>   Override the application version embedded in the DMG name.
  --dest <path>             Directory where the DMG should be written (default: build/distributions).
  --skip-clean              Do not run 'ant clean' before building the distribution.
  --dist-dir <name>         Override the Ant distribution directory (default: auto-detected).
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
    --dist-dir)
      [[ $# -ge 2 ]] || { echo "Missing value for --dist-dir" >&2; exit 1; }
      DIST_DIR_NAME="$2"
      shift 2
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
command -v tar >/dev/null 2>&1 || { echo "tar is required to stage resources for jpackage." >&2; exit 1; }

if [[ "${SKIP_CLEAN}" != "true" ]]; then
  ant clean
fi

ant dist

if [[ -z "${DIST_DIR_NAME}" ]]; then
  if [[ -f build.xml ]]; then
    DIST_DIR_NAME=$(grep -E '<property\s+name="distDir"' build.xml | head -n1 | sed -E 's/.*value="([^"]+)".*/\1/' || true)
  fi
  DIST_DIR_NAME="${DIST_DIR_NAME:-improvisor1020}"
fi

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

APP_IMAGE_DIR="${DIST_DIR_NAME}"
if [[ ! -d "${APP_IMAGE_DIR}" ]]; then
  echo "Expected distribution directory '${APP_IMAGE_DIR}' was not created." >&2
  exit 1
fi

DMG_BASENAME="${APP_NAME}-${APP_VERSION}"
ARCH_NAME="$(uname -m)"
TARGET_DMG="${OUTPUT_DIR}/${DMG_BASENAME}-macOS-${ARCH_NAME}.dmg"

rm -f "${OUTPUT_DIR}/${APP_NAME}-${APP_VERSION}.dmg" "${TARGET_DMG}"

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/improvisor-mac.XXXXXX")"
cleanup() {
  rm -rf "${STAGING_ROOT}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

INPUT_DIR="${STAGING_ROOT}/input"
RESOURCE_DIR="${STAGING_ROOT}/resources"
mkdir -p "${INPUT_DIR}" "${RESOURCE_DIR}"

if [[ ! -f "${APP_IMAGE_DIR}/improvisor.jar" ]]; then
  echo "Could not find improvisor.jar in '${APP_IMAGE_DIR}'." >&2
  exit 1
fi

cp "${APP_IMAGE_DIR}/improvisor.jar" "${INPUT_DIR}/"
tar -C "${APP_IMAGE_DIR}" --exclude "improvisor.jar" -cf - . | tar -C "${RESOURCE_DIR}" -xf -

jpackage \
  --type dmg \
  --name "${APP_NAME}" \
  --input "${INPUT_DIR}" \
  --resource-dir "${RESOURCE_DIR}" \
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
