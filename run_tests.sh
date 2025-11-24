#!/bin/bash

# Medical Imaging Suite - Test Runner Script
# This script runs all tests and generates coverage reports

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCHEME="MedicalImagingSuite"
DESTINATION="platform=visionOS Simulator,name=Apple Vision Pro"
RESULT_BUNDLE="TestResults.xcresult"

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Clean previous results
clean_results() {
    print_header "Cleaning Previous Results"
    rm -rf "$RESULT_BUNDLE"
    rm -rf DerivedData/
    print_success "Cleaned previous test results"
}

# Run unit tests
run_unit_tests() {
    print_header "Running Unit Tests"

    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:MedicalImagingSuiteTests \
        -enableCodeCoverage YES \
        -resultBundlePath "$RESULT_BUNDLE" \
        -quiet

    if [ $? -eq 0 ]; then
        print_success "Unit tests passed"
        return 0
    else
        print_error "Unit tests failed"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    print_header "Running Integration Tests"

    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:MedicalImagingSuiteTests/Integration \
        -enableCodeCoverage YES \
        -resultBundlePath "$RESULT_BUNDLE" \
        -quiet

    if [ $? -eq 0 ]; then
        print_success "Integration tests passed"
        return 0
    else
        print_error "Integration tests failed"
        return 1
    fi
}

# Run performance tests
run_performance_tests() {
    print_header "Running Performance Tests"

    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:MedicalImagingSuiteTests/DICOMPixelDataTests/testPixelDataExtractionPerformance \
        -only-testing:MedicalImagingSuiteTests/VolumeReconstructorTests/testVolumeReconstructionPerformance \
        -quiet

    if [ $? -eq 0 ]; then
        print_success "Performance tests passed"
        return 0
    else
        print_warning "Performance tests completed with warnings"
        return 0
    fi
}

# Generate coverage report
generate_coverage() {
    print_header "Generating Coverage Report"

    if [ ! -d "$RESULT_BUNDLE" ]; then
        print_error "No test results found. Run tests first."
        return 1
    fi

    # Generate text report
    xcrun xccov view --report "$RESULT_BUNDLE" > coverage_report.txt

    # Generate JSON report
    xcrun xccov view --report --json "$RESULT_BUNDLE" > coverage.json

    # Extract coverage percentage
    COVERAGE=$(xcrun xccov view --report "$RESULT_BUNDLE" | grep "MedicalImagingSuite.app" | awk '{print $4}')

    print_success "Coverage report generated"
    print_info "Coverage: $COVERAGE"

    # Check coverage threshold
    COVERAGE_NUM=$(echo $COVERAGE | sed 's/%//')
    if (( $(echo "$COVERAGE_NUM >= 80.0" | bc -l) )); then
        print_success "Coverage meets threshold (≥80%)"
    else
        print_warning "Coverage below threshold (<80%)"
    fi
}

# Run all tests
run_all_tests() {
    print_header "Medical Imaging Suite - Test Suite"

    local failed=0

    # Clean
    clean_results

    # Run unit tests
    if ! run_unit_tests; then
        failed=1
    fi

    # Run integration tests
    if ! run_integration_tests; then
        failed=1
    fi

    # Run performance tests
    run_performance_tests

    # Generate coverage
    generate_coverage

    # Summary
    print_header "Test Summary"

    if [ $failed -eq 0 ]; then
        print_success "All tests passed! 🎉"
        return 0
    else
        print_error "Some tests failed"
        return 1
    fi
}

# Show help
show_help() {
    echo "Medical Imaging Suite - Test Runner"
    echo ""
    echo "Usage: ./run_tests.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  all         Run all tests (default)"
    echo "  unit        Run unit tests only"
    echo "  integration Run integration tests only"
    echo "  performance Run performance tests only"
    echo "  coverage    Generate coverage report"
    echo "  clean       Clean previous results"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./run_tests.sh              # Run all tests"
    echo "  ./run_tests.sh unit         # Run unit tests only"
    echo "  ./run_tests.sh coverage     # Generate coverage"
}

# Main
main() {
    case "${1:-all}" in
        all)
            run_all_tests
            ;;
        unit)
            clean_results
            run_unit_tests
            ;;
        integration)
            clean_results
            run_integration_tests
            ;;
        performance)
            clean_results
            run_performance_tests
            ;;
        coverage)
            generate_coverage
            ;;
        clean)
            clean_results
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
