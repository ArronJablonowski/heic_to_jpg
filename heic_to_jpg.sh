#!/usr/bin/env bash
#
# heic_to_jpg.sh
#
# Convert HEIC/HEIF images to JPEG with ImageMagick.
# Designed for macOS, but works anywhere ImageMagick can read HEIC files.

set -euo pipefail

VERSION="1.0.0"

INPUT_DIR="."
OUTPUT_DIR=""
RECURSIVE=0
QUALITY=92
EXTENSION="jpg"
CONFLICT="skip"
DELETE_ORIGINALS=0
ASSUME_YES=0
DRY_RUN=0
VERBOSE=0
STRIP_METADATA=0
KEEP_DATES=0
RESIZE=""
SCALE=""

SCRIPT_NAME="$(basename "$0")"
SUCCESS_LIST=""

usage() {
  cat <<'EOF'
Convert HEIC/HEIF images to JPEG.

Usage:
  heic_to_jpg.sh [options]

Common examples:
  ./heic_to_jpg.sh
  ./heic_to_jpg.sh --input ~/Pictures --output ~/Pictures/jpg --recursive
  ./heic_to_jpg.sh --scale 50
  ./heic_to_jpg.sh --scale 125
  ./heic_to_jpg.sh --quality 85 --strip --conflict rename
  ./heic_to_jpg.sh --delete-originals --yes
  ./heic_to_jpg.sh --dry-run --recursive

Options:
  -i, --input DIR          Directory containing HEIC/HEIF files. Default: current directory.
  -o, --output DIR         Directory for JPEGs. Default: beside each source file.
  -r, --recursive          Include subdirectories. With --output, preserves folder structure.
  -q, --quality N          JPEG quality, 1-100. Default: 92.
      --scale PERCENT      Scale image dimensions by percent, e.g. 50, 125, or 12.5%.
      --resize GEOMETRY    Resize using ImageMagick geometry, e.g. 2048x2048>, 50%, 1600x.
      --strip              Remove metadata from output files.
      --keep-dates         Copy source modification date to the converted JPEG.
      --extension EXT      Output extension: jpg or jpeg. Default: jpg.
      --conflict MODE      What to do when output exists: skip, overwrite, rename. Default: skip.
      --delete-originals   Ask to remove originals after successful conversion.
  -y, --yes                Answer yes to prompts. Useful with --delete-originals.
  -n, --dry-run            Show what would happen without converting or deleting.
  -v, --verbose            Print each conversion command.
  -h, --help               Show this help.
      --version            Show version.

Requirements:
  ImageMagick with HEIC support. On macOS:
    brew install imagemagick
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$SUCCESS_LIST" && -f "$SUCCESS_LIST" ]]; then
    rm -f "$SUCCESS_LIST"
  fi
}
trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but was not found."
}

is_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

is_positive_percentage() {
  local value="${1%%%}"
  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  [[ "${value//[0.]/}" != "" ]]
}

absolute_path() {
  local path="$1"
  local dir
  local base

  if [[ -d "$path" ]]; then
    (cd "$path" && pwd -P)
  else
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
  fi
}

relative_to_input() {
  local source="$1"
  local prefix="$INPUT_DIR/"

  if [[ "$source" == "$prefix"* ]]; then
    printf '%s\n' "${source#"$prefix"}"
  else
    basename "$source"
  fi
}

without_extension() {
  local path="$1"
  printf '%s\n' "${path%.*}"
}

ensure_directory() {
  local dir="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  mkdir -p "$dir"
}

unique_destination() {
  local dest="$1"
  local base="${dest%.*}"
  local ext="${dest##*.}"
  local candidate="$dest"
  local index=1

  while [[ -e "$candidate" ]]; do
    candidate="${base}-${index}.${ext}"
    index=$((index + 1))
  done

  printf '%s\n' "$candidate"
}

destination_for() {
  local source="$1"
  local rel
  local rel_no_ext
  local dest

  if [[ -n "$OUTPUT_DIR" ]]; then
    rel="$(relative_to_input "$source")"
    rel_no_ext="$(without_extension "$rel")"
    dest="$OUTPUT_DIR/${rel_no_ext}.${EXTENSION}"
  else
    dest="$(without_extension "$source").${EXTENSION}"
  fi

  printf '%s\n' "$dest"
}

confirm() {
  local prompt="$1"
  local reply

  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi

  printf '%s [y/N] ' "$prompt"
  read -r reply
  case "$reply" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--input)
        [[ $# -ge 2 ]] || die "$1 requires a directory."
        INPUT_DIR="$2"
        shift 2
        ;;
      --input=*)
        INPUT_DIR="${1#*=}"
        shift
        ;;
      -o|--output)
        [[ $# -ge 2 ]] || die "$1 requires a directory."
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --output=*)
        OUTPUT_DIR="${1#*=}"
        shift
        ;;
      -r|--recursive)
        RECURSIVE=1
        shift
        ;;
      -q|--quality)
        [[ $# -ge 2 ]] || die "$1 requires a value from 1 to 100."
        QUALITY="$2"
        shift 2
        ;;
      --quality=*)
        QUALITY="${1#*=}"
        shift
        ;;
      --resize)
        [[ $# -ge 2 ]] || die "$1 requires an ImageMagick geometry value."
        RESIZE="$2"
        shift 2
        ;;
      --resize=*)
        RESIZE="${1#*=}"
        shift
        ;;
      --scale)
        [[ $# -ge 2 ]] || die "$1 requires a positive percentage."
        SCALE="$2"
        shift 2
        ;;
      --scale=*)
        SCALE="${1#*=}"
        shift
        ;;
      --strip)
        STRIP_METADATA=1
        shift
        ;;
      --keep-dates)
        KEEP_DATES=1
        shift
        ;;
      --extension)
        [[ $# -ge 2 ]] || die "$1 requires jpg or jpeg."
        EXTENSION="$2"
        shift 2
        ;;
      --extension=*)
        EXTENSION="${1#*=}"
        shift
        ;;
      --conflict)
        [[ $# -ge 2 ]] || die "$1 requires skip, overwrite, or rename."
        CONFLICT="$2"
        shift 2
        ;;
      --conflict=*)
        CONFLICT="${1#*=}"
        shift
        ;;
      --delete-originals)
        DELETE_ORIGINALS=1
        shift
        ;;
      -y|--yes)
        ASSUME_YES=1
        shift
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --version)
        printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        die "Unexpected argument: $1"
        ;;
    esac
  done
}

validate_config() {
  require_command magick

  [[ -d "$INPUT_DIR" ]] || die "Input directory does not exist: $INPUT_DIR"
  INPUT_DIR="$(absolute_path "$INPUT_DIR")"

  if [[ -n "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(absolute_path "$OUTPUT_DIR")"
  fi

  is_integer "$QUALITY" || die "Quality must be an integer from 1 to 100."
  [[ "$QUALITY" -ge 1 && "$QUALITY" -le 100 ]] || die "Quality must be between 1 and 100."

  if [[ -n "$SCALE" ]]; then
    is_positive_percentage "$SCALE" || die "Scale must be a positive percentage, such as 50, 125, or 12.5%."
    SCALE="${SCALE%%%}"
  fi

  if [[ -n "$SCALE" && -n "$RESIZE" ]]; then
    die "Use either --scale or --resize, not both."
  fi

  EXTENSION="${EXTENSION#.}"
  case "$EXTENSION" in
    jpg|jpeg) ;;
    JPG) EXTENSION="jpg" ;;
    JPEG) EXTENSION="jpeg" ;;
    *) die "Extension must be jpg or jpeg." ;;
  esac

  case "$CONFLICT" in
    skip|overwrite|rename) ;;
    *) die "Conflict mode must be skip, overwrite, or rename." ;;
  esac

  if [[ "$DELETE_ORIGINALS" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
    warn "--delete-originals is ignored during --dry-run."
  fi
}

convert_one() {
  local source="$1"
  local dest
  local dest_dir
  local cmd

  dest="$(destination_for "$source")"

  if [[ -e "$dest" ]]; then
    case "$CONFLICT" in
      skip)
        printf 'skip: %s -> %s (exists)\n' "$source" "$dest"
        return 2
        ;;
      overwrite)
        ;;
      rename)
        dest="$(unique_destination "$dest")"
        ;;
    esac
  fi

  dest_dir="$(dirname "$dest")"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'would convert: %s -> %s\n' "$source" "$dest"
    return 0
  fi

  ensure_directory "$dest_dir"

  cmd=(magick "$source" -auto-orient -quality "$QUALITY")
  if [[ -n "$SCALE" ]]; then
    cmd+=(-resize "${SCALE}%")
  fi
  if [[ -n "$RESIZE" ]]; then
    cmd+=(-resize "$RESIZE")
  fi
  if [[ "$STRIP_METADATA" -eq 1 ]]; then
    cmd+=(-strip)
  fi
  cmd+=("$dest")

  if [[ "$VERBOSE" -eq 1 ]]; then
    printf 'convert: %s -> %s\n' "$source" "$dest"
  fi

  if "${cmd[@]}"; then
    if [[ "$KEEP_DATES" -eq 1 ]]; then
      touch -r "$source" "$dest"
    fi
    printf '%s\0' "$source" >> "$SUCCESS_LIST"
    printf 'done: %s -> %s\n' "$source" "$dest"
    return 0
  fi

  warn "Failed to convert: $source"
  return 1
}

find_sources() {
  local source

  if [[ "$RECURSIVE" -eq 1 ]]; then
    find "$INPUT_DIR" -type f \( -iname '*.heic' -o -iname '*.heif' \) -print0
  else
    shopt -s nullglob nocaseglob
    for source in "$INPUT_DIR"/*.heic "$INPUT_DIR"/*.heif; do
      [[ -f "$source" ]] && printf '%s\0' "$source"
    done
    shopt -u nullglob nocaseglob
  fi
}

delete_successful_originals() {
  local source
  local deleted=0

  [[ "$DELETE_ORIGINALS" -eq 1 ]] || return 0
  [[ "$DRY_RUN" -eq 0 ]] || return 0
  [[ -s "$SUCCESS_LIST" ]] || return 0

  if ! confirm "Remove successfully converted HEIC/HEIF originals?"; then
    log "Originals kept."
    return 0
  fi

  while IFS= read -r -d '' source; do
    rm -f "$source"
    deleted=$((deleted + 1))
  done < "$SUCCESS_LIST"

  log "Removed $deleted original file(s)."
}

main() {
  local source
  local converted=0
  local skipped=0
  local failed=0
  local found=0
  local status=0

  parse_args "$@"
  validate_config

  SUCCESS_LIST="$(mktemp "${TMPDIR:-/tmp}/heic-to-jpg.XXXXXX")"

  log "Input: $INPUT_DIR"
  if [[ -n "$OUTPUT_DIR" ]]; then
    log "Output: $OUTPUT_DIR"
  else
    log "Output: beside each source file"
  fi

  while IFS= read -r -d '' source; do
    found=$((found + 1))
    if convert_one "$source"; then
      converted=$((converted + 1))
    else
      status=$?
      if [[ "$status" -eq 2 ]]; then
        skipped=$((skipped + 1))
      else
        failed=$((failed + 1))
      fi
    fi
  done < <(find_sources)

  if [[ "$found" -eq 0 ]]; then
    log "No HEIC/HEIF files found."
    exit 0
  fi

  delete_successful_originals

  log "Summary: $converted converted, $skipped skipped, $failed failed."
  [[ "$failed" -eq 0 ]]
}

main "$@"
