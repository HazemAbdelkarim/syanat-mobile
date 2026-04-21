# Firestore Services Collection Schema

## Document Structure

Each service is stored as a document in the `services` collection with the following schema:

```
services/
├── {serviceId}
│   ├── category_en: string
│   ├── category_ar: string
│   ├── subcategory_en: string
│   ├── subcategory_ar: string
│   ├── service_name_en: string
│   ├── service_name_ar: string
│   ├── price: number (nullable)
│   └── createdAt: timestamp
```

## Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `category_en` | string | Main service category in English (e.g., "AC Services", "Plumbing") |
| `category_ar` | string | Main service category in Arabic (e.g., "تكييف", "سباكة") |
| `subcategory_en` | string | Subcategory in English (e.g., "Maintenance", "Repairs") |
| `subcategory_ar` | string | Subcategory in Arabic (e.g., "صيانة", "تصليح") |
| `service_name_en` | string | Specific service name in English (e.g., "Cleaning & Filter Wash") |
| `service_name_ar` | string | Specific service name in Arabic (e.g., "تنظيف وغسيل فلاتر") |
| `price` | number \| null | Price in EGP (Egyptian Pounds), can be null |
| `createdAt` | timestamp | Document creation timestamp |

## Example Document

```json
{
  "category_en": "AC Services",
  "category_ar": "تكييف",
  "subcategory_en": "Maintenance",
  "subcategory_ar": "صيانة",
  "service_name_en": "Cleaning & Filter Wash",
  "service_name_ar": "تنظيف وغسيل فلاتر",
  "price": null,
  "createdAt": "2026-02-25T00:00:00Z"
}
```

## Indexes (Optional)

For better query performance, consider creating composite indexes:
- `category_en` + `subcategory_en` (for filtering by category and subcategory)
- `category_en` + `price` (for price range queries)
