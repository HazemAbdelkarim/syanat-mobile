# Quickstart — Event-Driven Stats (Spec 003)

**Audience**: Any engineer setting up the local environment to build, test, or verify Spec 003 triggers.
**Assumes**: Spec 002 scaffold is already in place (`functions/` exists with `package.json`, `tsconfig.json`, `node_modules`). If not, run Spec 002's quickstart first.

---

## 1. One-time setup

```powershell
# From repo root
cd functions
npm install        # if node_modules is missing or stale
cd ..
```

Verify the Firebase emulator is available:

```powershell
firebase --version       # any recent version
firebase emulators:start --only firestore,auth,functions   # Ctrl+C once it boots
```

The emulator uses `firebase.json` at the repo root — already configured.

---

## 2. Build the TypeScript

```powershell
cd functions
npm run build
cd ..
```

This compiles `functions/src/**/*.ts` → `functions/lib/**/*.js`, which is what the emulator actually executes. Build errors here MUST be fixed before the emulator will pick up new code.

---

## 3. Run the test suite (primary pre-prod gate — SC-007)

```powershell
cd functions
npm run test:emulators
cd ..
```

Under the hood, this runs `firebase emulators:exec --only functions,firestore,auth "jest --runInBand"`. The emulators boot, Jest runs against them, and the command exits with Jest's exit code. Exit `0` is the deploy gate. Exit non-zero blocks deploy.

For faster iteration on a single trigger:

```powershell
cd functions
npm run test:emulators -- --testPathPattern=stats/on-job-status-changed
```

---

## 4. Manual verification in the emulator (optional)

Start the emulator and hit the UI:

```powershell
firebase emulators:start --only firestore,auth,functions
```

The Emulator UI at `http://localhost:4000` lets you:

1. **Seed `stats/global`**: Firestore UI → Add Document → path `stats/global`, start with fields at `0`.
2. **Create a user**: Add Document → `users/test-user-1` with `role: 'customer'`. Within ~1s, the Functions log shows `onUserCreated` firing. Refresh `stats/global` — `totalUsers: 1`, `customers: 1`.
3. **Create a job**: Add Document → `jobs/test-job-1` with `status: 'requested'`. Verify `jobsRequested: 1`.
4. **Update job status**: Edit `jobs/test-job-1`, change `status` to `active`. Verify `jobsRequested: 0`, `jobsOngoing: 1`.
5. **Complete a job**: Edit `jobs/test-job-1`, set `status: 'completed'`, `amountPaid: 150`. Verify `jobsOngoing: 0`, `jobsCompleted: 1`, `totalEarnings: 150`.
6. **Verify lockdown** (after rule flip): Firestore UI → try to edit `stats/global` directly with an admin-role user — the write MUST be denied.

---

## 5. Verify the mobile-side cleanup (FR-008)

```powershell
# From repo root — zero incremental stats writes should remain after cleanup
```

Grep via the Grep tool or your IDE for `stats/global` in `lib/`. After the cleanup, the only remaining reference should be `initializeStatsGlobal()` (admin bootstrap tool, preserved per spec §US5 AS4) and the admin-dashboard **read** at `lib/admin_dashboard_screen.dart`. All `firestore.doc('stats/global').set(...)` increment sites MUST be gone.

---

## 6. Deploy (production — gated on Blaze plan)

```powershell
# From repo root. Atomic deploy of functions + rules (FR-010).
firebase deploy --only functions,firestore:rules
```

This uploads all Cloud Functions (Spec 002 admin callables + Spec 003 stats triggers) and pushes the updated `firestore.rules` (including the `stats/{docId}` lockdown) in a single command.

**Pre-deploy checklist**:
- [ ] `npm run test:emulators` exits `0` (SC-007)
- [ ] `lib/firebase_service.dart` grep for `stats/global` shows only `initializeStatsGlobal()` + admin-dashboard read references
- [ ] `firestore.rules` stats block reads `allow write: if false;` (FR-006)
- [ ] `firestore.rules` has a `_event_dedup/{eventId}` block with `allow read, write: if false;`
- [ ] Blaze plan is enabled on `syana-ea75a` (gated with Spec 002 deploy)

**Post-deploy checklist**:
- [ ] Firebase Console → Firestore Rules → attempt to write `stats/global` as any signed-in user in the Rules Playground → denied (SC-005)
- [ ] Create a test user in production → `stats/global.totalUsers` increments within ~5s (SC-002)
- [ ] Over a 72-hour window, check Firestore logs for rule denials on `stats/*` — should be near zero (SC-001; some noise from old app versions is expected initially)

---

## 7. Post-deploy: configure the `_event_dedup` TTL

One-time GCP setup to let Firestore sweep the dedup markers:

```powershell
gcloud firestore fields ttls update processedAt --collection-group=_event_dedup --enable-ttl --project=syana-ea75a
```

Without this, `_event_dedup/*` grows indefinitely. With it, Firestore deletes markers ~24 hours after their `processedAt` timestamp (TTL retention is best-effort with a short grace period — acceptable because the marker is only needed during a retry window, which is bounded at minutes).

---

## 8. Rollback (if the deploy misbehaves)

If triggers misfire and counters go wrong in production:

```powershell
# Re-open the stats collection so clients can write again while you debug.
# This partially reverts FR-006 ONLY — do NOT revert FR-010's atomic deploy by splitting.
firebase deploy --only firestore:rules   # with stats rule reverted to the pre-spec value
# Then re-seed stats/global via the admin bootstrap tool (initializeStatsGlobal)
```

Note: this is the only sanctioned rollback path. Do NOT delete individual triggers from the Firebase Console without also re-opening the rule — you will stop stats updates entirely.

---

## 9. Debugging tips

- **Trigger not firing?** Check `firebase emulators:exec` log for `Loaded functions definitions from source: onUserCreated, onJobCreated, onJobStatusChanged`. Missing names mean the build didn't include them — re-run `npm run build`.
- **Counter off by 1?** Check Functions logs for retry events — the dedup marker should prevent double-counts. If you see `already-exists` on the marker and then a skipped trigger, dedup is working as designed.
- **Unknown status logged?** Add the status to `STATUS_TO_BUCKET` in `functions/src/stats/lib/status-map.ts`. Do NOT silently map it to `jobsOngoing` — unknowns should remain loud until the mapping is intentionally updated.
