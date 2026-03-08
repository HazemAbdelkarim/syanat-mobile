#!/usr/bin/env python3
"""
SERVICES UPLOAD HELPER
Validates CSV and uploads to Firestore with simple setup.
Follow the instructions below to get your Firebase credentials.
"""

import csv
import sys
import os
from pathlib import Path

def validate_csv(csv_path):
    """Parse and validate the CSV file."""
    print("=" * 70)
    print("VALIDATING CSV FILE")
    print("=" * 70)
    
    services = []
    errors = []
    
    try:
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            
            # Get headers and strip any remaining whitespace
            headers = {h.strip(): h for h in (reader.fieldnames or [])}
            
            for row_num, row in enumerate(reader, start=2):
                # Get values with flexible header matching
                def get_val(keys):
                    for key in keys:
                        if key in row:
                            return row[key].strip()
                        # Try without whitespace
                        for k in row.keys():
                            if k.strip() == key:
                                return row[k].strip()
                    return ''
                
                service = {
                    'category_en': get_val(['Main Icon (EN)']),
                    'category_ar': get_val(['الأيقونة الرئيسية (AR)']),
                    'subcategory_en': get_val(['Sub-Category Card (EN)']),
                    'subcategory_ar': get_val(['البطاقة الفرعية (AR)']),
                    'service_name_en': get_val(['Micro-Service (EN)']),
                    'service_name_ar': get_val(['الخدمة الدقيقة (AR)']),
                    'price_str': get_val(['Price (EGP)']),
                }
                
                # Validate
                if not all([service['category_en'], service['category_ar'],
                           service['subcategory_en'], service['subcategory_ar'],
                           service['service_name_en'], service['service_name_ar']]):
                    errors.append(f"Row {row_num}: Missing required fields")
                    continue
                
                # Parse price
                price = None
                if service['price_str']:
                    try:
                        price = float(service['price_str'])
                    except ValueError:
                        errors.append(f"Row {row_num}: Invalid price '{service['price_str']}'")
                        price = None
                
                service['price'] = price
                services.append(service)
        
        print(f"✅ CSV Validation Complete!")
        print(f"📊 Total Services: {len(services)}")
        print(f"⚠️  Errors: {len(errors)}")
        
        if errors:
            print("\nErrors found:")
            for error in errors:
                print(f"  - {error}")
        
        return services, errors
    
    except Exception as e:
        print(f"❌ Error reading CSV: {e}")
        return [], [str(e)]

def show_sample_data(services):
    """Show sample of what will be uploaded."""
    print("\n" + "=" * 70)
    print("SAMPLE DATA (First 3 Services)")
    print("=" * 70)
    
    for i, service in enumerate(services[:3], 1):
        print(f"\nService {i}:")
        print(f"  Category: {service['category_en']} / {service['category_ar']}")
        print(f"  Subcategory: {service['subcategory_en']} / {service['subcategory_ar']}")
        print(f"  Service: {service['service_name_en']} / {service['service_name_ar']}")
        print(f"  Price: {service['price'] if service['price'] else 'Not set'} EGP")

def show_setup_instructions():
    """Show Firebase setup instructions."""
    print("\n" + "=" * 70)
    print("FIREBASE SETUP INSTRUCTIONS")
    print("=" * 70)
    
    instructions = """
📋 Step 1: Get Firebase Service Account Credentials
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Go to: https://console.firebase.google.com
2. Select your project (syana-ea75a)
3. Click ⚙️ (Settings) → Service Accounts
4. Click "Generate New Private Key"
5. A JSON file will download
6. IMPORTANT: Keep this file PRIVATE! Never commit to git!

📁 Step 2: Place Credentials File
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Rename the downloaded file to: firebase-key.json
Place it in: c:\\Users\\lenovo\\flutter_projects\\

✅ Step 3: Run Upload Script
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
From terminal, run:
  cd c:\\Users\\lenovo\\flutter_projects
  python upload_services_to_firestore.py \\
    "Syanat_App_Developer_Workflow.csv" \\
    "firebase-key.json"

⏱️  This will upload 61 services to Firestore.

🔒 Step 4: Secure Your Credentials
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Add to .gitignore (IMPORTANT!):
  firebase-key.json

❌ NEVER commit credentials to GitHub!
    """
    
    print(instructions)

def create_example_credentials():
    """Create example credentials file."""
    example = {
        "type": "service_account",
        "project_id": "syana-ea75a",
        "private_key_id": "YOUR_PRIVATE_KEY_ID_HERE",
        "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n",
        "client_email": "firebase-adminsdk-xxxxx@syana-ea75a.iam.gserviceaccount.com",
        "client_id": "YOUR_CLIENT_ID_HERE",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "YOUR_CERT_URL_HERE"
    }
    
    example_path = Path(__file__).parent / "firebase-key.example.json"
    
    import json
    with open(example_path, 'w') as f:
        json.dump(example, f, indent=2)
    
    print(f"✅ Created example file: {example_path}")

def main():
    print("""
╔════════════════════════════════════════════════════════════════════╗
║          SYANAT APP - SERVICES FIRESTORE UPLOADER                 ║
║                      v1.0                                          ║
╚════════════════════════════════════════════════════════════════════╝
    """)
    
    csv_path = "Syanat_App_Developer_Workflow.csv"
    
    # Check if CSV exists
    if not Path(csv_path).exists():
        print(f"❌ CSV file not found: {csv_path}")
        print(f"📁 Please place the CSV file in: {Path.cwd() / csv_path}")
        sys.exit(1)
    
    # Validate CSV
    services, errors = validate_csv(csv_path)
    
    if not services:
        print("\n❌ No valid services found in CSV!")
        sys.exit(1)
    
    # Show sample
    show_sample_data(services)
    
    # Show setup instructions
    show_setup_instructions()
    
    # Check if firebase-key.json exists
    credentials_path = Path("firebase-key.json")
    
    if credentials_path.exists():
        print("\n" + "=" * 70)
        print("✅ CREDENTIALS FOUND!")
        print("=" * 70)
        print(f"Found: {credentials_path.absolute()}")
        print("\n🚀 Ready to upload! Run:")
        print("   python upload_services_to_firestore.py \"Syanat_App_Developer_Workflow.csv\" \"firebase-key.json\"")
    else:
        print("\n" + "=" * 70)
        print("⏳ WAITING FOR CREDENTIALS")
        print("=" * 70)
        print(f"Credentials file not found: {credentials_path.absolute()}")
        print("\n👉 Follow the Firebase Setup Instructions above!")
        print("\n✅ Once you have firebase-key.json, run:")
        print("   python upload_services_to_firestore.py \"Syanat_App_Developer_Workflow.csv\" \"firebase-key.json\"")

if __name__ == '__main__':
    main()
