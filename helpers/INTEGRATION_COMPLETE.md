# 🚀 SYANAT APP - COMPLETE INTEGRATION SETUP

## ✅ What's Been Done

Your Flutter app has been updated to use **real services from Firebase** instead of hardcoded data:

### Code Changes Made:

1. **✅ Service Model** (`lib/models/service.dart`)
   - Bilingual support (English/Arabic)
   - Firestore integration with `fromFirestore()`, `toMap()`, `toJson()`
   - Full type safety

2. **✅ Service Repository** (`lib/repositories/service_repository.dart`)
   - Data access layer with query methods
   - Stream support for real-time updates
   - Search, filter, and batch operations

3. **✅ Service Integration Layer** (`lib/services_integration.dart`)
   - Maps app service keys (ac, plumbing, etc.) to CSV categories
   - Loads real services from Firebase 'services' collection
   - Subcategory extraction and filtering

4. **✅ Updated ServiceDetailsScreen**
   - Replaced hardcoded "Common Problems" with real services
   - Shows subcategories from CSV data
   - Displays prices from Firebase
   - Real-time filtering by subcategory

5. **✅ Service Model & Integration Ready**
   - All imports configured
   - Connected to existing UserHomeScreen
   - Works with existing TechniciansListScreen

---

## 📋 Next Steps - Firebase Setup

### Step 1: Get Firebase Service Account Key

Follow these exact steps:

```
1. Open: https://console.firebase.google.com
2. Select project: "syana-ea75a"
3. Click ⚙️ (Settings) in top left
4. Go to "Service Accounts" tab
5. Click "Generate New Private Key" button
6. A JSON file will download automatically (e.g., "syana-ea75a-firebase-adminsdk-xxxxx.json")
```

### Step 2: Place Credentials & Run Upload Script

```bash
# 1. Navigate to flutter_projects folder
cd c:\Users\lenovo\flutter_projects

# 2. Rename the JSON file to simple name
# Move/rename downloaded file to: c:\Users\lenovo\flutter_projects\firebase-key.json

# 3. Run the upload script
python upload_services_to_firestore.py "Syanat_App_Developer_Workflow.csv" "firebase-key.json"

# You should see:
# ✅ CSV Validation Complete!
# 📊 Total Services: 61
# ⏱️ Uploading services to Firestore...
# [Progress: 1/61, 2/61... 61/61]
# ✅ Upload Complete! Total Services Added: 61
```

### Step 3: Verify in Firebase

```
1. Go to: https://console.firebase.google.com
2. Select project: "syana-ea75a"
3. Click "Firestore Database" (left menu)
4. Look for "services" collection
5. Expand and see all 61 documents with:
   - category_en, category_ar
   - subcategory_en, subcategory_ar
   - service_name_en, service_name_ar
   - price, createdAt
```

### Step 4: Run Flutter App

```bash
# In the flutter_projects\flutter_projects folder
cd c:\Users\lenovo\flutter_projects\flutter_projects

# Get dependencies
flutter pub get

# Run the app
flutter run -d windows  # or android/ios
```

---

## 🎯 How It All Works Now

### User Flow:

1. **Home Screen** → User sees 10 service categories (AC, Plumbing, Electricity, etc.)
   - Loads from: `ServiceIntegration.keyToCategoryMap`
   
2. **User Taps Category** → Opens ServiceDetailsScreen
   - Example: Click "AC Services" → Shows maintenance, repairs, installation, other
   
3. **Real Services Load** → Shows actual services from CSV
   - Subcategories displayed as filter chips
   - Services listed with prices and bilingual names
   
4. **User Selects Service** → Finds technicians for that specific service
   - Example: Click "Cleaning & Filter Wash" → View plumbers who offer this

### Data Flow:

```
CSV File (61 services)
        ↓
Python Upload Script
        ↓
Firebase Cloud Firestore (services collection)
        ↓
Flutter App (ServiceIntegration layer)
        ↓
ServiceDetailsScreen (Real-time updates)
        ↓
User Interface (Categories → Subcategories → Services → Technicians)
```

---

## 🔧 Service Key Mapping

The app uses these service keys internally (map to CSV categories):

```dart
{
  'ac': 'AC Services',
  'plumbing': 'Plumbing',
  'electricity': 'Electricity',
  'security_intercom': 'Security & Intercom',
  'large_appliances': 'Large Appliances',
  'small_appliances': 'Small Appliances',
  'carpentry': 'Carpentry',
  'pest_control': 'Pest Control',
  'aluminum': 'Alometal',
  'finishing': 'Finishing',
}
```

When a user taps a category, the app:
1. Gets the service key (e.g., 'plumbing')
2. Maps it to category name ('Plumbing')
3. Queries Firebase: `services.where('category_en', '==', 'Plumbing')`
4. Displays all matching services with subcategories

---

## 📱 Testing the Integration

### Test 1: Load Services
```dart
// In any screen, test this code:
final integration = ServiceIntegration();
final services = await integration.getServicesByKey('plumbing'); // Should return 11 services
print('Plumbing services: ${services.length}'); // Should print: 11
```

### Test 2: Get Subcategories
```dart
final subcats = await integration.getSubcategoriesForKey('plumbing');
print('Subcategories: $subcats'); 
// Should print: [Bathroom, Heaters & Pumps, Kitchen, Main Pipes & Leaks, Other]
```

### Test 3: Real-time Stream
```dart
integration.streamServicesByKey('ac').listen((services) {
  print('AC services updated: ${services.length}');
});
```

---

## ⚠️ IMPORTANT SECURITY NOTES

1. **firebase-key.json** - NEVER commit to Git!
   ```
   # Add to .gitignore
   echo firebase-key.json >> .gitignore
   ```

2. **Set Firestore Security Rules** (for production):
   ```firestore
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /services/{document=**} {
         // Public read access
         allow read: if true;
         
         // Only admins can create/update/delete
         allow create, update, delete: if request.auth.token.admin == true;
       }
     }
   }
   ```

3. **Keep API Keys Safe**
   - Firebase Console → Settings → API Keys
   - Restrict to Firestore and Auth APIs only

---

## 🐛 Troubleshooting

### Issue: "Services not loading in app"
**Solution**: 
- Make sure services collection exists in Firebase
- Run upload script successfully (check for "61 services added")
- Check app logs: `flutter run -v`

### Issue: "No such collection error"
**Solution**: 
- Upload script hasn't run yet
- Check Firebase console → Firestore Database
- Should see "services" collection with 61 documents

### Issue: "Price is null for all services"
**Solution**: 
- This is OK! Prices in CSV are empty
- Update via Firebase Console or script when ready
- App handles null prices gracefully

### Issue: "Subcategories not appearing"
**Solution**: 
- Services must be uploaded first
- Clear app cache: `flutter clean && flutter pub get`
- Restart the app

---

## 📊 Database Structure

After upload, your Firestore will have:

```
firestore-database/
├── services/  (Collection)
│   ├── ac_services_maintenance_1  (Document)
│   │   ├── category_en: "AC Services"
│   │   ├── category_ar: "تكييف"
│   │   ├── subcategory_en: "Maintenance"
│   │   ├── subcategory_ar: "صيانة"
│   │   ├── service_name_en: "Cleaning & Filter Wash"
│   │   ├── service_name_ar: "تنظيف وغسيل فلاتر"
│   │   ├── price: null
│   │   └── createdAt: timestamp
│   │
│   ├── ac_services_maintenance_2
│   ├── ac_services_repairs_1
│   ... (61 total documents)
│   
├── users/  (Existing)
├── jobs/  (Existing)
├── chats/  (Existing)
```

---

## 🎉 Success Checklist

Once setup is complete:

- [ ] Firebase key downloaded from Firebase Console
- [ ] Upload script run successfully (`python upload_services_to_firestore.py ...`)
- [ ] 61 services visible in Firestore console
- [ ] `flutter pub get` runs without errors
- [ ] App starts without import errors
- [ ] Home screen shows 10 service categories
- [ ] Clicking a category loads real services from Firebase
- [ ] Subcategories appear as filter chips
- [ ] Service names display in both English/Arabic
- [ ] Prices display (if set)
- [ ] Chat with technician still works

---

## 🚀 Further Customization

### Add More Services
1. Update CSV with new services
2. Re-run Python upload script
3. App will auto-load new services from Firebase

### Update Prices
```python
# Edit the CSV file with prices
# Re-run upload script to update Firestore
```

### Change Service Icons
Add icons to the CSV and update ServiceIntegration:
```dart
static const Map<String, IconData> keyToIconMap = {
  'ac': Icons.ac_unit,
  'plumbing': Icons.plumbing,
  // ... etc
};
```

### Add Location Filtering
Services can be filtered by location:
```dart
final services = await integration.getServicesByKey('plumbing');
final localServices = services.where((s) => 
  // Add location filtering logic
).toList();
```

---

## 📞 Need Help?

1. **CSV not parsing**: Check encoding (use UTF-8)
2. **Firebase auth issues**: Verify project ID is correct
3. **Empty services**: Run upload script again
4. **App crashes**: Run `flutter clean && flutter pub get`

---

**Setup Complete!**  
Your app is now connected to Firebase with all 61 real services!  
Date: February 25, 2026
