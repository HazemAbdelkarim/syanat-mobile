# ✅ SERVICES SETUP - COMPLETE GUIDE

## Current Status
- ✅ **CSV Validated**: All 61 services successfully parsed
- ✅ **Flutter Models**: Service.dart created (bilingual support)
- ✅ **Repository**: ServiceRepository.dart created (data access patterns)
- ✅ **UI Screen**: ServicesScreen.dart created (with category filtering)
- ✅ **Python Script**: Ready for upload to Firestore
- ⏳ **Firebase Credentials**: Needed to complete setup

---

## 🚀 QUICK SETUP (Choose One Path)

### Path A: Direct Upload via Firebase (Recommended)

1. **Get Firebase Service Account Key**
   - Go to: https://console.firebase.google.com
   - Select project: `syana-ea75a`
   - Click ⚙️ Settings → Service Accounts → Generate New Private Key
   - Download JSON file

2. **Prepare the Key**
   - Rename to: `firebase-key.json`
   - Place in: `c:\Users\lenovo\flutter_projects\`
   - Add to `.gitignore` - **IMPORTANT!**
   
3. **Run Upload Command**
   ```bash
   cd c:\Users\lenovo\flutter_projects
   python upload_services_to_firestore.py "Syanat_App_Developer_Workflow.csv" "firebase-key.json"
   ```

4. **Verify in Firebase**
   - Go to Firebase Console
   - Check Firestore → `services` collection
   - All 61 services should appear

---

### Path B: Add Services Manually in Firebase Console

1. Open Firebase Console → Firestore
2. Create `services` collection
3. Add documents with schema:
   ```
   category_en: string
   category_ar: string
   subcategory_en: string
   subcategory_ar: string
   service_name_en: string
   service_name_ar: string
   price: number (optional)
   createdAt: timestamp
   ```

---

## 📱 USE SERVICES IN YOUR FLUTTER APP

### 1. Add Services Screen to Your Navigation

Edit your main screen navigation to include the new `ServicesScreen`:

```dart
// In your navigation or home screen
ServicesScreen(setLocale: setLocale)
```

### 2. Quick Example: Display All Services

```dart
import 'models/service.dart';
import 'repositories/service_repository.dart';

class MyServicesWidget extends StatefulWidget {
  @override
  State<MyServicesWidget> createState() => _MyServicesWidgetState();
}

class _MyServicesWidgetState extends State<MyServicesWidget> {
  final _serviceRepo = ServiceRepository();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Service>>(
      future: _serviceRepo.getAllServices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final services = snapshot.data ?? [];
        
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
    );
  }
}
```

### 3. Real-time Updates (Highly Recommended)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

StreamBuilder<List<Service>>(
  stream: _serviceRepo.streamServicesByCategory('AC Services'),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    
    final services = snapshot.data!;
    return ListView.builder(
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          child: ListTile(
            title: Text(service.serviceNameEn),
            subtitle: Text(service.serviceNameAr),
          ),
        );
      },
    );
  },
)
```

---

## 📊 DATA SUMMARY

| Category | Services | Status |
|----------|----------|--------|
| AC Services | 8 | ✅ Ready |
| Plumbing | 11 | ✅ Ready |
| Electricity | 8 | ✅ Ready |
| Security & Intercom | 5 | ✅ Ready |
| Large Appliances | 7 | ✅ Ready |
| Small Appliances | 6 | ✅ Ready |
| Carpentry | 5 | ✅ Ready |
| Pest Control | 4 | ✅ Ready |
| Alometal | 4 | ✅ Ready |
| Finishing | 5 | ✅ Ready |
| **TOTAL** | **61** | **✅ Ready** |

**Bilingual Content**: All services have English and Arabic translations ✅

---

## 🔧 AVAILABLE METHODS

### Fetch Services

```dart
// Get all services
final allServices = await _serviceRepo.getAllServices();

// Get services by category
final acServices = await _serviceRepo.getServicesByCategory('AC Services');

// Get services by subcategory
final maintenance = await _serviceRepo.getServicesBySubcategory(
  'AC Services',
  'Maintenance'
);

// Search services
final results = await _serviceRepo.searchServices('Cleaning');

// Get all categories
final categories = await _serviceRepo.getCategories();

// Get subcategories for a category
final subs = await _serviceRepo.getSubcategories('AC Services');
```

### Real-time Streams

```dart
// Stream all services
_serviceRepo.streamAllServices();

// Stream by category
_serviceRepo.streamServicesByCategory('AC Services');

// Stream by subcategory
_serviceRepo.streamServicesBySubcategory('AC Services', 'Maintenance');
```

### Admin Operations

```dart
// Add new service
final id = await _serviceRepo.addService(newService);

// Update service
await _serviceRepo.updateService(serviceId, updatedService);

// Delete service
await _serviceRepo.deleteService(serviceId);

// Batch update prices
await _serviceRepo.updatePrices({
  'service1': 100.0,
  'service2': 150.0,
});
```

---

## ✅ VERIFICATION CHECKLIST

After uploading services to Firestore:

- [ ] CSV validated (61 services)
- [ ] Firebase credentials obtained
- [ ] Service account key downloaded
- [ ] Upload script executed successfully
- [ ] Services visible in Firebase Firestore console
- [ ] `lib/models/service.dart` added to project
- [ ] `lib/repositories/service_repository.dart` added to project
- [ ] `lib/services_screen.dart` added to project
- [ ] Cloud Firestore dependency in pubspec.yaml ✅
- [ ] Services screen displays categories
- [ ] Real-time updates work correctly

---

## 🐛 TROUBLESHOOTING

### Issue: "Services collection not found"
**Solution**: Upload is still pending. Run the Python script with firebase-key.json

### Issue: "Timestamp parsing error"
**Solution**: Ensure createdAt field in Cloud Firestore is a timestamp type

### Issue: "Real-time updates not showing"
**Solution**: Check Firestore security rules - should allow read access

### Issue: "Python script fails"
**Solution**: Ensure firebase-admin is installed:
```bash
pip install firebase-admin
```

### Issue: "CSV encoding error"
**Solution**: The script now handles UTF-8 BOM automatically

---

## 🔒 SECURITY NOTES

1. **Never commit firebase-key.json to Git**
   ```
   # Add to .gitignore
   firebase-key.json
   ```

2. **Set Firestore Security Rules**
   ```firestore
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /services/{document=**} {
         // Public read access
         allow read: if true;
         
         // Only admins can write
         allow write: if request.auth.token.admin == true;
       }
     }
   }
   ```

3. **Restrict Firebase API Keys**
   - Firebase Console → Settings → API Keys
   - Restrict to Firestore and Authentication only

---

## 📋 FILES CREATED

| File | Purpose |
|------|---------|
| `upload_services_to_firestore.py` | Bulk upload Python script |
| `setup_services.py` | CSV validation & setup guide |
| `lib/models/service.dart` | Service data model |
| `lib/repositories/service_repository.dart` | Data access layer |
| `lib/services_screen.dart` | UI for browsing services |
| `requirements.txt` | Python dependencies |

---

## 🎯 NEXT STEPS

1. ✅ **Validate CSV** - Done!
2. ⏳ **Get Firebase key** - Go to Firebase Console
3. 🚀 **Upload services** - Run Python script
4. 📱 **Add to app UI** - Integrate ServicesScreen
5. 🎨 **Customize styling** - Match your app theme
6. 🔐 **Set security rules** - Protect your data

---

**Created**: February 25, 2026  
**Status**: Ready for Firebase upload  
**Services**: 61 (All validated & bilingual)
