#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] LICENSE [DIRECTORY]

Add license headers to source files using lice.

Required positional arguments:
  LICENSE       License name supported by lice (e.g. apache, mit, gpl3). See 'lice --help' for options.

Required options:
  -y YEAR       Year (e.g. 2026)
  -o ORG        Organization / author name

Optional positional arguments:
  DIRECTORY     Directory to search (defaults to current directory)

Optional options (at least one required):
  -s            Include shell files (*.sh, *.bash, *.zsh)
  -p            Include Python files (*.py)
  -c            Include C/C++ files (*.c, *.cpp, *.h, *.hpp)
  -j            Include JSONC files (*.jsonc)
  -Y            Include YAML files (*.yaml, *.yml)
  -h            Show this help message
EOF
    exit 1
}

YEAR=""
ORG=""
DO_SHELL=false
DO_PYTHON=false
DO_CPP=false
DO_JSONC=false
DO_YAML=false

while getopts "y:o:spcjYh" opt; do
    case "$opt" in
        y) YEAR="$OPTARG" ;;
        o) ORG="$OPTARG" ;;
        s) DO_SHELL=true ;;
        p) DO_PYTHON=true ;;
        c) DO_CPP=true ;;
        j) DO_JSONC=true ;;
        Y) DO_YAML=true ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
    echo "Error: LICENSE is required." >&2
    usage
fi

LICENSE="$1"
SEARCH_DIR="${2:-.}"

if [[ -z "$YEAR" ]]; then
    echo "Error: -y YEAR is required." >&2
    usage
fi

if [[ -z "$ORG" ]]; then
    echo "Error: -o ORG is required." >&2
    usage
fi

if ! $DO_SHELL && ! $DO_PYTHON && ! $DO_CPP && ! $DO_JSONC && ! $DO_YAML; then
    echo "Error: at least one file type flag (-s, -p, -c, -j, -Y) is required." >&2
    usage
fi

if ! command -v lice &> /dev/null; then
    echo "Error: 'lice' command not found. Please install lice via 'pipx install lice'." >&2
    exit 1
fi

COPYRIGHT_LINE="Copyright $YEAR $ORG"

process_file() {
    : "
    Prepend a lice-generated license header to a file.
    Skips the file if the copyright line is already present. Preserves
    shebang and Python encoding lines at the top of the file.

    Args:
      file  Path to the file to update.
      lang  lice language code for comment formatting (e.g. 'sh', 'py', 'cpp').
    Outputs:
      Prints 'Updated: <file>' if the file was modified.
    Returns:
      0 always.
    "
    local file="$1" lang="$2"

    if grep -qF "$COPYRIGHT_LINE" "$file"; then
        return
    fi

    local header=$(lice --header -o "$ORG" -y "$YEAR" -l "$lang" "$LICENSE" 2>/dev/null | sed '/./,$!d')
    local tmp=$(mktemp)

    {
        local first_line second_line
        first_line=$(sed -n '1p' "$file")
        second_line=$(sed -n '2p' "$file")

        if [[ "$first_line" == '#!'* ]]; then
            printf "%s\n" "$first_line"
            if [[ "$second_line" =~ coding[:=] ]]; then
                printf "%s\n\n" "$second_line"
                printf "%s\n\n" "$header"
                tail -n +3 "$file"
            else
                printf "\n%s\n\n" "$header"
                tail -n +2 "$file"
            fi
        else
            printf "%s\n\n" "$header"
            cat "$file"
        fi
    } > "$tmp"

    mv "$tmp" "$file"
    echo "Updated: $file"
}

build_find_args() {
    : "
    Emit NUL-delimited find(1) -name arguments for the enabled file types.
    Each token is printed with printf '%s\0' so the caller can read them
    into an array with mapfile -d ''.

    Args:
      None (reads DO_SHELL, DO_PYTHON, DO_CPP, DO_JSONC, DO_YAML globals).
    Outputs:
      NUL-delimited sequence of -name / -o -name tokens for find(1).
    Returns:
      0 always.
    "
    local args=()
    local first=true

    add_names() {
        for name in "$@"; do
            if $first; then
                args+=(-name "$name")
                first=false
            else
                args+=(-o -name "$name")
            fi
        done
    }

    $DO_SHELL  && add_names "*.sh" "*.bash" "*.zsh"
    $DO_PYTHON && add_names "*.py"
    $DO_CPP    && add_names "*.c" "*.cpp" "*.h" "*.hpp"
    $DO_JSONC  && add_names "*.jsonc"
    $DO_YAML   && add_names "*.yaml" "*.yml"

    printf '%s\0' "${args[@]}"
}

# Collect find args into an array via NUL-delimited output
mapfile -d '' FIND_ARGS < <(build_find_args)

while IFS= read -r -d '' file; do
    case "$file" in
        *.sh|*.bash|*.zsh) process_file "$file" "sh" ;;
        *.py)              process_file "$file" "py" ;;
        *.yaml|*.yml)      process_file "$file" "sh" ;;
        *.c)               process_file "$file" "c" ;;
        *.cpp)             process_file "$file" "cpp" ;;
        *.h)               process_file "$file" "h" ;;
        *.hpp)             process_file "$file" "hpp" ;;
        *.jsonc)           process_file "$file" "js" ;;
    esac
done < <(find "$SEARCH_DIR" -type f \( "${FIND_ARGS[@]}" \) -print0)
