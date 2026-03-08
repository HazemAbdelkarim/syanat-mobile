# Firebase Cost Optimization Reference

Last updated: March 6, 2026

## Purpose
This document is a practical playbook to reduce Firebase costs as usage grows, without breaking core app functionality.

## Current Baseline
The app already includes major read-leak fixes:
- Services are read from `services` directly (no full technician scan).
- Technician home avoids per-row profile reads and uses customer caching.
- Admin stats use Firestore aggregation counts instead of full collection scans.
- Chat message-limit check reads at most 2 docs.

This is a good low-traffic baseline.

## Cost Drivers To Watch
1. Firestore reads from real-time listeners on large collections.
2. Repeated dashboard refreshes by admins.
3. Long chat histories read as one large stream.
4. Unbounded data retention (messages, logs, media).
5. Abuse/bot traffic from unverified clients.
6. Storage growth from uploaded images.

## Stage-Based Plan

## Stage 1: Low Traffic (Do Now)
Goal: protect against accidental overspend with minimal backend complexity.

1. Set budget and usage alerts in Google Cloud Billing.
2. Enable Firebase App Check for Firestore/Storage/Auth endpoints.
3. Keep hard limits on user-facing queries (`limit`, pagination-ready patterns).
4. Keep image compression before upload (already implemented).
5. Review and keep strict Firestore Security Rules.

Recommended alerts:
- 50%, 80%, 100% of monthly budget.
- Sudden daily spend jump alert.

## Stage 2: Moderate Growth (When traffic starts becoming regular)
Goal: reduce per-screen read cost and cap growth.

1. Chat pagination:
   - Load last 30-50 messages first.
   - Load older messages only on scroll.
2. Admin read optimization:
   - Keep aggregate counts for KPIs.
   - Reduce map refresh frequency or add caching.
3. Denormalize small display fields:
   - Store `customerNameSnapshot` in job doc when job is created.
   - Avoid profile fetches for list rendering where consistency is not critical.
4. Index hygiene:
   - Maintain required indexes only; remove unused composite indexes.

## Stage 3: Scale (Before heavy admin/ops traffic)
Goal: make read cost nearly constant for dashboards.

1. Server-side counters (Cloud Functions):
   - Maintain a `stats/global` doc (users/jobs/chats/revenue counters).
   - Dashboard reads one doc instead of many queries.
2. Scheduled aggregation jobs:
   - Daily/weekly summaries written to precomputed docs.
3. Separate hot/cold data:
   - Keep active data in primary collections.
   - Archive historical data to cheaper paths/buckets.

## Chat Retention and Deletion Strategy
This is the highest-value long-term control for both Firestore and Storage.

### Recommended policy
1. Keep full chat history for a fixed window (example: 90 or 180 days).
2. After the window:
   - Delete old `messages` docs, or
   - Archive to cheaper storage and keep only a minimal summary in Firestore.

### Implementation options
1. Firestore TTL:
   - Add `expiresAt` to each message.
   - Configure Firestore TTL policy on `expiresAt`.
2. Scheduled Cloud Function cleanup:
   - Daily job:
     - Query expired messages in batches.
     - Delete in batched writes.
     - Optional: write archive summary before delete.

### Suggested message fields
- `createdAt`
- `expiresAt` (set at write time: `createdAt + retentionWindow`)
- `chatId`
- `senderId`
- `text`

### Safe rollout checklist
1. Start with soft-delete (`deleted: true`) for 1-2 weeks if needed.
2. Verify no UI depends on old messages.
3. Enable hard-delete after validation.
4. Track deletion counts in logs.

## Operational Guardrails
1. Monthly review:
   - Top collections by reads/writes/storage.
   - Most expensive queries/listeners.
2. Per-release check:
   - Any new `.snapshots()` call must have bounded scope.
   - Any `.get()` on large collection must be justified.
3. Incident guardrail:
   - If daily cost spikes, temporarily disable high-cost admin features behind a flag.

## Trigger Points (When to apply next optimizations)
Use these practical thresholds:

1. Move to Stage 2 when any applies:
   - Daily active users > 100
   - Chat messages > 10,000 total
   - Admin dashboard opened > 100 times/day

2. Move to Stage 3 when any applies:
   - Monthly Firestore bill exceeds target by > 20%
   - Ops/admin team grows and dashboards are used continuously
   - Data volume causes noticeable latency in admin screens

## Quick Action Backlog (Prioritized)
1. Enable App Check.
2. Configure budget + anomaly alerts.
3. Implement chat pagination.
4. Implement chat retention/deletion (TTL or scheduled cleanup).
5. Add server-side counters for dashboard stats.

## Notes
- Keep functionality first, optimize in stages.
- Do not overbuild backend early if traffic is low.
- Revisit this document before each major growth phase.
