#!/usr/bin/env bash

DIRECTORY=$1
SBOM_PATTERN=${2:-*-cyclonedx.json}
SEVERITIES=${3:-HIGH,CRITICAL}

function abort() {
  echo "$*"
  exit 1
}

pushd "${DIRECTORY}" || abort "Directory was not configured correctly"
echo "Scanning for SBOMs in Directory $(pwd)..."
echo "SBOM filename search pattern is ${SBOM_PATTERN}"
echo "Trivy Vulnerability severities are ${SEVERITIES}"
echo ""

if [ ! -f pom.xml ]; then
  echo "No Maven project found in current directory $(pwd)"
  ls -lh
  exit 1
fi

set -o pipefail

function result() {
  echo "$*"
  echo "$*" >> target/maven-trivy-summary.txt 
}

SUCCESS=0
FAILURES=0

function success() {
  SUCCESS=$(( ${SUCCESS} + 1))
  result "$*"
}

function failure() {
  local MODULE=$1
  local BOM=$2
  shift 2
  FAILURES=$(( ${FAILURES} + 1))

  local REPORT="${BOM%/*}/${MODULE}-trivy-report.json"
  trivy sbom --severity ${SEVERITIES} --format json --output "${REPORT}" "${BOM}" 2>&1 | grep \
            -v "Unsupported hash algorithm"
  result "Trivy violations report written to ${REPORT}"
  result "$*"
}

mkdir -p target/
rm -f target/maven-trivy-summary.txt >/dev/null 2>&1

for BOM in $(find . -path "*/target/*" -name "${SBOM_PATTERN}" ); do
  MODULE=${BOM##*/}
  MODULE=${MODULE%%-bom.json}

  echo "Scanning BOM for module ${MODULE}..."
  echo "trivy sbom --severity "${SEVERITIES}" --ignore-unfixed --exit-code 1 "$BOM""
  
  trivy sbom --severity "${SEVERITIES}" --ignore-unfixed \
        --exit-code 1 "$BOM" 2>&1 | grep \
            -v "Unsupported hash algorithm" \
            && success "No violations in ${MODULE}" \
            || failure "${MODULE}" "${BOM}" "Violations in BOM ${MODULE}"
  echo
done

if [ ${FAILURES} -ne 0 ]; then
  result "${FAILURES} module(s) had violations (${SUCCESS} module(s) had no violations)"
  echo "See ${PWD}/target/maven-trivy-summary.txt for summary"
  exit 1
elif [ ${SUCCESS} -eq 0 ]; then
  result "No SBOMs were detected, are you sure your build is generating SBOMs, or was your SBOM Filename Pattern (${SBOM_PATTERN}) configured incorrectly?"
  exit 1
else
  result "${SUCCESS} module(s) had no violations"
  exit 0
fi
