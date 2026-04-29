import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_projects/job_status.dart';

void main() {
  group('job state machine', () {
    group('technician flow (happy path)', () {
      test('active → technician_accepted', () {
        expect(
          isValidJobTransition(
            from: JobStatus.active,
            to: JobStatus.technicianAccepted,
            actor: JobActor.technician,
          ),
          isTrue,
        );
      });

      test('technician_accepted → on_the_way (release 006)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.technicianAccepted,
            to: JobStatus.onTheWay,
            actor: JobActor.technician,
          ),
          isTrue,
        );
      });

      test('on_the_way → technician_arrived (release 006)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.onTheWay,
            to: JobStatus.technicianArrived,
            actor: JobActor.technician,
          ),
          isTrue,
        );
      });

      test('technician_arrived → work_finished', () {
        expect(
          isValidJobTransition(
            from: JobStatus.technicianArrived,
            to: JobStatus.workFinished,
            actor: JobActor.technician,
          ),
          isTrue,
        );
      });

      test('work_finished → awaiting_customer_approval (submit receipt)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.workFinished,
            to: JobStatus.awaitingCustomerApproval,
            actor: JobActor.technician,
          ),
          isTrue,
        );
      });

      test('awaiting_payment_verification → completed (tech verifies proof)',
          () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingPaymentVerification,
            to: JobStatus.completed,
            actor: JobActor.technician,
          ),
          isTrue,
          reason:
              'Tech completes the job by uploading payment proof — this is '
              'one of only two paths to status=completed (see SECURITY '
              'INVARIANT in firestore.rules).',
        );
      });
    });

    group('customer flow', () {
      test(
          'awaiting_customer_approval → awaiting_payment '
          '(approve receipt, release 006)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingCustomerApproval,
            to: JobStatus.awaitingPayment,
            actor: JobActor.customer,
          ),
          isTrue,
          reason:
              'Approving the receipt no longer completes the job — the '
              'customer still has to pay and the tech still has to verify.',
        );
      });

      test(
          'awaiting_payment → awaiting_payment_verification '
          '(mark paid, release 006)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingPayment,
            to: JobStatus.awaitingPaymentVerification,
            actor: JobActor.customer,
          ),
          isTrue,
        );
      });

      test('awaiting_customer_approval → receipt_disputed (reject)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingCustomerApproval,
            to: JobStatus.receiptDisputed,
            actor: JobActor.customer,
          ),
          isTrue,
        );
      });
    });

    group('release-006 backdoors are closed', () {
      test('technician cannot jump work_finished → completed', () {
        expect(
          isValidJobTransition(
            from: JobStatus.workFinished,
            to: JobStatus.completed,
            actor: JobActor.technician,
          ),
          isFalse,
          reason:
              'Completion is reachable only from awaiting_payment_verification '
              '(tech + photo proof) or receipt_disputed (admin).',
        );
      });

      test('technician cannot jump technician_arrived → completed', () {
        expect(
          isValidJobTransition(
            from: JobStatus.technicianArrived,
            to: JobStatus.completed,
            actor: JobActor.technician,
          ),
          isFalse,
        );
      });

      test('technician cannot skip on_the_way (accepted → arrived)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.technicianAccepted,
            to: JobStatus.technicianArrived,
            actor: JobActor.technician,
          ),
          isFalse,
          reason:
              'Release-006 requires on_the_way between accepted and arrived.',
        );
      });

      test('customer cannot jump awaiting_customer_approval → completed', () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingCustomerApproval,
            to: JobStatus.completed,
            actor: JobActor.customer,
          ),
          isFalse,
          reason:
              'Customer can no longer mark the job complete directly — '
              'they approve the receipt (→ awaiting_payment), then mark paid '
              '(→ awaiting_payment_verification), then the tech verifies.',
        );
      });

      test('customer cannot jump awaiting_payment → completed', () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingPayment,
            to: JobStatus.completed,
            actor: JobActor.customer,
          ),
          isFalse,
        );
      });

      test(
          'customer cannot verify payment '
          '(awaiting_payment_verification → completed)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingPaymentVerification,
            to: JobStatus.completed,
            actor: JobActor.customer,
          ),
          isFalse,
          reason: 'Only the tech (with proof) may close out the verification.',
        );
      });

      test('customer cannot jump work_finished → completed (skip receipt)',
          () {
        expect(
          isValidJobTransition(
            from: JobStatus.workFinished,
            to: JobStatus.completed,
            actor: JobActor.customer,
          ),
          isFalse,
        );
      });

      test('technician cannot perform customer approve (awaiting_customer_approval → awaiting_payment)',
          () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingCustomerApproval,
            to: JobStatus.awaitingPayment,
            actor: JobActor.technician,
          ),
          isFalse,
          reason: 'Only the customer approves their own receipt.',
        );
      });

      test('technician cannot mark payment initiated for the customer', () {
        expect(
          isValidJobTransition(
            from: JobStatus.awaitingPayment,
            to: JobStatus.awaitingPaymentVerification,
            actor: JobActor.technician,
          ),
          isFalse,
        );
      });

      test('customer cannot cancel once tech has accepted', () {
        expect(
          isValidJobTransition(
            from: JobStatus.technicianAccepted,
            to: JobStatus.cancelled,
            actor: JobActor.customer,
          ),
          isFalse,
        );
      });

      test('customer cannot cancel once tech is on the way', () {
        expect(
          isValidJobTransition(
            from: JobStatus.onTheWay,
            to: JobStatus.cancelled,
            actor: JobActor.customer,
          ),
          isFalse,
        );
      });

      test(
          'technician CAN cancel from active (no penalty) and from '
          'technician_accepted (penalty applies)', () {
        expect(
          isValidJobTransition(
            from: JobStatus.active,
            to: JobStatus.cancelled,
            actor: JobActor.technician,
          ),
          isTrue,
          reason:
              'Pre-acceptance tech-cancel is allowed by firestore.rules and '
              'cancelJobByTech writes cancellationPenalty=0 / escalateForReview=false.',
        );
        expect(
          isValidJobTransition(
            from: JobStatus.technicianAccepted,
            to: JobStatus.cancelled,
            actor: JobActor.technician,
          ),
          isTrue,
          reason:
              'Post-acceptance tech-cancel is now allowed; cancelJobByTech '
              'computes the penalty via calculateCancellationPenalty and '
              'flags late cancels for review.',
        );
      });

      test('terminal states are sinks — no transitions out of completed', () {
        for (final actor in JobActor.values) {
          for (final target in const [
            JobStatus.active,
            JobStatus.cancelled,
            JobStatus.workFinished,
            JobStatus.awaitingPayment,
          ]) {
            expect(
              isValidJobTransition(
                from: JobStatus.completed,
                to: target,
                actor: actor,
              ),
              isFalse,
              reason:
                  'completed → $target should be denied for ${actor.name}',
            );
          }
        }
      });

      test('terminal states are sinks — no transitions out of cancelled', () {
        for (final actor in JobActor.values) {
          for (final target in const [
            JobStatus.active,
            JobStatus.completed,
            JobStatus.workFinished,
            JobStatus.awaitingPaymentVerification,
          ]) {
            expect(
              isValidJobTransition(
                from: JobStatus.cancelled,
                to: target,
                actor: actor,
              ),
              isFalse,
              reason:
                  'cancelled → $target should be denied for ${actor.name}',
            );
          }
        }
      });
    });

    group('admin flow', () {
      test('admin assigns: requested → active', () {
        expect(
          isValidJobTransition(
            from: JobStatus.requested,
            to: JobStatus.active,
            actor: JobActor.admin,
          ),
          isTrue,
        );
      });

      test('admin resolves dispute: receipt_disputed → completed', () {
        expect(
          isValidJobTransition(
            from: JobStatus.receiptDisputed,
            to: JobStatus.completed,
            actor: JobActor.admin,
          ),
          isTrue,
        );
      });

      test('admin can cancel from any non-terminal state', () {
        for (final from in const [
          JobStatus.requested,
          JobStatus.active,
          JobStatus.technicianAccepted,
          JobStatus.onTheWay,
          JobStatus.technicianArrived,
          JobStatus.workFinished,
          JobStatus.awaitingCustomerApproval,
          JobStatus.awaitingPayment,
          JobStatus.awaitingPaymentVerification,
        ]) {
          expect(
            isValidJobTransition(
              from: from,
              to: JobStatus.cancelled,
              actor: JobActor.admin,
            ),
            isTrue,
            reason: 'admin should be able to cancel from $from',
          );
        }
      });
    });
  });
}
