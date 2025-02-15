#!/bin/bash
#
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Usage:
#   $ release.sh [-f] <organization/project-name> [<new-version>]
#
#   Args:
#     organization/project-name    Required. The GitHub repo to release.
#     new-version                  Optional. The new version number to use,
#                                  specified as M.N.0. If not specified, the
#                                  new version will be computed from existing
#                                  git tags. This flag should only be needed
#                                  when jumping to a non-sequential version
#                                  number.
#
#   Options:
#     -f     Force; actually make and push the changes
#     -h     Print help message
#
# This script creates a "release" on github by doing the following:
#
#   1. Computes the next version to use, if not specified on the command line
#   2. Creates and pushes the tag w/ the new version
#   3. Creates and pushes a new branch w/ the new version
#   4. Creates the "Pre-Release" in the GitHub UI.
#
# Before running this script the user should make sure the CHANGELOG.md on
# main is up-to-date with the release notes for the new release that will
# happen. Then run this script. After running this script, the user must still
# go to the GH UI where the new release will exist as a "pre-release", confirm
# that everything looks OK, then mark the release as not pre-release.
#
# Examples:
#
#   # NO CHANGES ARE PUSHED. Shows what commands would be run.
#   $ release.sh googleapis/google-cloud-cpp
#
#   # NO CHANGES ARE PUSHED. Shows what commands would be run.
#   $ release.sh googleapis/google-cloud-cpp 2.0.0
#
#   # PUSHES CHANGES.
#   $ release.sh -f googleapis/google-cloud-cpp
#
#   # PUSHES CHANGES to your fork
#   $ release.sh -f <my-gh-username>/google-cloud-cpp

set -euo pipefail

# Extracts all the documentation at the top of this file as the usage text.
USAGE="$(sed -n '17,/^$/s/^# \?//p' "$0")"
readonly USAGE

# Takes an optional list of strings to be printed with a trailing newline and
# exits the program with code 1
function die_with_message() {
  for m in "$@"; do
    echo "$m" 1>&2
  done
  exit 1
}

FORCE_FLAG="no"
while getopts "fh" opt "$@"; do
  case "$opt" in
    [f])
      FORCE_FLAG="yes"
      ;;
    [h])
      echo "${USAGE}"
      exit 0
      ;;
    *)
      die_with_message "${USAGE}"
      ;;
  esac
done
shift $((OPTIND - 1))
declare -r FORCE_FLAG

REPO_ARG=""
VERSION_ARG=""
if [[ $# -eq 1 ]]; then
  REPO_ARG="$1"
elif [[ $# -eq 2 ]]; then
  REPO_ARG="$1"
  VERSION_ARG="$2"
else
  die_with_message "Invalid arguments" "${USAGE}"
fi
declare -r REPO_ARG
declare -r VERSION_ARG

readonly CLONE_URL="git@github.com:${REPO_ARG}"
TMP_DIR="$(mktemp -d "/tmp/${REPO_ARG//\//-}-release.XXXXXXXX")"
readonly TMP_DIR
readonly REPO_DIR="${TMP_DIR}/repo"

function banner() {
  local color
  color=$(
    tput bold
    tput setaf 4
    tput rev
  )
  local reset
  reset=$(tput sgr0)
  echo "${color}$*${reset}"
}

function run() {
  printf "#"
  printf " %q" "$@"
  printf "\n"
  if [[ "${FORCE_FLAG}" == "yes" ]]; then
    "$@"
  fi
}

# Outputs the release notes for the given tag. Looks for the release notes in
# the CHANGELOG.md file starting at a heading that looks like "## <tag>", and
# ending at the next heading that looks like `##` with a version number. For
# example `get_release_notes v0.6.0` would look for a line like "## v0.6.0" and
# stop at "## v0.5.0".
function get_release_notes() {
  local tag="$1"
  local begin="^## ${tag}"
  local end="^## v[0-9]+\.[0-9]+\.[0-9]"
  local notes
  # Note: the use of command substitution here removes trailing blank lines
  notes="$(awk "/${begin}/ {x=1; next} /${end}/ { x=0 } x" CHANGELOG.md)"
  # Removes leading blank lines
  sed '/./,$!d' <<<"${notes}"
}

function exit_handler() {
  if [[ -d "${TMP_DIR}" ]]; then
    banner "OOPS! Unclean shutdown"
    echo "Local repo at ${REPO_DIR}"
    echo 1
  fi
}
trap exit_handler EXIT

# We use github's official `gh` command to create the release on on the GH
# website, so we make sure it's installed early on so we don't fail after
# completing part of the release.
if ! command -v gh >/dev/null; then
  die_with_message \
    "Can't find 'gh' command." \
    "You can build from source or download a binary from" \
    "https://github.com/cli/cli"
fi
# Makes sure auth works, else fails
gh auth status

banner "Starting release for ${REPO_ARG} (${CLONE_URL})"
# Only clones the last 90 days worth of commits, which should be more than
# enough to get the most recent release tags.
SINCE="$(date --date="90 days ago" +"%Y-%m-%d")"
readonly SINCE
git clone --tags --shallow-since="${SINCE}" "${CLONE_URL}" "${REPO_DIR}"
cd "${REPO_DIR}"

# Figures out the most recent tagged version, and computes the next version.
TAG="$(git describe --tags --abbrev=0 origin/main)"
readonly TAG
CUR_TAG="$(test -n "${TAG}" && echo "${TAG}" || echo "v0.0.0")"
readonly CUR_TAG
readonly CUR_VERSION="${CUR_TAG#v}"

NEW_VERSION=""
if [[ -n "${VERSION_ARG}" ]]; then
  NEW_VERSION="${VERSION_ARG}"
else
  # Compute the new version by incrementing the minor number.
  NEW_VERSION="$(awk -F. '{printf "%d.%d.%d", $1, $2+1, $3}' <<<"${CUR_VERSION}")"
fi
declare -r NEW_VERSION

# Avoid handling patch releases for now, because we wouldn't need a new branch
# for those.
if ! grep -P "\d+\.\d+\.0" <<<"${NEW_VERSION}" >/dev/null; then
  die_with_message "Sorry, cannot handle patch releases (yet)" "${USAGE}"
fi

readonly NEW_TAG="v${NEW_VERSION}"
readonly NEW_BRANCH="${NEW_TAG%.0}.x"

banner "Release info for ${CUR_TAG} -> ${NEW_TAG}"
echo "    New tag: ${NEW_TAG}"
echo " New branch: ${NEW_BRANCH}"

banner "Creating and pushing tag ${NEW_TAG}"
run git tag "${NEW_TAG}"
run git push origin "${NEW_TAG}"

banner "Creating and pushing branch ${NEW_BRANCH}"
run git checkout -b "${NEW_BRANCH}" "${NEW_TAG}"
run git push --set-upstream origin "${NEW_BRANCH}"

banner "Getting release notes for ${NEW_TAG}"
RELEASE_NOTES="$(get_release_notes "${NEW_TAG}")"
readonly RELEASE_NOTES
echo "got release notes"

banner "Creating release"
run gh -R "${REPO_ARG}" release create \
  --prerelease \
  --title="${NEW_TAG}" \
  --notes-file=<(printf "%s" "${RELEASE_NOTES}") \
  "${NEW_TAG}"

banner "Success!"
run gh -R "${REPO_ARG}" release view "${NEW_TAG}"

# Clean up
if [[ "${TMP_DIR}" == /tmp/* ]]; then
  rm -rf "${TMP_DIR}"
fi
