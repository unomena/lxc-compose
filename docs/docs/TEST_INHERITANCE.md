# Test Inheritance Documentation

## Overview

When using the `includes:` field to pull in library services, all tests defined in those library services are automatically inherited by your container. This ensures that included services are properly tested without needing to duplicate test definitions.

## How Test Inheritance Works

### 1. Library Service Tests
Each library service can define its own tests:

```yaml
# library/alpine/3.19/postgresql/lxc-compose.yml
containers:
  postgresql-alpine-3-19:
    template: alpine-3.19
    packages:
      - postgresql
    tests:
      external:
        - crud:/tests/test.sh  # CRUD test for PostgreSQL
```

### 2. Including Library Services
When you include a library service, its tests are inherited:

```yaml
# myapp/lxc-compose.yml
containers:
  database:
    template: alpine-3.19
    includes:
      - postgresql  # Inherits PostgreSQL's tests
    environment:
      POSTGRES_PASSWORD: secret
```

### 3. Test Resolution
The system automatically resolves test paths:
- **Library tests**: Resolved relative to the library service location
- **Local tests**: Resolved relative to your config file location

## Test Path Metadata

When tests are inherited from library services, they include metadata about their source:

```
Test entry format: name:path@library:/path/to/library/service
```

This metadata ensures the test runner can find the test script in the correct location.

## Running Inherited Tests

### List All Tests
```bash
lxc-compose test <container> list
```

Output shows which tests are from libraries:
```
Container: database
  External tests:
    • crud: /tests/test.sh (from library)
```

### Run All Tests
```bash
lxc-compose test <container>
```

This runs both inherited library tests and any local tests you've defined.

### Run Specific Test Types
```bash
lxc-compose test <container> external  # Run external tests only
lxc-compose test <container> internal  # Run internal tests only
```

## Combining Library and Local Tests

You can add local tests in addition to inherited library tests:

```yaml
containers:
  webapp:
    template: ubuntu-24.04
    includes:
      - nginx       # Inherits nginx tests
      - redis       # Inherits redis tests
    tests:
      external:
        - custom:/tests/my_custom_test.sh  # Local test
```

## Test Execution Order

1. **Template tests** (if any)
2. **Library service tests** (from includes)
3. **Local tests** (defined in your config)

## Best Practices

### 1. Don't Duplicate Library Tests
If you're including a library service, rely on its tests rather than recreating them.

### 2. Add Application-Specific Tests
Library tests verify the service works. Add your own tests for application-specific functionality:

```yaml
containers:
  api:
    template: ubuntu-24.04
    includes:
      - postgresql  # Basic PostgreSQL tests inherited
    tests:
      external:
        - api_schema:/tests/validate_schema.sh  # Your schema test
        - api_data:/tests/check_seed_data.sh    # Your data test
```

### 3. Override When Necessary
If you need different test behavior, define a local test with the same name to override:

```yaml
containers:
  custom_db:
    template: alpine-3.19
    includes:
      - postgresql
    tests:
      external:
        - crud:/tests/custom_crud.sh  # Overrides library's crud test
```

## Troubleshooting

### Test Not Found
If a test from a library service isn't found:
1. Check the library service exists: `ls library/<os>/<version>/<service>`
2. Verify the test file exists in the library
3. Check file permissions on the test script

### Path Resolution Issues
The system shows the resolved path when tests fail:
```
⚠ Test script not found: /srv/lxc-compose/library/alpine/3.19/postgresql/tests/test.sh
  Library path: /srv/lxc-compose/library/alpine/3.19/postgresql
```

### Debugging Test Inheritance
Use the test script to verify inheritance:
```bash
python3 test_path_resolution.py
```

This shows exactly which tests are inherited and their resolved paths.

## Example: Complete Application Stack

```yaml
version: '1.0'

containers:
  frontend:
    template: ubuntu-24.04
    includes:
      - nginx         # Inherits nginx tests
    tests:
      external:
        - ui:/tests/test_ui.sh  # Custom UI test

  backend:
    template: ubuntu-24.04
    packages:
      - python3
      - python3-pip
    tests:
      internal:
        - api:/app/test_api.sh  # API test
      external:
        - health:/tests/health_check.sh

  database:
    template: alpine-3.19
    includes:
      - postgresql    # Inherits PostgreSQL tests
    environment:
      POSTGRES_PASSWORD: secure123
    tests:
      external:
        - migrations:/tests/test_migrations.sh  # Custom migration test

  cache:
    template: alpine-3.19
    includes:
      - redis        # Inherits Redis tests only
```

In this example:
- `frontend` inherits nginx tests and adds a UI test
- `backend` has only custom tests (no includes)
- `database` inherits PostgreSQL tests and adds a migration test
- `cache` only uses inherited Redis tests

## Summary

Test inheritance makes it easy to:
- **Reuse proven tests** from library services
- **Maintain consistency** across deployments
- **Focus on application-specific testing** rather than service basics
- **Combine library and custom tests** seamlessly

The path resolution system ensures tests always run from the correct location, whether they're defined locally or inherited from library services.