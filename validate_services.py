#!/usr/bin/env python3
"""
Validate all service configurations
"""

import os
import yaml
from pathlib import Path

def validate_services():
    library_path = Path("library")
    results = {
        "valid": 0,
        "no_config": 0,
        "no_tests": 0,
        "invalid": 0,
        "details": []
    }
    
    # Walk through all service directories
    for distro_dir in library_path.iterdir():
        if not distro_dir.is_dir():
            continue
            
        for version_dir in distro_dir.iterdir():
            if not version_dir.is_dir():
                continue
                
            for service_dir in version_dir.iterdir():
                if not service_dir.is_dir():
                    continue
                    
                service_path = f"{distro_dir.name}/{version_dir.name}/{service_dir.name}"
                config_file = service_dir / "lxc-compose.yml"
                
                # Check if config exists
                if not config_file.exists():
                    results["no_config"] += 1
                    results["details"].append(f"❌ {service_path} - No config")
                    continue
                
                # Validate YAML
                try:
                    with open(config_file) as f:
                        yaml.safe_load(f)
                    
                    # Check for tests
                    tests_dir = service_dir / "tests"
                    has_tests = False
                    if tests_dir.exists():
                        test_files = list(tests_dir.glob("*.sh"))
                        has_tests = len(test_files) > 0
                    
                    if has_tests:
                        results["valid"] += 1
                        results["details"].append(f"✅ {service_path} - Valid with tests")
                    else:
                        results["no_tests"] += 1
                        results["details"].append(f"⚠️  {service_path} - Valid but no tests")
                        
                except Exception as e:
                    results["invalid"] += 1
                    results["details"].append(f"❌ {service_path} - Invalid: {e}")
    
    # Print results
    print("\n=== Service Validation Results ===\n")
    
    for detail in sorted(results["details"]):
        print(detail)
    
    print("\n=== Summary ===")
    total = results["valid"] + results["no_config"] + results["no_tests"] + results["invalid"]
    print(f"Total services: {total}")
    print(f"✅ Valid with tests: {results['valid']}")
    print(f"⚠️  Valid but no tests: {results['no_tests']}")
    print(f"❌ Invalid or missing: {results['invalid'] + results['no_config']}")
    
    # Save to file
    with open("validation_results.md", "w") as f:
        f.write("# Service Validation Results\n\n")
        f.write("## Service Status\n\n")
        for detail in sorted(results["details"]):
            f.write(f"- {detail}\n")
        f.write(f"\n## Summary\n\n")
        f.write(f"- Total services: {total}\n")
        f.write(f"- Valid with tests: {results['valid']}\n")
        f.write(f"- Valid but no tests: {results['no_tests']}\n")
        f.write(f"- Invalid or missing: {results['invalid'] + results['no_config']}\n")

if __name__ == "__main__":
    validate_services()