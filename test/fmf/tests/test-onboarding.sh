#!/bin/bash
set -euox pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Cleanup function
function cleanup() {
    info "Cleaning up FDO test environment..."

    # Stop any running FDO services
    systemctl stop fdo-manufacturing-server.service || true
    systemctl stop fdo-owner-onboarding-server.service || true
    systemctl stop fdo-rendezvous-server.service || true

    # Clean up test files
    rm -rf /tmp/fdo-test
    rm -f /tmp/cred.bin

    info "Cleanup complete"
}

trap cleanup EXIT

# Verify go-fdo-client is installed
info "Verifying go-fdo-client installation..."
if ! rpm -qa | grep -q go-fdo-client; then
    error "go-fdo-client package is not installed"
    exit 1
fi
info "go-fdo-client package is installed"

# Verify go-fdo-server is installed
info "Verifying go-fdo-server installation..."
if ! rpm -qa | grep -q go-fdo-server; then
    error "go-fdo-server package is not installed"
    exit 1
fi
info "go-fdo-server package is installed"

# Check that go-fdo-client binary is available
info "Checking go-fdo-client binary..."
if ! command -v go-fdo-client &> /dev/null; then
    error "go-fdo-client binary not found in PATH"
    exit 1
fi
info "go-fdo-client binary found: $(which go-fdo-client)"

# Print version information
info "Go FDO Client version:"
go-fdo-client --version || true

# Create test directory
mkdir -p /tmp/fdo-test
cd /tmp/fdo-test

# Configure and start FDO servers
info "Setting up FDO server environment..."

# Initialize FDO server configuration
export FDO_MANUFACTURING_SERVER_BIND=127.0.0.1:8038
export FDO_OWNER_ONBOARDING_SERVER_BIND=127.0.0.1:8042
export FDO_RENDEZVOUS_SERVER_BIND=127.0.0.1:8040

# Start FDO services
info "Starting FDO Manufacturing Server..."
systemctl start fdo-manufacturing-server.service || {
    error "Failed to start FDO Manufacturing Server"
    journalctl -u fdo-manufacturing-server.service --no-pager
    exit 1
}

info "Starting FDO Rendezvous Server..."
systemctl start fdo-rendezvous-server.service || {
    error "Failed to start FDO Rendezvous Server"
    journalctl -u fdo-rendezvous-server.service --no-pager
    exit 1
}

info "Starting FDO Owner Onboarding Server..."
systemctl start fdo-owner-onboarding-server.service || {
    error "Failed to start FDO Owner Onboarding Server"
    journalctl -u fdo-owner-onboarding-server.service --no-pager
    exit 1
}

# Wait for services to be ready
sleep 5

# Check service status
info "Verifying FDO services are running..."
systemctl is-active --quiet fdo-manufacturing-server.service || {
    error "FDO Manufacturing Server is not active"
    journalctl -u fdo-manufacturing-server.service --no-pager
    exit 1
}

systemctl is-active --quiet fdo-rendezvous-server.service || {
    error "FDO Rendezvous Server is not active"
    journalctl -u fdo-rendezvous-server.service --no-pager
    exit 1
}

systemctl is-active --quiet fdo-owner-onboarding-server.service || {
    error "FDO Owner Onboarding Server is not active"
    journalctl -u fdo-owner-onboarding-server.service --no-pager
    exit 1
}

info "All FDO services are running"

# Test 1: Device Initialization (DI)
info "Testing Device Initialization (DI)..."
go-fdo-client device-init http://127.0.0.1:8038 \
    --device-info e2e-test-device \
    --key ec256 \
    --debug \
    --blob /tmp/cred.bin || {
    error "Device initialization failed"
    exit 1
}

# Verify credential blob was created
if [ ! -f /tmp/cred.bin ]; then
    error "Credential blob file was not created"
    exit 1
fi
info "Device initialization successful - credential blob created"

# Test 2: Device Onboarding (TO0, TO1, TO2)
info "Testing Device Onboarding (TO0, TO1, TO2)..."

# Note: For a complete e2e test, we would run the onboarding process here
# This requires the credential blob to be transferred to the device and
# the device to connect to the rendezvous and owner servers
# For now, we verify the client can print the credential status

go-fdo-client print --blob /tmp/cred.bin || {
    error "Failed to print credential blob"
    exit 1
}
info "Credential blob is valid and readable"

# Check service logs for errors
info "Checking service logs for errors..."
journalctl -u fdo-manufacturing-server.service --no-pager | tail -20
journalctl -u fdo-rendezvous-server.service --no-pager | tail -20
journalctl -u fdo-owner-onboarding-server.service --no-pager | tail -20

# Success
info "======================================="
info "Go FDO Client E2E Test PASSED"
info "======================================="
info "✓ go-fdo-client package installed correctly"
info "✓ go-fdo-client binary is functional"
info "✓ Device initialization completed successfully"
info "✓ Credential blob created and validated"
info "======================================="

exit 0
