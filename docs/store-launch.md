# Store Launch Reference

Single source of truth for Play Store + App Store submission. Copy text directly from this file into the consoles.

---

## 1. Asset inventory

| Asset | Path | Status |
|---|---|---|
| App icon (Android launcher, all densities) | `android/app/src/main/res/mipmap-*/` | ✅ Built by `flutter_launcher_icons` |
| App icon (iOS, all sizes) | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | ✅ Built by `flutter_launcher_icons` |
| Play Store icon (512×512 PNG) | `store-assets/play-icon-512.png` | ✅ Generated from `assets/branding/icon_full.png` |
| App Store icon (1024×1024 PNG) | `assets/branding/icon_full.png` | ✅ Source — App Store reads this from the IPA via AppIcon.appiconset |
| Play Store feature graphic (1024×500 PNG) | `store-assets/feature-graphic-1024x500.png` | ⚠️ Generated placeholder. Replace with a designer-made version before launch if you want polish. |
| Phone screenshots | `store-assets/screenshots/` | ❌ Must be captured — see §4 |
| Privacy policy URL | https://syanat-privacy.web.app | ✅ Live |

---

## 2. Store copy — English

### App Store Connect

**App Name (max 30 chars):**
```
Syanat
```

**Subtitle (max 30 chars):**
```
Home maintenance, on demand
```

**Promotional Text (max 170 chars, shown above the description, updatable without re-review):**
```
Book trusted technicians for plumbing, electrical, AC repair, and more — at your doorstep across Egypt. Pin your exact spot on the map and track every step.
```

**Keywords (max 100 chars, comma-separated, no spaces between):**
```
home,maintenance,technician,plumbing,electrical,AC,repair,Egypt,booking,handyman,fix,صيانة
```

**Description (max ~4000 chars, no formatting):**
```
Syanat connects you with verified home-maintenance technicians across Egypt. Whether it's a leaking tap, a flickering light, or an AC that's stopped cooling, book a qualified technician in minutes and watch the job get done on your terms.

WHY SYANAT
• Verified technicians, vetted by our team
• Transparent pricing — see the receipt before you pay
• Pin your exact location on the map so the technician arrives at the right door
• Live status updates from booking to completion
• In-app dispute resolution if something isn't right
• Pay only after you approve the work

HOW IT WORKS
1. Pick the service you need
2. Pin your address on the map and describe the problem
3. We assign a nearby technician — you see their name and ETA
4. The technician arrives, inspects, and shares a receipt for your approval
5. You approve the receipt, pay, and rate the service

PERFECT FOR
• Apartment owners and renters
• Office managers
• Anyone who's tired of chasing handymen on the phone

LANGUAGES
Available in English and Arabic, with full right-to-left support.

PRIVACY
We collect only what we need to connect you with a technician. We never sell your data. Read the full policy at https://syanat-privacy.web.app

SUPPORT
Questions? Email privacy@syanat.app — we usually reply within one business day.

Currently available in Cairo, Giza, and surrounding areas. New cities added regularly.
```

**Support URL:** *fill in once you have one — e.g. https://syanat-privacy.web.app/support or a Google Form*
**Marketing URL (optional):** *your landing page if you have one*
**Privacy Policy URL:** `https://syanat-privacy.web.app`

### Play Store

**App Name (max 30 chars):**
```
Syanat
```

**Short description (max 80 chars):**
```
Book trusted home technicians in Egypt — plumbing, electrical, AC, and more
```

**Full description (max 4000 chars):**
```
Syanat connects you with verified home-maintenance technicians across Egypt. Whether it's a leaking tap, a flickering light, or an AC that's stopped cooling, book a qualified technician in minutes and watch the job get done on your terms.

★ WHY SYANAT ★
• Verified technicians, vetted by our team
• Transparent pricing — see the receipt before you pay
• Pin your exact location on the map so the technician arrives at the right door
• Live status updates from booking to completion
• In-app dispute resolution if something isn't right
• Pay only after you approve the work

★ HOW IT WORKS ★
1. Pick the service you need
2. Pin your address on the map and describe the problem
3. We assign a nearby technician — you see their name and ETA
4. The technician arrives, inspects, and shares a receipt for your approval
5. You approve the receipt, pay, and rate the service

★ PERFECT FOR ★
Apartment owners and renters, office managers, and anyone tired of chasing handymen by phone.

★ LANGUAGES ★
Available in English and Arabic, with full right-to-left support.

★ PRIVACY ★
We collect only what we need to connect you with a technician. We never sell your data. Full policy: https://syanat-privacy.web.app

★ SUPPORT ★
Email privacy@syanat.app — usually replies within one business day.

Currently available in Cairo, Giza, and surrounding areas. New cities added regularly.
```

---

## 3. Store copy — Arabic (العربية)

### App Store Connect

**اسم التطبيق (الحد الأقصى 30 حرفًا):**
```
صيانات
```

**العنوان الفرعي (الحد الأقصى 30 حرفًا):**
```
صيانة منزلك في متناول يدك
```

**النص الترويجي (الحد الأقصى 170 حرفًا):**
```
احجز فنيين موثوقين للسباكة والكهرباء وتكييف الهواء وغيرها — يأتون إلى باب منزلك في جميع أنحاء مصر. حدد موقعك بدقة على الخريطة وتابع كل خطوة.
```

**الكلمات المفتاحية (الحد الأقصى 100 حرف، مفصولة بفواصل):**
```
صيانة,منزل,فني,سباكة,كهرباء,تكييف,إصلاح,مصر,حجز,نجار,تصليح,Syanat
```

**الوصف:**
```
صيانات يربطك بفنيي صيانة منازل موثوقين في جميع أنحاء مصر. سواء كان صنبور يسرّب، إضاءة تومض، أو مكيف توقف عن التبريد، احجز فنيًا مؤهلًا خلال دقائق وتابع تنفيذ الخدمة وفق شروطك.

★ لماذا صيانات ★
• فنيون موثوقون مُعتمدون من فريقنا
• أسعار شفافة — راجع الفاتورة قبل الدفع
• ثبّت موقعك بدقة على الخريطة ليصل الفني إلى الباب الصحيح
• تحديثات حية لحالة الطلب من الحجز إلى الإنجاز
• حل النزاعات داخل التطبيق إذا حدث خطأ
• ادفع فقط بعد موافقتك على العمل

★ كيف يعمل ★
1. اختر الخدمة التي تحتاجها
2. حدد عنوانك على الخريطة وصف المشكلة
3. نُسند فنيًا قريبًا — وترى اسمه ووقت الوصول
4. يصل الفني، يفحص الموقع، ويشاركك الفاتورة لاعتمادها
5. توافق على الفاتورة، تدفع، وتقيّم الخدمة

★ مثالي لـ ★
ملاك ومستأجري الشقق، مديري المكاتب، وأي شخص سئم مطاردة الفنيين عبر الهاتف.

★ اللغات ★
متاح بالعربية والإنجليزية مع دعم كامل للكتابة من اليمين إلى اليسار.

★ الخصوصية ★
لا نجمع إلا ما نحتاجه لربطك بفني. لا نبيع بياناتك أبدًا. السياسة الكاملة: https://syanat-privacy.web.app

★ الدعم ★
راسلنا على privacy@syanat.app — نرد عادةً خلال يوم عمل واحد.

متاح حاليًا في القاهرة والجيزة والمناطق المحيطة. مدن جديدة تُضاف باستمرار.
```

### Play Store (نسخة Play)

**الوصف القصير (الحد الأقصى 80 حرفًا):**
```
احجز فنيي صيانة موثوقين في مصر — سباكة وكهرباء وتكييف وغيرها
```

**الوصف الكامل:** *نفس النص الإنجليزي أعلاه. الإصدار العربي يستخدم القالب نفسه — انسخ القسم العربي من Store Connect.*

---

## 4. Screenshots

### Required device classes

| Store | Device class | Resolution | Min | Max | Required? |
|---|---|---|---|---|---|
| App Store | 6.7" iPhone (15 Pro Max, 16 Pro Max) | 1290 × 2796 | 3 | 10 | **Yes** — primary device class |
| App Store | 6.5" iPhone (11 Pro Max) | 1242 × 2688 | 3 | 10 | Optional (auto-derived from 6.7" if not provided) |
| App Store | 6.1" iPhone (15, 16) | 1179 × 2556 | 3 | 10 | Optional |
| App Store | iPad 12.9" (if you support iPad) | 2048 × 2732 | 3 | 10 | Required only if `LSRequiresIPhoneOS=false` |
| Play Store | Phone | 1080 × 1920 (or any 16:9 / 9:16) | 2 | 8 | **Yes** |
| Play Store | 7" tablet | 1080 × 1920 minimum | 0 | 8 | Optional |
| Play Store | 10" tablet | 1080 × 1920 minimum | 0 | 8 | Optional |

### Suggested screen list (5 screenshots, both languages)

These cover the critical user flows for the customer side:

1. **Welcome / Login** — `lib/login_screen.dart` — the brand entrance
2. **Service grid (home)** — pick a service category
3. **Order request with map pin** — the differentiator
4. **Live job status** — "Technician is on the way"
5. **Receipt approval** — transparency promise

You can add 1–3 more from saved-locations, technician profile, or sign-up if you want a longer reel. **Don't show admin or technician screens to App Store reviewers** — those flows are for a different audience.

### Capture method

```powershell
# Android emulator
flutter run --release --device-id <emulator-id>
# Then: emulator side-bar camera icon, or `adb exec-out screencap -p > screen.png`
```

```bash
# iOS simulator (Mac only)
flutter run --release --device-id <booted-simulator-udid>
# Then: ⌘+S in the simulator
```

For each screenshot:
- Take it on a fresh signed-in customer account
- Make sure the status bar shows a plausible time (e.g. 9:41 AM matches Apple convention) — there are tools (Apple's `xcrun simctl status_bar`) that fake this
- Take both EN and AR versions of each flow
- Save into `store-assets/screenshots/<store>/<device>/<language>/01-welcome.png` etc.

---

## 5. Content rating questionnaires

### Apple App Store — Age Rating

App Store Connect → App → Age Rating → Edit. Answer "None" or "No" to all of:

| Category | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Simulated Gambling | None |
| Sexual Content and Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Contests | None |
| Unrestricted Web Access | **No** (your app does not browse arbitrary URLs) |
| Gambling | No |
| User-Generated Content | **No** — receipts/photos are job-scoped, not a public feed |

**Expected rating:** 4+ (everyone)

### Google Play — Content Rating questionnaire

Play Console → Policy → App Content → Content rating. The questionnaire asks ~30 yes/no questions across IARC categories. For Syanat the answers are uniformly "No" except:

| Question | Answer |
|---|---|
| Does your app allow users to interact with each other? | **Yes** — customers and technicians communicate in-app for an order |
| Can users exchange personal information? | **No** — phone numbers are revealed by the system only after assignment; users don't share email/addresses freely |
| Does your app share user location? | **Yes — with other users** (the assigned technician sees the customer's pinned location for the job) |
| User-generated content moderated? | **Yes** — admin review of disputes is the moderation mechanism |
| Allows real-money purchases / digital transactions? | **No, in v1** — current implementation has tech receiving cash on-site. If you add in-app payments later, change this. |

Everything else: **No**.

**Expected rating:** Everyone / 3+ / PEGI 3

---

## 6. Data Safety (Play Console)

Play Console → Policy → App Content → Data safety. Pre-filled answers below mirror the privacy policy at https://syanat-privacy.web.app.

**Does your app collect or share any of the required user data types?** Yes.

**Is all user data encrypted in transit?** Yes (HTTPS/TLS — see firebase.json CSP headers).

**Do you provide a way for users to request that their data be deleted?** Yes (Account → Delete account, in-app).

### Data types collected:

| Data type | Collected | Shared with third party | Optional | Purpose |
|---|---|---|---|---|
| Name | Yes | No | No | Account management, Service personalization |
| Email | Yes | No | No | Account management |
| Phone number | Yes | **Yes (with the assigned technician for that order)** | No | Account management, App functionality |
| Photos | Yes | No | Yes | App functionality (receipts, profile) |
| Precise location | Yes | **Yes (with the assigned technician for that order)** | Yes (only when user pins) | App functionality |
| Approximate location | No | — | — | — |
| App interactions (job history) | Yes | No | No | Analytics, App functionality |
| Crash logs | Yes | No | No | Analytics (Firebase Crashlytics) |
| Diagnostics | Yes | No | No | Analytics |
| Installed apps / device IDs | No | — | — | — |

**No advertising, no targeted ads, no data sold to third parties.**

---

## 7. URLs you need ready

| Field | Value | Where to put it |
|---|---|---|
| Privacy Policy URL | `https://syanat-privacy.web.app` | Both stores |
| Support URL | *fill in — easiest is the privacy site with a `/support` route or `mailto:` form* | App Store Connect |
| Marketing URL | Optional | App Store Connect |
| Account deletion URL | `https://syanat-privacy.web.app#rights` (links to the "Your rights" section that documents in-app deletion) | Play Console (required) |

---

## 8. Versioning & metadata

| Field | Value |
|---|---|
| Bundle ID (iOS) / Application ID (Android) | `com.syanat.app` |
| Initial version | `1.0.0` (build 1) |
| Primary language | Arabic (or English — your call; you can localize the other) |
| Category (App Store) | Primary: **Utilities** or **Lifestyle**. Secondary: optional |
| Category (Play) | **House & Home** |
| Age rating | 4+ / Everyone / 3+ |
| Content advisory | None |
| Pricing | Free |
| In-app purchases | None (in v1) |

---

## 9. Submission checklist (your turn)

These are the steps that cannot happen from a Windows machine without your accounts:

### Pre-flight

- [ ] Apple Developer Program membership ($99/year) — https://developer.apple.com/programs/enroll/
- [ ] Google Play Console one-time registration fee ($25) — https://play.google.com/console/signup
- [ ] Decide on a support contact (email or simple landing page)
- [ ] Verify you own / can use the name "Syanat" / "صيانات"
- [ ] Final keystore password rotation in a clean PowerShell (no Claude session) — see Phase 3 notes
- [ ] Replace placeholder feature graphic with a designer-made one if you want polish (optional — the generated one works as a baseline)

### Capture screenshots

- [ ] Run signed release on an Android emulator (6.7" / 1080×2400 / Pixel 8 Pro AVD recommended)
- [ ] Capture 5 customer-flow screenshots, EN
- [ ] Toggle language to AR (Account → Language), repeat for 5 AR screenshots
- [ ] (Phase 6 dependent on Mac) Run iOS simulator (iPhone 15 Pro Max), capture EN + AR sets
- [ ] Save under `store-assets/screenshots/<store>/<device>/<lang>/`

### Apple App Store Connect

- [ ] Reserve app name "Syanat" — https://appstoreconnect.apple.com/apps → "+" → New App
- [ ] Create App ID with Sign in with Apple capability — see Phase 3 iOS checklist
- [ ] Get a Mac with Xcode 15+ and a Distribution provisioning profile
- [ ] Build IPA: `flutter build ipa --release`
- [ ] Upload via Transporter or Xcode Organizer
- [ ] Fill metadata from §2 (English) and §3 (Arabic) of this doc
- [ ] Upload screenshots from `store-assets/screenshots/app-store/...`
- [ ] Set Privacy URL, Support URL, age rating (§5)
- [ ] Set "Sign-In Information" if Apple wants a demo account (they will)
- [ ] Submit for review

### Google Play Console

- [ ] Create app in Play Console — choose "App", "Free", "Egypt + other regions"
- [ ] **Enroll in Play App Signing** during the AAB upload step (critical — see Phase 3 notes)
- [ ] Upload AAB: `build/app/outputs/bundle/release/app-release.aab`
- [ ] Fill Store listing: §2 (English) and §3 (Arabic)
- [ ] Upload 512×512 icon (`store-assets/play-icon-512.png`)
- [ ] Upload 1024×500 feature graphic (`store-assets/feature-graphic-1024x500.png` or your designer version)
- [ ] Upload screenshots from `store-assets/screenshots/play/...`
- [ ] Content rating questionnaire — answers in §5
- [ ] Data safety form — answers in §6
- [ ] Privacy policy URL
- [ ] Account deletion URL (Play now requires this — link to the rights section)
- [ ] Choose release track: **Internal testing** first (lets you test the full pipeline without going live), then promote to Production

### After first approval

- [ ] Test on real device installed via store, not sideloaded
- [ ] Verify Google Sign-In works on the signed release build (depends on SHA-1 from Phase 3)
- [ ] Verify Sign in with Apple works on iOS (depends on Apple capability + Firebase Auth config)
- [ ] Verify Crashlytics receives a test crash from the production build
- [ ] Verify the privacy page link in the store listing opens correctly

---

## 10. Things I cannot do for you

To be explicit so nothing falls through the cracks, these are the items that genuinely require *you* and cannot be automated from a Windows shell:

1. **Apple Developer enrollment + Mac access.** Apple does not have a Windows path. Without a Mac (real, rented, or CI-hosted), you cannot ship to App Store at all.
2. **Capturing real screenshots.** The app has to run on a device or emulator with a real signed-in account and real-looking data. I can describe which screens to capture but not generate the imagery.
3. **Creating store accounts and paying the fees.** $99/yr Apple + $25 one-time Google.
4. **Final design polish.** The placeholder feature graphic, store copy, and questionnaire answers are launchable baselines. A designer + a marketer reviewing them will move you from "passes review" to "actually converts installs".
5. **Final privacy-policy legal review.** The text at https://syanat-privacy.web.app accurately reflects the data flows in your code, but a lawyer who knows Egyptian PDPL (Law 151/2020) and Saudi PDPL should sign off before public launch.
6. **Final keystore password rotation.** Documented in Phase 3 — needs a fresh PowerShell with no Claude session attached so the password doesn't enter another conversation log.
7. **Reserving the app name.** Both stores require interactive sign-in to claim the name.
8. **App Store demo account.** Apple's reviewers will ask for a working customer login. You'll create a dummy customer in Firestore and give Apple its credentials in the App Store Connect review notes.

Everything else — text, icons, feature graphic, AAB, signing, fingerprints, questionnaire pre-fills, privacy site — is in this repo or already deployed.
