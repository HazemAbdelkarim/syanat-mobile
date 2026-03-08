#!/usr/bin/env python3
"""
Syanat App - Firebase Services Integration Validator
Checks if everything is ready for the upload and integration
"""

import json
import csv
import os
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'

def print_status(status, message):
    """Print status message with color"""
    if status == 'ok':
        print(f"{Colors.GREEN}✅{Colors.END} {message}")
    elif status == 'error':
        print(f"{Colors.RED}❌{Colors.END} {message}")
    elif status == 'warning':
        print(f"{Colors.YELLOW}⚠️{Colors.END} {message}")
    else:
        print(f"{Colors.BLUE}ℹ️{Colors.END} {message}")

def check_csv_file():
    """Check if CSV file exists and is valid"""
    csv_path = Path("Syanat_App_Developer_Workflow.csv")
    
    if not csv_path.exists():
        print_status('error', f"CSV file not found: {csv_path.absolute()}")
        return False
    
    try:
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            print_status('ok', f"CSV file found with {len(rows)} services")
            return True
    except Exception as e:
        print_status('error', f"CSV file error: {e}")
        return False

def check_firebase_credentials():
    """Check if Firebase credentials exist"""
    cred_path = Path("firebase-key.json")
    
    if cred_path.exists():
        try:
            with open(cred_path, 'r') as f:
                data = json.load(f)
                if 'project_id' in data:
                    print_status('ok', f"Firebase credentials found (Project: {data['project_id']})")
                    return True
                else:
                    print_status('error', "Firebase credentials invalid (missing project_id)")
                    return False
        except Exception as e:
            print_status('error', f"Firebase credentials format error: {e}")
            return False
    else:
        print_status('warning', "Firebase credentials not found (firebase-key.json)")
        print("       Run: python upload_services_to_firestore.py to start upload")
        return False

def check_python_packages():
    """Check if required Python packages are installed"""
    try:
        import firebase_admin
        print_status('ok', "firebase-admin package installed")
        return True
    except ImportError:
        print_status('error', "firebase-admin not installed")
        print("       Run: pip install firebase-admin")
        return False

def check_flutter_files():
    """Check if Flutter app files are in place"""
    flutter_dir = Path("flutter_projects/lib")
    
    required_files = [
        'models/service.dart',
        'repositories/service_repository.dart',
        'services_integration.dart',
        'service_details_screen.dart',
    ]
    
    all_ok = True
    for file in required_files:
        file_path = flutter_dir / file
        if file_path.exists():
            print_status('ok', f"Flutter file: {file}")
        else:
            print_status('error', f"Flutter file missing: {file}")
            all_ok = False
    
    return all_ok

def print_header():
    """Print header"""
    print(f"\n{Colors.BLUE}")
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║  SYANAT APP - FIREBASE INTEGRATION VALIDATOR                  ║")
    print("║  Check all components before uploading services               ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print(f"{Colors.END}\n")

def print_next_steps():
    """Print next steps"""
    print(f"\n{Colors.BLUE}{'='*70}{Colors.END}")
    print(f"{Colors.BLUE}NEXT STEPS{Colors.END}")
    print(f"{Colors.BLUE}{'='*70}{Colors.END}\n")
    
    print("1️⃣  If firebase-key.json is missing:")
    print("    a) Go to: https://console.firebase.google.com")
    print("    b) Select project: 'syana-ea75a'")
    print("    c) Settings → Service Accounts → Generate New Private Key")
    print("    d) Save as 'firebase-key.json' in current folder\n")
    
    print("2️⃣  Once credentials are ready:")
    print("    python upload_services_to_firestore.py \"Syanat_App_Developer_Workflow.csv\" \"firebase-key.json\"\n")
    
    print("3️⃣  After upload completes:")
    print("    flutter pub get")
    print("    flutter run\n")

def main():
    print_header()
    
    checks = {
        'Python packages': check_python_packages,
        'CSV file': check_csv_file,
        'Flutter files': check_flutter_files,
        'Firebase credentials': check_firebase_credentials,
    }
    
    results = {}
    for check_name, check_func in checks.items():
        print(f"\nChecking: {check_name}...")
        try:
            results[check_name] = check_func()
        except Exception as e:
            print_status('error', f"Check failed: {e}")
            results[check_name] = False
    
    # Summary
    print(f"\n{Colors.BLUE}{'='*70}{Colors.END}")
    print(f"{Colors.BLUE}SUMMARY{Colors.END}")
    print(f"{Colors.BLUE}{'='*70}{Colors.END}\n")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for check_name, result in results.items():
        status = 'ok' if result else 'error'
        print_status(status, f"{check_name}: {'PASS' if result else 'FAIL'}")
    
    print(f"\nTotal: {passed}/{total} checks passed")
    
    if passed == total:
        print_status('ok', "All checks passed! Ready to upload services.")
    elif passed >= total - 1:
        print_status('warning', "Almost ready. Missing Firebase credentials.")
    else:
        print_status('error', "Fix issues above before proceeding.")
    
    print_next_steps()
    print(f"\n{Colors.BLUE}{'='*70}{Colors.END}\n")

if __name__ == '__main__':
    main()
