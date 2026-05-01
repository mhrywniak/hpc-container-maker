#!/usr/bin/env bash
# Regenerate the API reference under docs/ using a pinned toolchain
#
# Background:
#   - The committed docs/ files were generated with pydoc-markdown==2.0.5
#     under Python 2.7. Newer pydoc-markdown 2.1.x changed the `simple`
#     preprocessor to reset the active section on blank lines, which breaks
#     the "- __param__: description" formatting that HPCCM docstrings rely
#     on (every parameter ends up unbulleted/unbolded).
#   - pydoc-markdown 2.0.5 itself uses `yaml.load(fp)` without a Loader
#     argument, which raises a TypeError under modern PyYAML (>= 5). We
#     monkey-patch that single call to use yaml.safe_load.
#   - pydoc-markdown 2.x relies on the (removed in 3.12) `imp` module, so
#     we pin Python to 3.11, and it is no longer updated
#
# Usage:
#   ./regenerate-docs.sh           # regenerate in-place
#   ./regenerate-docs.sh --check   # regenerate and `git diff` the result

set -euo pipefail

cd "$(dirname "$0")"

PYTHON_VERSION="3.11"
PYDOCMD_VERSION="2.0.5"
VENV_DIR=".venv-pydocmd"

if ! command -v uv >/dev/null 2>&1; then
    echo "error: uv is required (https://docs.astral.sh/uv/)" >&2
    exit 1
fi

if [[ ! -d "${VENV_DIR}" ]]; then
    uv venv -p "${PYTHON_VERSION}" "${VENV_DIR}"
fi

uv pip install --python "${VENV_DIR}/bin/python" --quiet \
    "pydoc-markdown==${PYDOCMD_VERSION}" \
    -e .

# Patch pydoc-markdown 2.0.5 to use yaml.safe_load (modern PyYAML compat).
PYDOCMD_MAIN="${VENV_DIR}/lib/python${PYTHON_VERSION}/site-packages/pydocmd/__main__.py"
if grep -q 'yaml.load(fp)' "${PYDOCMD_MAIN}"; then
    sed -i 's/yaml\.load(fp)/yaml.safe_load(fp)/' "${PYDOCMD_MAIN}"
fi

"${VENV_DIR}/bin/pydocmd" generate

if [[ "${1:-}" == "--check" ]]; then
    git --no-pager diff --stat docs/
fi
