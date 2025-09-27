#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -CeEuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# check for jq
check_jq

if [[ -z "${INPUT_API_BASE_URL:-}" ]]; then
  API_BASE_URL="https://api.ucdjs.dev/api"
else
  case "${INPUT_API_BASE_URL}" in
    */api) API_BASE_URL="${INPUT_API_BASE_URL}" ;;
    *)     API_BASE_URL="${INPUT_API_BASE_URL}/api" ;;
  esac
fi

info "🔍 checking for new releases"
info "🔗 api base url: ${API_BASE_URL}"

UNICODE_VERSIONS=$(fetch_with_retry "${API_BASE_URL}/v1/versions" "all versions")
validate_json "${UNICODE_VERSIONS}" "all versions"

DRAFT_README=$(fetch_with_retry "${API_BASE_URL}/v1/files/draft/ReadMe.txt" "draft README")
LATEST_README=$(fetch_with_retry "${API_BASE_URL}/v1/files/UCD/latest/ReadMe.txt" "latest release README")

info "🔍 extracting versions from README files"

# when there is no draft the draft readme is set to
# "There is no current draft for the Unicode Standard or data files at this time."
# But since this string could change, we just check if it matches "no current draft", or is totally empty

if [[ "${DRAFT_README}" == *"no current draft"* || -z "${DRAFT_README}" ]]; then
    DRAFT_VERSION=""
else
    DRAFT_VERSION=$(extract_from_readme "${DRAFT_README}")
fi

LATEST_RELEASE=$(extract_from_readme "${LATEST_README}")

info "🔍 validating extracted versions"

# validate extracted versions
if [[ -z "${DRAFT_VERSION}" ]]; then
    warn "could not extract draft version from README"
fi

if [[ -z "${LATEST_RELEASE}" ]]; then
    warn "could not extract latest release version from README"
fi

info "📝 latest release: ${LATEST_RELEASE}"
info "📝 latest draft: ${DRAFT_VERSION}"
info "📦 all releases count: $(echo "${UNICODE_VERSIONS}" | jq length)"

{
    printf 'current_draft=%s\n' "${DRAFT_VERSION}"
    printf 'latest_release=%s\n' "${LATEST_RELEASE}"
    printf 'all_releases=%s\n' "$(echo "${UNICODE_VERSIONS}" | jq -c .)"
} >>"${GITHUB_OUTPUT}"

info "✅ outputs generated successfully"
