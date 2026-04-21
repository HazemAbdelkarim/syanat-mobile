// AuthGate — the one place that decides what screen the app opens on.
//
// Decision tree:
//   1. Auth stream hydrating                       → Splash
//   2. Auth error                                  → Splash (let it retry)
//   3. Signed out (user == null)                   → LoginScreen
//   4. Signed in, profile snapshot hydrating       → Splash
//   5. Signed in, profile read error               → Splash (transient App Check /
//                                                     rules / network issues recover
//                                                     once the token or doc settles)
//   6. Signed in, profile doc missing-from-cache   → Splash (wait for server)
//   7. Signed in, profile incomplete               → CompleteProfileScreen
//   8. Signed in, profile complete + admin role    → AdminRedirectScreen
//   9. Signed in, profile complete + technician    → TechHomeScreen
//  10. Signed in, profile complete + customer      → UserHomeScreen
//
// Never flashes Login or Signup during limbo. The new-user signup (Role
// Selection → Customer/Technician signup flow) is reachable ONLY from
// LoginScreen's "Create an account" link, never as a landing page for
// authenticated-but-incomplete users — those get the dedicated
// CompleteProfileScreen with a visible Log Out escape hatch.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'admin_redirect_screen.dart';
import 'complete_profile_screen.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'tech_home_screen.dart';
import 'user_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> authSnap) {
        // (1) Auth stream still hydrating — show splash. Never Login/Signup here.
        if (authSnap.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            debugPrint('[AuthGate] auth: waiting → SplashScreen');
          }
          return const SplashScreen();
        }

        // (2) Auth stream errored — keep splash; the stream is broadcast and
        // will recover. We never silently drop to Login on error (that would
        // log the user out by UX even if their session is fine).
        if (authSnap.hasError) {
          if (kDebugMode) {
            debugPrint('[AuthGate] auth error: ${authSnap.error} → SplashScreen');
          }
          return const SplashScreen();
        }

        final User? user = authSnap.data;

        // (3) Signed out → Login.
        if (user == null) {
          if (kDebugMode) {
            debugPrint('[AuthGate] user=null → LoginScreen');
          }
          return const LoginScreen();
        }

        // Signed in → stream the Firestore profile. Using snapshots() rather
        // than a one-shot get() means that a stale/empty first emission is
        // replaced live when the server reconciles; we never dead-end on a
        // cache miss.
        if (kDebugMode) {
          debugPrint(
            '[AuthGate] user=${user.uid} '
            '(${user.providerData.map((i) => i.providerId).toList()}) '
            '→ streaming users/${user.uid}',
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profSnap,
          ) {
            // (4) Profile stream hydrating.
            if (profSnap.connectionState == ConnectionState.waiting) {
              if (kDebugMode) {
                debugPrint('[AuthGate] profile: waiting → SplashScreen');
              }
              return const SplashScreen();
            }

            // (5) Transient read error — stay on splash. The snapshots stream
            // will retry automatically once App Check / rules / network
            // resolve. No silent fall-through to Login.
            if (profSnap.hasError) {
              if (kDebugMode) {
                debugPrint(
                  '[AuthGate] profile error: ${profSnap.error} → SplashScreen',
                );
              }
              return const SplashScreen();
            }

            final DocumentSnapshot<Map<String, dynamic>>? doc = profSnap.data;
            final SnapshotMetadata? meta = doc?.metadata;
            final bool fromCache = meta?.isFromCache ?? false;
            final bool exists = doc != null && doc.exists;

            // (6) First emission is a cache miss (`exists=false` + isFromCache)
            // on cold start. This happens for legitimately-registered users
            // whose users/{uid} doc just hasn't reached the local cache yet.
            // Stay on splash until the server snapshot arrives — do NOT route
            // to Signup on the strength of a cache-only answer.
            if (!exists && fromCache) {
              if (kDebugMode) {
                debugPrint(
                  '[AuthGate] profile: cache miss for ${user.uid}, '
                  'awaiting server → SplashScreen',
                );
              }
              return const SplashScreen();
            }

            final Map<String, dynamic>? data = exists ? doc.data() : null;
            final bool complete = FirebaseService.isProfileComplete(data);

            // (7) Signed in but no complete profile. Route to the dedicated
            // CompleteProfileScreen — NEVER to the new-user RoleSelectionScreen
            // as a landing page. CompleteProfileScreen carries a visible
            // Log Out action so the user is never dead-ended.
            if (!complete) {
              if (kDebugMode) {
                debugPrint(
                  '[AuthGate] ${user.uid} profile incomplete '
                  '(exists=$exists, fromCache=$fromCache) → CompleteProfileScreen',
                );
              }
              return CompleteProfileScreen(
                uid: user.uid,
                email: user.email ?? '',
                name: user.displayName ?? '',
              );
            }

            // (8–10) Complete profile → route by role.
            final String role =
                ((data!['role'] as String?) ?? 'customer').trim();
            if (kDebugMode) {
              debugPrint(
                '[AuthGate] ${user.uid} profile complete, role=$role → home',
              );
            }
            if (role == 'admin') return const AdminRedirectScreen();
            if (role == 'technician') return const TechHomeScreen();
            return const UserHomeScreen();
          },
        );
      },
    );
  }
}
