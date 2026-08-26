#!/usr/bin/env bash
set -euo pipefail

ENGINE_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_PROJECT_ROOT="$(cd "$ENGINE_COMMON_DIR/.." && pwd)"

gamma_engine_artifacts_dir() {
  printf '%s\n' "${GAMMA_ENGINE_ARTIFACTS_DIR:-${CYDER_ENGINE_ARTIFACTS_DIR:-$ENGINE_PROJECT_ROOT/dist/artifacts}}"
}

gamma_crossover_version() {
  printf '%s\n' "${GAMMA_CROSSOVER_VERSION:-${CYDER_CROSSOVER_VERSION:-26.3.0}}"
}

gamma_engine_version_label_trim() {
  local ver="$1"
  ver="${ver//$'\r'/}"
  ver="${ver#"${ver%%[![:space:]]*}"}"
  ver="${ver%"${ver##*[![:space:]]}"}"
  printf '%s\n' "$ver"
}

gamma_format_engine_version_from_wine() {
  local wine_bin="${1:-}"
  local wine_raw wine_ver cx_ver
  local version_label="${GAMMA_ENGINE_VERSION_LABEL:-${CYDER_ENGINE_VERSION_LABEL:-}}"
  if [[ -n "$version_label" ]]; then
    gamma_engine_version_label_trim "$version_label"
    return 0
  fi
  if [[ -z "$wine_bin" && -n "${WINE_INSTALL:-}" ]]; then
    wine_bin="$WINE_INSTALL/bin/wine"
  fi
  [[ -x "$wine_bin" ]] || return 1
  wine_raw="$(arch -x86_64 "$wine_bin" --version 2>/dev/null || true)"
  wine_ver="${wine_raw#wine-}"
  cx_ver="$(gamma_crossover_version)"
  printf 'wine crossover %s (wine %s)\n' "$cx_ver" "$wine_ver"
}

gamma_detect_engine_version_label() {
  gamma_format_engine_version_from_wine "${1:-}"
}

gamma_engine_version_slug_from_label() {
  local label="$1"
  local slug cx wine_ver tail
  label="$(gamma_engine_version_label_trim "$label")"
  if [[ "$label" == wine\ crossover\ * ]]; then
    cx="${label#wine crossover }"
    cx="${cx%% (wine *)}"
    wine_ver="${label#* (wine }"
    wine_ver="${wine_ver%)}"
    slug="crossover-${cx}-wine-${wine_ver}"
    slug="${slug// /-}"
    printf '%s\n' "$slug"
    return 0
  fi
  if [[ "$label" == wine\ sikarugir\ * || "$label" == wine\ Sikarugir\ * ]]; then
    tail="${label#wine sikarugir }"
    if [[ "$tail" == "$label" ]]; then
      tail="${label#wine Sikarugir }"
    fi
    slug="sikarugir-${tail}"
    slug="$(printf '%s' "$slug" | tr ' .()/' '-' | tr -s '-')"
    slug="${slug#-}"
    slug="${slug%-}"
    printf '%s\n' "$slug"
    return 0
  fi
  slug="$label"
  slug="$(printf '%s' "$slug" | tr ' .()/' '-' | tr -s '-')"
  slug="${slug#-}"
  slug="${slug%-}"
  printf '%s\n' "$slug"
}

gamma_engine_versions_equal() {
  local left right left_slug right_slug
  left="$(gamma_engine_version_label_trim "${1:-}")"
  right="$(gamma_engine_version_label_trim "${2:-}")"
  [[ -n "$left" && -n "$right" ]] || return 1
  [[ "$left" == "$right" ]] && return 0
  left_slug="$(gamma_engine_version_slug_from_label "$left")"
  right_slug="$(gamma_engine_version_slug_from_label "$right")"
  [[ "$left_slug" == "$right" || "$left" == "$right_slug" || "$left_slug" == "$right_slug" ]]
}

gamma_read_engine_version_file() {
  local engine_root="$1"
  local ver
  [[ -f "$engine_root/version" ]] || return 1
  ver="$(gamma_engine_version_label_trim "$(cat "$engine_root/version")")"
  [[ -n "$ver" ]] || return 1
  printf '%s\n' "$ver"
}

gamma_write_engine_version_file() {
  local engine_root="$1"
  local ver="$2"
  ver="$(gamma_engine_version_label_trim "$ver")"
  [[ -n "$ver" ]] || return 1
  printf '%s\n' "$ver" >"$engine_root/version"
}

gamma_engine_version_from_tarball() {
  local tarball="$1"
  local ver
  ver="$(tar -xOf "$tarball" wswine.bundle/version 2>/dev/null | head -1 || true)"
  ver="$(gamma_engine_version_label_trim "$ver")"
  [[ -n "$ver" ]] || return 1
  printf '%s\n' "$ver"
}

# Explicit artifact basename (no extension). Order of precedence:
#   GAMMA_ENGINE_ARTIFACT_BASENAME -> artifactBasename in engine-release.json
#   -> empty, meaning "fall back to the version-derived name".
gamma_engine_artifact_basename() {
  local config="${GAMMA_ENGINE_RELEASE_CONFIG:-${CYDER_ENGINE_RELEASE_CONFIG:-$ENGINE_PROJECT_ROOT/config/engine-release.json}}"
  local name="${GAMMA_ENGINE_ARTIFACT_BASENAME:-}"
  if [[ -z "$name" && -f "$config" ]]; then
    name="$(sed -n 's/.*"artifactBasename"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config" | head -n 1)"
  fi
  printf '%s\n' "$name"
}

gamma_engine_archive_path_for_format() {
  local ver="$1"
  local dir="${2:-$(gamma_engine_artifacts_dir)}"
  local format="${3:-xz}"
  local base
  base="$(gamma_engine_artifact_basename)"
  if [[ -n "$base" ]]; then
    case "$format" in
      zst | zstd) printf '%s/%s.tar.zst\n' "$dir" "$base" ; return 0 ;;
      xz) printf '%s/%s.tar.xz\n' "$dir" "$base" ; return 0 ;;
    esac
  fi
  case "$format" in
    zst | zstd) printf '%s/engine-%s.tar.zst\n' "$dir" "$ver" ;;
    xz) printf '%s/gamma-wine-x86_64-%s.tar.xz\n' "$dir" "$ver" ;;
    *)
      echo "Unknown engine archive format: $format" >&2
      return 1
      ;;
  esac
}

gamma_find_zstd() {
  local candidate
  for candidate in \
    "${GAMMA_ZSTD:-}" \
    "$ENGINE_PROJECT_ROOT/tools/zstd/zstd" \
    "$(command -v zstd 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s/%s\n' "$(cd "$(dirname "$candidate")" && pwd -P)" "$(basename "$candidate")"
      return 0
    fi
  done
  return 1
}
