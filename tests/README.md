# LXC Compose Test Suite

This directory contains comprehensive test configurations for all core services across all supported base templates.

## Directory Structure

```
tests/
├── alpine/3.19/
│   ├── haproxy/
│   ├── nginx/
│   ├── postgresql/
│   ├── python3/
│   ├── redis/
│   ├── supervisor/
│   └── all-services/
├── debian/
│   ├── 11/
│   │   └── [same services]
│   └── 12/
│       └── [same services]
├── ubuntu-minimal/
│   ├── 22.04/
│   │   └── [same services]
│   └── 24.04/
│       └── [same services]
└── ubuntu/
    ├── 22.04/
    │   └── [same services]
    └── 24.04/
        └── [same services]
```

## Core Services Tested

- **haproxy**: Load balancer and proxy server
- **nginx**: Web server and reverse proxy
- **postgresql**: PostgreSQL database server
- **python3**: Python 3 runtime environment
- **redis**: In-memory data store
- **supervisor**: Process control system
- **all-services**: Combined test with all services in one container

## Test Scripts

### 1. Sequential Bulk Test Script
```bash
sudo ./run_bulk_tests.sh [--individual|--combined|--all]
```

Options:
- `--individual`: Test each service separately
- `--combined`: Test all services combined in one container
- `--all` (default): Run both individual and combined tests

Features:
- Sequential execution for reliability
- Detailed logging for each test
- Comprehensive summary report
- Failed test tracking

### 2. Parallel Test Script
```bash
sudo ./run_parallel_tests.sh [max_parallel_tests]
```

Options:
- `max_parallel_tests`: Number of simultaneous tests (default: 3)

Features:
- Parallel execution for speed
- Progress indicators
- Real-time pass/fail reporting
- Summary report generation

### 3. Generate Test Files
```bash
./generate_test_files.sh
```

Regenerates all test configuration files based on the current library structure.

## Running Tests

### Quick Test of Single Service
```bash
# Test PostgreSQL on Alpine 3.19
sudo lxc-compose up -f alpine/3.19/postgresql/lxc-compose.yml
sudo lxc-compose test postgresql-alpine-test
sudo lxc-compose down -f alpine/3.19/postgresql/lxc-compose.yml
```

### Test All Services for One Distribution
```bash
# Test all Alpine 3.19 services
for service in haproxy nginx postgresql python3 redis supervisor all-services; do
    sudo lxc-compose up -f alpine/3.19/$service/lxc-compose.yml
    # ... test and cleanup
done
```

### Full Test Suite (Sequential)
```bash
# Run all tests sequentially (most reliable)
sudo ./run_bulk_tests.sh --all
```

### Full Test Suite (Parallel)
```bash
# Run tests in parallel (faster, may have resource contention)
sudo ./run_parallel_tests.sh 5
```

## Test Results

Test results are saved in timestamped directories:
- `/srv/lxc-compose/test-results-YYYYMMDD-HHMMSS/` (sequential)
- `/srv/lxc-compose/parallel-test-results-YYYYMMDD-HHMMSS/` (parallel)

Each results directory contains:
- Individual log files for each test
- `summary.txt`: Overview of all test results
- `failed.txt`: List of failed tests (sequential only)

## Container Naming Convention

Test containers follow this pattern:
- Individual services: `{service}-{os}{version}-test`
  - Example: `nginx-alpine-test`, `postgresql-debian11-test`
- Combined services: `all-services-{os}{version}-test`
  - Example: `all-services-ubuntu2204-test`

## Test Coverage

| Base Template | Version | Services | Combined | Total Tests |
|--------------|---------|----------|----------|-------------|
| Alpine | 3.19 | 6 | 1 | 7 |
| Debian | 11 | 6 | 1 | 7 |
| Debian | 12 | 6 | 1 | 7 |
| Ubuntu Minimal | 22.04 | 6 | 1 | 7 |
| Ubuntu Minimal | 24.04 | 6 | 1 | 7 |
| Ubuntu | 22.04 | 6 | 1 | 7 |
| Ubuntu | 24.04 | 6 | 1 | 7 |
| **Total** | | **42** | **7** | **49** |

## Troubleshooting

### Test Failures
1. Check the log file in the results directory
2. Look for deployment issues vs test failures
3. Verify the library service exists and is properly configured

### Resource Issues
- Reduce parallel test count if system is overloaded
- Ensure sufficient disk space for containers
- Check available memory with `free -h`

### Cleanup
If tests fail to cleanup properly:
```bash
# List all test containers
lxc list | grep test

# Destroy specific test container
sudo lxc-compose destroy -f <test-config-file>

# Force cleanup all test containers
for container in $(lxc list -c n --format csv | grep test); do
    lxc stop --force "$container"
    lxc delete "$container"
done
```

## Adding New Services

To add tests for a new service:

1. Ensure the service exists in `library/services/`
2. Add the service name to the service lists in test scripts
3. Run `./generate_test_files.sh` to create test configs
4. Test individually first, then in combination

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run LXC Compose Tests
  run: |
    sudo apt-get update
    sudo apt-get install -y lxc lxd
    sudo ./install.sh
    sudo ./tests/run_bulk_tests.sh --all
```

## Performance Considerations

- Sequential tests: ~2-3 minutes per service
- Parallel tests: Total time depends on parallelism level
- Combined service tests: ~5 minutes per distribution
- Full suite sequential: ~3-4 hours
- Full suite parallel (5 jobs): ~45-60 minutes