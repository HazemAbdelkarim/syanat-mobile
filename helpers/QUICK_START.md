# Quick Start Guide: Services Upload & Integration

## 📋 What's Included

This package includes everything needed to upload your services CSV to Firebase Firestore and integrate it into your Flutter app:

1. **firestore_schema.md** - Firestore collection structure design
2. **upload_services_to_firestore.py** - Python script to bulk upload services
3. **requirements.txt** - Python dependencies
4. **lib/models/service.dart** - Dart Service model class
5. **SERVICES_INTEGRATION_GUIDE.md** - Complete integration guide with examples
6. **SERVICES_DATA_SUMMARY.md** - Detailed breakdown of all 61 services

---

## 🚀 Quick Start (5 Steps)

### Step 1: Set Up Python Environment

```bash
# Install dependencies
pip install -r requirements.txt
```

### Step 2: Get Firebase Credentials

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Settings → Service Accounts → Generate New Private Key
4. Save the file as `firebase-key.json` in your project root

### Step 3: Run Upload Script

```bash
python upload_services_to_firestore.py "Syanat_App_Developer_Workflow.csv" "firebase-key.json"
```

**Expected Output:**
```
✓ Added: Cleaning & Filter Wash (تنظيف وغسيل فلاتر)
✓ Added: Deep Chemical Wash (غسيل كيميائي عميق)
...
============================================================
Upload Complete!
============================================================
Total Services Added: 61
```

### Step 4: Add Service Model to Flutter

The `lib/models/service.dart` file is already created. Ensure your `pubspec.yaml` includes:

```yaml
dependencies:
  cloud_firestore: ^4.13.0  # or latest
```

Run: `flutter pub get`

### Step 5: Start Using Services in Your App

**Example: Fetch and display services**

```dart
import 'models/service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> loadServices() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('services')
      .where('category_en', isEqualTo: 'AC Services')
      .get();
  
  final services = snapshot.docs
      .map((doc) => Service.fromFirestore(doc))
      .toList();
  
  for (final service in services) {
    print(service.serviceNameEn); // Cleaning & Filter Wash
  }
}
```

---

## 📊 Data Summary

- **Total Services:** 61
- **Total Categories:** 10
- **Languages:** English + Arabic (Bilingual)
- **Fields:** Category, Subcategory, Service Name, Price (optional)

**Categories:**
- AC Services (8)
- Plumbing (11)
- Electricity (8)
- Security & Intercom (5)
- Large Appliances (7)
- Small Appliances (6)
- Carpentry (5)
- Pest Control (4)
- Alometal (4)
- Finishing (5)

---

## 🔧 Common Tasks

### Fetch All Services
```dart
final services = await FirebaseFirestore.instance
    .collection('services')
    .get()
    .then((snapshot) => 
      snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
```

### Fetch Services by Category
```dart
final services = await FirebaseFirestore.instance
    .collection('services')
    .where('category_en', isEqualTo: 'AC Services')
    .get()
    .then((snapshot) => 
      snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
```

### Real-time Updates (StreamBuilder)
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('services')
      .where('category_en', isEqualTo: 'AC Services')
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return Text('Loading...');
    
    final services = snapshot.data!.docs
        .map((doc) => Service.fromFirestore(doc))
        .toList();
    
    return ListView(
      children: services.map((service) => 
        ListTile(title: Text(service.serviceNameEn))
      ).toList(),
    );
  },
)
```

---

## ✅ Verification Checklist

After following the quick start:

- [ ] Python dependencies installed
- [ ] Firebase credentials JSON downloaded
- [ ] Upload script executed successfully (61 services)
- [ ] Services visible in Firebase Console
- [ ] Service model added to Flutter project
- [ ] cloud_firestore dependency added to pubspec.yaml
- [ ] Can fetch services in Flutter app
- [ ] Bilingual content (EN/AR) displays correctly

---

## 📚 Full Documentation

For detailed information and advanced usage:
- See **SERVICES_INTEGRATION_GUIDE.md** for comprehensive examples
- See **SERVICES_DATA_SUMMARY.md** for complete service listing
- See **firestore_schema.md** for database structure details

---

## ⚠️ Important Notes

1. **Keep firebase-key.json private** - Add to `.gitignore`
   ```
   firebase-key.json
   ```

2. **Security Rules** - Set up Firestore rules to control access:
   ```firestore
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /services/{document=**} {
         allow read: if true;
         allow write: if request.auth.token.admin == true;
       }
     }
   }
   ```

3. **Prices** - Currently empty in CSV. Update via:
   - Firebase Console
   - Admin panel in your app
   - Batch update script

---

## 🆘 Troubleshooting

**Script fails with "ModuleNotFoundError"**
```bash
pip install -r requirements.txt
```

**"Firestore not found" error in Flutter**
- Verify cloud_firestore in pubspec.yaml
- Run `flutter pub get`
- Check Firebase initialization in main.dart

**Services not appearing in Firestore**
- Check Firebase Console > Firestore > services collection
- Verify script output shows "61 services added"
- Check browser console for errors

---

## 🎯 Next Steps

1. ✅ Upload services to Firestore
2. Build service listing screens
3. Implement service booking flow
4. Add search and filtering
5. Display prices and ratings
6. Create admin panel for management

---

**Created:** February 25, 2026  
**Version:** 1.0
