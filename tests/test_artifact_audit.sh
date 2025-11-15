#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# shellcheck source=/dev/null
source "$ROOT_DIR/artifact_audit.sh"

pass_count=0
fail_count=0

declare -a TESTS=(
    test_latest_release_artifact_detected
    test_latest_release_artifact_not_detected
    test_calculate_total_storage_output
)

function assert_true() {
    local condition="$1"
    local message="$2"
    if $condition; then
        ((pass_count++))
        return 0
    else
        ((fail_count++))
        echo "[FAIL] $message"
        return 1
    fi
}

function assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        ((pass_count++))
        return 0
    else
        ((fail_count++))
        echo "[FAIL] $message (expected '$expected' got '$actual')"
        return 1
    fi
}

function test_latest_release_artifact_detected() {
    init_state
    latest_releases["acme/galp"]="v1.2.3"
    if is_latest_release_artifact "acme/galp" "build-v1.2.3"; then
        assert_true true "artifact should match latest release"
    else
        assert_true false "artifact should match latest release"
    fi
}

function test_latest_release_artifact_not_detected() {
    init_state
    latest_releases["acme/galp"]="v1.2.3"
    if is_latest_release_artifact "acme/galp" "build-v1.2.2"; then
        assert_true false "artifact should not match latest release"
    else
        assert_true true "artifact should not match latest release"
    fi
}

function test_calculate_total_storage_output() {
    init_state
    all_artifacts=(
        "acme/galp|1|artifact-one|1.00|2023-01-01||1048576"
        "acme/galp|2|artifact-two|2.00|2023-01-02||2097152"
    )
    local output
    output=$(calculate_total_storage)
    assert_equals "🧮 Total Storage Used: 3.00 MB" "$output" "calculate_total_storage should report combined bytes"
}

function run_tests() {
    for test in "${TESTS[@]}"; do
        if ! $test; then
            ((fail_count++))
            echo "[FAIL] $test exited with non-zero status"
        fi
    done

    echo "Passed: $pass_count"
    echo "Failed: $fail_count"

    if [[ $fail_count -gt 0 ]]; then
        exit 1
    fi
}

run_tests
