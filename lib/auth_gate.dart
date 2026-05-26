// AuthGate — the one place that decides what screen the app opens on.
//
// Decision tree:
//   1. Auth stream hydrating                       → Splash
//   2. Auth error                                  → Splash (let it retry)
//   3a. Signed out, no pending edge-case message   → WelcomeScreen
//   3b. Signed out, pending edge-case message set  → LoginScreen
//   4. Signed in, profile snapshot hydrating       → Splash
//   5. Signed in, profile read error               → Splash (transient App Check /
//                                                     rules / network issues recover
//                                                     once the token or doc settles)
//   6. Signed in, profile doc missing-from-cache   → Splash (wait for server)
//   7. Signed in, profile incomplete               → force sign-out + queue
//                                                     LoginScreen snackbar
//   8. Signed in, profile complete + customer      → UserHomeScreen
//   9. Signed in, profile complete + technician    → TechHomeScreen
//  10. Signed in, profile complete + admin/other   → UnauthorizedScreen
//
// The legacy "Finish setting up your account" landing page (CompleteProfileScreen)
// was removed in 006-mobile-admin-cleanup. The previous design routed every
// half-signed-up user to that screen on cold start, which silently pulled
// users back into signup flow on every refresh. The new behavior instead
// signs the half-signed-up user out so they can re-enter through the
// canonical LoginScreen, which now surfaces a one-shot snackbar explaining
// what happened.
//
// The new-user signup (RoleSelectionScreen → OnboardingFlow) is reachable
// only from WelcomeScreen's "Create account" CTA and from LoginScreen's
// social-signin path for incomplete users — never from AuthGate as a
// landing page.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'tech_home_screen.dart';
import 'unauthorized_screen.dart';
import 'user_home_screen.dart';
import 'welcome_screen.dart';

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

        // (3) Signed out. By default → Welcome. But if AuthGate just kicked a
        // half-signed-up user out (case 7 below), route them straight to
        // LoginScreen so the queued snackbar surfaces immediately.
        if (user == null) {
          final bool hasPendingMsg =
              FirebaseService.pendingAuthSnackEn != null ||
                  FirebaseService.pendingAuthSnackAr != null;
          if (kDebugMode) {
            debugPrint(
              '[AuthGate] user=null '
              '${hasPendingMsg ? "(pending snack)" : ""} '
              '→ ${hasPendingMsg ? "LoginScreen" : "WelcomeScreen"}',
            );
          }
          return hasPendingMsg ? const LoginScreen() : const WelcomeScreen();
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

            // (7) Signed in but profile incomplete — half-signed-up account.
            // Force a sign-out so the user re-enters through LoginScreen.
            // The legacy "Finish setting up your account" screen used to live
            // here; it was removed because it silently re-entered signup flow
            // on every cold start.
            //
            // The presence of the queued message also acts as the idempotency
            // guard: subsequent rebuilds skip this branch's side effects
            // because the message is already set.
            if (!complete) {
              // Signup race guard: while OnboardingFlow is mid-flight
              // (between createUserWithEmailAndPassword and the
              // createUser Firestore write), the users/{uid} document is
              // legitimately missing. Without this short-circuit AuthGate
              // would force-sign-out the user and abort onboarding. The
              // flag is set/reset by OnboardingFlow with try/finally so it
              // cannot stay `true` past a thrown exception. Re-check
              // `complete` after the flag flips back to false — the doc
              // emission that follows the createUser write will route
              // home via case 8/9/10.
              if (FirebaseService.signupInProgress) {
                if (kDebugMode) {
                  debugPrint(
                    '[AuthGate] ${user.uid} profile incomplete but '
                    'signupInProgress=true → SplashScreen (no signOut)',
                  );
                }
                return const SplashScreen();
              }
              if (FirebaseService.pendingAuthSnackEn == null) {
                FirebaseService.pendingAuthSnackEn =
                    'Please sign in again to complete your account setup';
                FirebaseService.pendingAuthSnackAr =
                    'يرجى تسجيل الدخول مرة أخرى لإكمال إعداد الحساب';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FirebaseService.auth.signOut();
                });
                if (kDebugMode) {
                  debugPrint(
                    '[AuthGate] ${user.uid} profile incomplete '
                    '(exists=$exists, fromCache=$fromCache) '
                    '→ force sign-out + queued LoginScreen snackbar',
                  );
                }
              }
              return const SplashScreen();
            }

            // (8–10) Complete profile → route by role.
            final String role =
                ((data!['role'] as String?) ?? 'customer').trim();
            if (kDebugMode) {
              debugPrint(
                '[AuthGate] ${user.uid} profile complete, role=$role → home',
              );
            }
            if (role == 'customer') return const UserHomeScreen();
            if (role == 'technician') return const TechHomeScreen();
            return const UnauthorizedScreen();
          },
        );
      },
    );
  }
}
