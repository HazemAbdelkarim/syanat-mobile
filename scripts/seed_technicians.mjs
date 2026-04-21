#!/usr/bin/env node
// Seeds three test technician accounts into the syana-ea75a project.
//
//   Tech A — AVAILABLE electrician:      tech.electric@syana.test / Test12345!
//   Tech B — BUSY plumber (simulated):   tech.plumb@syana.test    / Test12345!
//   Tech C — OFFLINE AC technician:      tech.ac@syana.test       / Test12345!
//
// Run from the repo root:
//   node --experimental-vm-modules scripts/seed_technicians.mjs
//
// Requires:
//   GOOGLE_APPLICATION_CREDENTIALS=<path to a service-account key JSON>
//     (or: `gcloud auth application-default login && gcloud config set project syana-ea75a`)
//
// The script is idempotent — re-running updates the users/{uid} docs and
// the auth password if the account already exists.

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const PROJECT_ID = process.env.GCLOUD_PROJECT || "syana-ea75a";

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });

const auth = getAuth();
const db = getFirestore();

const seeds = [
  {
    email: "tech.electric@syana.test",
    password: "Test12345!",
    fullName: "Ahmed Electric",
    phone: "+201000000011",
    availableForServices: ["electricity", "electrical"],
    isAvailable: true,
    rating: 4.9,
    completedJobsCount: 42,
    city: "New Cairo",
    photoURL: null,
  },
  {
    email: "tech.plumb@syana.test",
    password: "Test12345!",
    fullName: "Mostafa Plumb",
    phone: "+201000000022",
    availableForServices: ["plumbing"],
    // Available, but the seed also creates an active job assigned to them
    // below so they show up as "On a job" in the picker.
    isAvailable: true,
    rating: 4.6,
    completedJobsCount: 28,
    city: "New Cairo",
    photoURL: null,
  },
  {
    email: "tech.ac@syana.test",
    password: "Test12345!",
    fullName: "Omar AC",
    phone: "+201000000033",
    availableForServices: ["ac", "air_conditioning"],
    isAvailable: false, // offline
    rating: 4.3,
    completedJobsCount: 17,
    city: "Maadi",
    photoURL: null,
  },
];

async function ensureAuthUser(seed) {
  try {
    const existing = await auth.getUserByEmail(seed.email);
    await auth.updateUser(existing.uid, {
      password: seed.password,
      displayName: seed.fullName,
      phoneNumber: seed.phone,
    });
    return existing.uid;
  } catch (err) {
    if (err && err.code === "auth/user-not-found") {
      const created = await auth.createUser({
        email: seed.email,
        password: seed.password,
        displayName: seed.fullName,
        phoneNumber: seed.phone,
      });
      return created.uid;
    }
    throw err;
  }
}

async function main() {
  console.log(`Seeding technicians into project ${PROJECT_ID} …`);
  const out = [];
  for (const seed of seeds) {
    const uid = await ensureAuthUser(seed);
    const userDoc = db.collection("users").doc(uid);
    await userDoc.set(
      {
        role: "technician",
        fullName: seed.fullName,
        username: seed.fullName,
        phone: seed.phone,
        availableForServices: seed.availableForServices,
        isAvailable: seed.isAvailable,
        rating: seed.rating,
        completedJobsCount: seed.completedJobsCount,
        city: seed.city,
        photoURL: seed.photoURL,
        lastSeenAt: FieldValue.serverTimestamp(),
        joinedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    console.log(`  ✓ ${seed.email}  →  ${uid}`);
    out.push({ ...seed, uid });
  }

  // Simulate Tech B being on a job so the picker renders the "On a job" pill.
  // We write a synthetic active job assigned to Tech B. If you don't want a
  // synthetic job in prod data, comment out this block or delete the doc after.
  const busyTech = out[1];
  const jobRef = db.collection("jobs").doc(); // auto-id
  await jobRef.set({
    customerId: "seed-customer",
    customerName: "Seeded Customer",
    phoneNumber: "+201099999999",
    serviceKey: "plumbing",
    serviceCategory: "Home Services",
    description: "Seed-only test job to mark technician as busy.",
    locationLabel: "Seed Home",
    locationAddress: "Seed address, New Cairo",
    status: "active",
    assignedTechnicianId: busyTech.uid,
    technicianId: busyTech.uid,
    assignedTechnicianName: busyTech.fullName,
    assignedBy: "seed-script",
    price: 0,
    photos: [],
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    assignedAt: FieldValue.serverTimestamp(),
  });
  await db.collection("users").doc(busyTech.uid).set(
    { currentJobId: jobRef.id, isAvailable: false },
    { merge: true },
  );
  console.log(`  ✓ synthetic active job ${jobRef.id} assigned to ${busyTech.email}`);

  console.log("\nSeed complete. To clean up:");
  console.log("  - delete the three auth accounts in Firebase Console");
  console.log("  - delete the matching users/<uid> docs");
  console.log(`  - delete the synthetic job jobs/${jobRef.id}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Seed failed:", err);
    process.exit(1);
  });
