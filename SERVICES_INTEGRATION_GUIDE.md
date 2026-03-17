
# Services Upload & Integration Guide

## Overview

This guide walks you through uploading the services CSV to Firebase Cloud Firestore and integrating the Service model into your Flutter app.

## Part 1: Upload Services to Firestore

### Prerequisites

1. **Firebase Project Setup**
   - Ensure you have a Firebase project created
   - Enable Cloud Firestore
   - Create a service account key

2. **Python Environment**
   ```bash
   pip install firebase-admin
   ```

3. **Service Account Credentials**
   - Download your Firebase service account key from Firebase Console
   - Go to: Project Settings → Service Accounts → Generate Private Key
   - Save as `firebase-key.json`

### Running the Upload Script

```bash
# Basic usage
python upload_services_to_firestore.py <path_to_csv> <path_to_credentials.json>

# Example
python upload_services_to_firestore.py "Syanat_App_Developer_Workflow.csv" "firebase-key.json"

# With explicit project ID
python upload_services_to_firestore.py "Syanat_App_Developer_Workflow.csv" "firebase-key.json" --project-id "your-project-id"
```

### Script Output

The script will:
- Parse all 61 service entries from the CSV
- Validate data integrity
- Create documents in the `services` collection
- Print progress and any errors encountered
- Summary of uploaded services

### Verification

After upload, verify in Firebase Console:
1. Go to Firestore Database
2. Check the `services` collection
3. Each document should have all fields (category, subcategory, service name in EN/AR, price, createdAt)

---

## Part 2: Using the Service Model in Flutter

### Installation

Ensure you have the required dependency in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^4.13.0  # or latest version
```

### Basic Usage

#### 1. Fetch a Single Service

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/service.dart';

Future<Service?> fetchService(String serviceId) async {
  final doc = await FirebaseFirestore.instance
      .collection('services')
      .doc(serviceId)
      .get();
  
  if (doc.exists) {
    return Service.fromFirestore(doc);
  }
  return null;
}
```

#### 2. Fetch All Services

```dart
Future<List<Service>> fetchAllServices() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('services')
      .get();
  
  return snapshot.docs
      .map((doc) => Service.fromFirestore(doc))
      .toList();
}
```

#### 3. Fetch Services by Category

```dart
Future<List<Service>> fetchServicesByCategory(String categoryEn) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('services')
      .where('category_en', isEqualTo: categoryEn)
      .get();
  
  return snapshot.docs
      .map((doc) => Service.fromFirestore(doc))
      .toList();
}
```

#### 4. Fetch Services by Category and Subcategory

```dart
Future<List<Service>> fetchServicesBySubcategory(
  String categoryEn,
  String subcategoryEn,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('services')
      .where('category_en', isEqualTo: categoryEn)
      .where('subcategory_en', isEqualTo: subcategoryEn)
      .get();
  
  return snapshot.docs
      .map((doc) => Service.fromFirestore(doc))
      .toList();
}
```

#### 5. Real-time Listener (StreamBuilder)

```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('services')
      .where('category_en', isEqualTo: 'AC Services')
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    
    final services = snapshot.data!.docs
        .map((doc) => Service.fromFirestore(doc))
        .toList();
    
    return ListView.builder(
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return ListTile(
          title: Text(service.serviceNameEn),
          subtitle: Text(service.categoryEn),
          trailing: service.price != null
              ? Text('${service.price} EGP')
              : null,
        );
      },
    );
  },
)
```

#### 6. Add/Update a Service

```dart
Future<void> addService(Service service) async {
  await FirebaseFirestore.instance
      .collection('services')
      .add(service.toMap());
}

Future<void> updateService(String serviceId, Service service) async {
  await FirebaseFirestore.instance
      .collection('services')
      .doc(serviceId)
      .update(service.toMap());
}
```

#### 7. Delete a Service

```dart
Future<void> deleteService(String serviceId) async {
  await FirebaseFirestore.instance
      .collection('services')
      .doc(serviceId)
      .delete();
}
```

### Advanced: Service Repository

Create a `service_repository.dart` for cleaner code:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/service.dart';

class ServiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<List<Service>> getAllServices() async {
    final snapshot = await _firestore.collection('services').get();
    return snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();
  }
  
  Future<List<Service>> getServicesByCategory(String categoryEn) async {
    final snapshot = await _firestore
        .collection('services')
        .where('category_en', isEqualTo: categoryEn)
        .get();
    return snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();
  }
  
  Future<List<Service>> getServicesBySubcategory(
    String categoryEn,
    String subcategoryEn,
  ) async {
    final snapshot = await _firestore
        .collection('services')
        .where('category_en', isEqualTo: categoryEn)
        .where('subcategory_en', isEqualTo: subcategoryEn)
        .get();
    return snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();
  }
  
  Future<List<String>> getCategories() async {
    final snapshot = await _firestore.collection('services').get();
    final categories = <String>{};
    for (final doc in snapshot.docs) {
      final service = Service.fromFirestore(doc);
      categories.add(service.categoryEn);
    }
    return categories.toList();
  }
  
  Stream<List<Service>> watchServicesByCategory(String categoryEn) {
    return _firestore
        .collection('services')
        .where('category_en', isEqualTo: categoryEn)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
  }
}
```

### Using the Repository

```dart
final serviceRepo = ServiceRepository();

// Get all services
final allServices = await serviceRepo.getAllServices();

// Get AC services
final acServices = await serviceRepo.getServicesByCategory('AC Services');

// Watch category changes in real-time
serviceRepo.watchServicesByCategory('AC Services').listen((services) {
  print('Services updated: ${services.length}');
});
```

---

## CSV Data Summary

The CSV contains **61 service entries** across **9 categories**:

1. **AC Services** (8 services)
2. **Plumbing** (11 services)
3. **Electricity** (8 services)
4. **Security & Intercom** (5 services)
5. **Large Appliances** (7 services)
6. **Small Appliances** (6 services)
7. **Carpentry** (5 services)
8. **Pest Control** (4 services)
9. **Alometal** (4 services)
10. **Finishing** (5 services)

---

## Troubleshooting

### Upload Script Issues

**Error: "Firebase credentials file not found"**
- Ensure the path to credentials JSON is correct
- Check file permissions

**Error: "Firestore already initialized"**
- The script handles cleanup, but restart if needed

**Error: "Permission denied on Firestore"**
- Check Firestore security rules
- Ensure service account has proper permissions

### Flutter Integration Issues

**Error: "Service model import not found"**
- Verify the file path: `lib/models/service.dart`
- Ensure pubspec.yaml has `cloud_firestore` dependency

**Error: "Timestamp type mismatch"**
- Ensure Cloud Firestore is properly initialized
- Check Firestore security rules allow reads

---

## Security Considerations

1. **Never commit** `firebase-key.json` to version control
   - Add to `.gitignore`
   
2. **Use Firestore Security Rules** to protect data:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /services/{document=**} {
      // Read: Allow all users to read services
      allow read: if true;
      
      // Write: Only authenticated admins can write
      allow write: if request.auth != null && request.auth.token.admin == true;
    }
  }
}
```

3. **Environment Variables**: Store Firebase config in a `firebase_config.dart` file
4. **API Key Restrictions**: In Firebase Console, restrict API keys to specific APIs

---

## Next Steps

1. ✅ Run the upload script to populate Firestore
2. ✅ Add the Service model to your Flutter project
3. ✅ Create a ServiceRepository for data access
4. ✅ Implement UI screens using the service data
5. ✅ Set up Firestore security rules
6. ✅ Test bilingual (EN/AR) content rendering
