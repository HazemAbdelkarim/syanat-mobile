#!/usr/bin/env python3
"""
Firebase Firestore Services Uploader
Uploads services from CSV to Firestore 'services' collection
"""

import csv
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
from datetime import datetime
import argparse

def upload_services_to_firestore(csv_file_path, credentials_path, project_id=None):
    """
    Parse CSV file and upload all services to Firestore.
    
    Args:
        csv_file_path: Path to the CSV file
        credentials_path: Path to Firebase service account credentials JSON
        project_id: Firebase project ID (optional if in credentials)
    """
    
    # Initialize Firebase
    try:
        cred = credentials.Certificate(credentials_path)
        if project_id:
            firebase_admin.initialize_app(cred, {'projectId': project_id})
        else:
            firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Error initializing Firebase: {e}")
        return False
    
    db = firestore.client()
    
    services_added = 0
    errors = []
    
    try:
        with open(csv_file_path, 'r', encoding='utf-8-sig') as csvfile:
            reader = csv.DictReader(csvfile)
            
            # Normalize field names (remove BOM if present)
            if reader.fieldnames:
                reader.fieldnames = [name.replace('\ufeff', '') if name else name 
                                     for name in reader.fieldnames]
            
            # Validate headers
            expected_headers = [
                'Main Icon (EN)',
                'الأيقونة الرئيسية (AR)',
                'Sub-Category Card (EN)',
                'البطاقة الفرعية (AR)',
                'Micro-Service (EN)',
                'الخدمة الدقيقة (AR)',
                'Price (EGP)'
            ]
            
            if reader.fieldnames != expected_headers:
                print("Warning: CSV headers may not match expected format")
                print(f"Expected: {expected_headers}")
                print(f"Found: {reader.fieldnames}")
            
            # Process each row
            for row_num, row in enumerate(reader, start=2):  # start=2 because row 1 is header
                try:
                    # Extract data from CSV
                    category_en = row.get('Main Icon (EN)', '').strip()
                    category_ar = row.get('الأيقونة الرئيسية (AR)', '').strip()
                    subcategory_en = row.get('Sub-Category Card (EN)', '').strip()
                    subcategory_ar = row.get('البطاقة الفرعية (AR)', '').strip()
                    service_name_en = row.get('Micro-Service (EN)', '').strip()
                    service_name_ar = row.get('الخدمة الدقيقة (AR)', '').strip()
                    price_str = row.get('Price (EGP)', '').strip()
                    
                    # Validate required fields
                    if not all([category_en, category_ar, subcategory_en, 
                               subcategory_ar, service_name_en, service_name_ar]):
                        errors.append(f"Row {row_num}: Missing required fields")
                        continue
                    
                    # Parse price (can be None/empty)
                    price = None
                    if price_str:
                        try:
                            price = float(price_str)
                        except ValueError:
                            errors.append(f"Row {row_num}: Invalid price value '{price_str}'")
                            price = None
                    
                    # Create service document
                    service_doc = {
                        'category_en': category_en,
                        'category_ar': category_ar,
                        'subcategory_en': subcategory_en,
                        'subcategory_ar': subcategory_ar,
                        'service_name_en': service_name_en,
                        'service_name_ar': service_name_ar,
                        'price': price,
                        'createdAt': datetime.now()
                    }
                    
                    # Generate document ID (slug format)
                    doc_id = f"{category_en.lower().replace(' ', '_')}_{subcategory_en.lower().replace(' ', '_')}_{services_added + 1}"
                    
                    # Add to Firestore
                    db.collection('services').document(doc_id).set(service_doc)
                    
                    services_added += 1
                    print(f"✓ Added: {service_name_en} ({service_name_ar})")
                    
                except Exception as e:
                    errors.append(f"Row {row_num}: {str(e)}")
        
        # Print summary
        print(f"\n{'='*60}")
        print(f"Upload Complete!")
        print(f"{'='*60}")
        print(f"Total Services Added: {services_added}")
        
        if errors:
            print(f"\nErrors encountered ({len(errors)}):")
            for error in errors:
                print(f"  - {error}")
        
        return True
    
    except FileNotFoundError:
        print(f"Error: CSV file not found at {csv_file_path}")
        return False
    except Exception as e:
        print(f"Error uploading services: {e}")
        return False
    finally:
        # Cleanup
        if firebase_admin._apps:
            firebase_admin.delete_app(firebase_admin.get_app())

def main():
    parser = argparse.ArgumentParser(
        description='Upload services from CSV to Firestore'
    )
    parser.add_argument(
        'csv_file',
        help='Path to the CSV file'
    )
    parser.add_argument(
        'credentials',
        help='Path to Firebase service account credentials JSON file'
    )
    parser.add_argument(
        '--project-id',
        help='Firebase project ID (optional)',
        default=None
    )
    
    args = parser.parse_args()
    
    success = upload_services_to_firestore(
        args.csv_file,
        args.credentials,
        args.project_id
    )
    
    exit(0 if success else 1)

if __name__ == '__main__':
    main()
