// Technician schedule screen — month / week / day calendar over the
// technician's assigned jobs. Visual treatment is a Dart port of the
// design-system handoff (`design-bundle/.../Schedule.jsx`); the data layer
// is the existing `jobs` collection scoped to `assignedTechnicianId`.
//
// No new state machine values, no new Firestore fields. The schedule
// reads `scheduledTime` for placement and falls back to `assignedAt` /
// `createdAt` so urgent jobs (which write no `scheduledTime`) still show.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'job_status.dart';
import 'tech_home_screen.dart' show syanatBlue;
import 'technician_active_job_screen.dart';
import 'technician_approve_payment_screen.dart';
import 'technician_job_detail_readonly_screen.dart';
import 'technician_receipt_screen.dart';

/// View mode for the schedule.
enum _ScheduleMode { month, week, day }

/// Statuses that surface a job in the schedule view. `active` is excluded —
/// those jobs are still inbox-style assignments that the tech hasn't yet
/// committed to and belong on the Active Jobs list, not the calendar.
const Set<String> _scheduleStatuses = {
  JobStatus.technicianAccepted,
  JobStatus.onTheWay,
  JobStatus.technicianArrived,
  JobStatus.workFinished,
  JobStatus.awaitingCustomerApproval,
  JobStatus.awaitingPayment,
  JobStatus.awaitingPaymentVerification,
  JobStatus.receiptDisputed,
};

class TechnicianScheduleScreen extends StatefulWidget {
  const TechnicianScheduleScreen({super.key});

  @override
  State<TechnicianScheduleScreen> createState() =>
      _TechnicianScheduleScreenState();
}

class _TechnicianScheduleScreenState extends State<TechnicianScheduleScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _jobs = const [];
  bool _loading = true;
  Object? _error;

  _ScheduleMode _mode = _ScheduleMode.week;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'auth_not_ready';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _sub?.cancel();
    // Same shape as tech_home_screen's stream — we let the screen filter
    // locally by date so we can flip view modes without re-querying.
    _sub = FirebaseService.firestore
        .collection('jobs')
        .where('assignedTechnicianId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      final now = DateTime.now();
      final jobs = snap.docs
          .map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['id'] = d.id;
            return data;
          })
          // Schedule shows only jobs the tech has accepted. Jobs in `active`
          // (assigned but not yet acknowledged) live on the home Active Jobs
          // list — surfacing them here would make the calendar feel like an
          // inbox of unanswered assignments.
          .where((j) => _scheduleStatuses.contains(j['status']))
          // Same-day (and urgent / null-scheduled) accepted jobs live on
          // the home Active Jobs list. The Schedule view is only for the
          // future calendar — past days are kept for context, today is
          // routed elsewhere so the tech doesn't see the same job in two
          // places.
          .where((j) {
            final dynamic s = j['scheduledTime'];
            final DateTime? sch = s is Timestamp ? s.toDate() : null;
            return !isSameDay(sch, now);
          })
          .toList();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
        _error = null;
      });
    }, onError: (Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[Schedule] jobs stream error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    });
  }

  // ── Routing ──────────────────────────────────────────────────────────
  // Mirror of tech_home_screen._activeJobRouteFor so a tap on a schedule
  // tile lands on the same screen the home screen would land on. Kept
  // local rather than exported from tech_home to avoid widening that
  // file's public surface for one caller.
  void _openJob(Map<String, dynamic> job) {
    final status = (job['status'] as String?) ?? '';
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;
    final techId = user.uid;
    Widget? route;
    switch (status) {
      case 'active':
      case 'technician_accepted':
      case 'on_the_way':
      case 'technician_arrived':
        route = TechnicianActiveJobScreen(job: job, technicianId: techId);
        break;
      case 'work_finished':
        route = TechnicianReceiptScreen(
          jobId: (job['id'] as String?) ?? '',
          technicianId: techId,
          job: Map<String, dynamic>.from(job),
        );
        break;
      case 'awaiting_payment_verification':
        route = TechnicianApprovePaymentScreen(
          jobId: (job['id'] as String?) ?? '',
          technicianId: techId,
          job: Map<String, dynamic>.from(job),
        );
        break;
      default:
        route = TechnicianJobDetailReadonlyScreen(
          job: Map<String, dynamic>.from(job),
        );
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => route!));
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: syanatBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(isEn ? 'My Schedule' : 'الجدول'),
          actions: [
            IconButton(
              tooltip: isEn ? 'Today' : 'اليوم',
              onPressed: () {
                final now = DateTime.now();
                setState(() {
                  _selectedDate = DateTime(now.year, now.month, now.day);
                });
              },
              icon: const Icon(Icons.today_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: _buildBody(isEn),
        ),
      ),
    );
  }

  Widget _buildBody(bool isEn) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: syanatBlue));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(
                isEn ? 'Could not load schedule.' : 'تعذر تحميل الجدول.',
                style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _subscribe,
                icon: const Icon(Icons.refresh),
                label: Text(isEn ? 'Retry' : 'إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: syanatBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final byDate = _groupByDate(_jobs);
    final dayJobs = byDate[_dateKey(_selectedDate)] ?? const <Map<String, dynamic>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryHeader(dayJobs, isEn),
          const SizedBox(height: 12),
          _modeToggle(isEn),
          const SizedBox(height: 12),
          if (_mode == _ScheduleMode.month) ...[
            _MonthGrid(
              selectedDate: _selectedDate,
              jobsByDate: byDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 14),
            _agendaSectionHeader(dayJobs.length, isEn),
            const SizedBox(height: 8),
            _AgendaList(jobs: dayJobs, onTap: _openJob, isEn: isEn),
          ] else ...[
            _WeekStrip(
              selectedDate: _selectedDate,
              jobsByDate: byDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 14),
            if (_mode == _ScheduleMode.day)
              _DayTimeline(
                selectedDate: _selectedDate,
                jobs: dayJobs,
                onTap: _openJob,
                isEn: isEn,
              )
            else
              _AgendaList(jobs: dayJobs, onTap: _openJob, isEn: isEn),
          ],
        ],
      ),
    );
  }

  Widget _summaryHeader(List<Map<String, dynamic>> dayJobs, bool isEn) {
    final monthName = _monthName(_selectedDate.month, isEn);
    final dayName = _dayLongName(_selectedDate.weekday, isEn);
    final earnings = dayJobs
        .where((j) => j['status'] != 'cancelled')
        .fold<num>(0, (acc, j) => acc + jobDisplayPrice(j));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthName ${_selectedDate.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEn
                      ? '$dayName ${_selectedDate.day} · ${dayJobs.length} job${dayJobs.length == 1 ? '' : 's'}'
                      : '$dayName ${_selectedDate.day} · ${dayJobs.length} مهمة',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (dayJobs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1410B981),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${earnings.toStringAsFixed(0)} EGP',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeToggle(bool isEn) {
    final modes = <_ScheduleMode>[
      _ScheduleMode.month,
      _ScheduleMode.week,
      _ScheduleMode.day,
    ];
    String label(_ScheduleMode m) {
      switch (m) {
        case _ScheduleMode.month:
          return isEn ? 'Month' : 'شهر';
        case _ScheduleMode.week:
          return isEn ? 'Week' : 'أسبوع';
        case _ScheduleMode.day:
          return isEn ? 'Day' : 'يوم';
      }
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFEC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: modes.map((m) {
          final selected = m == _mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1)),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label(m),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? syanatBlue : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _agendaSectionHeader(int count, bool isEn) {
    final dayName = _dayLongName(_selectedDate.weekday, isEn);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        isEn
            ? '$dayName · $count job${count == 1 ? '' : 's'}'
            : '$dayName · $count مهمة',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date helpers
// ─────────────────────────────────────────────────────────────────────────────

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _jobDate(Map<String, dynamic> job) {
  // Prefer scheduledTime; fall back to assignedAt; then createdAt. Without
  // any of these, the job won't appear on the schedule (rare — orders.dart
  // always writes createdAt server-side).
  final dynamic s = job['scheduledTime'];
  if (s is Timestamp) return _atMidnight(s.toDate());
  final dynamic a = job['assignedAt'];
  if (a is Timestamp) return _atMidnight(a.toDate());
  final dynamic c = job['createdAt'];
  if (c is Timestamp) return _atMidnight(c.toDate());
  return null;
}

double _jobStartHour(Map<String, dynamic> job) {
  final dynamic s = job['scheduledTime'];
  if (s is Timestamp) {
    final dt = s.toDate();
    return dt.hour + dt.minute / 60.0;
  }
  // Urgent / now jobs — slot at the assigned time.
  final dynamic a = job['assignedAt'];
  if (a is Timestamp) {
    final dt = a.toDate();
    return dt.hour + dt.minute / 60.0;
  }
  return 9.0;
}

double _jobEndHour(Map<String, dynamic> job) {
  // No `durationMinutes` field on jobs today — render a default 2h block.
  final start = _jobStartHour(job);
  return (start + 2).clamp(0.0, 23.5);
}

Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> jobs) {
  final map = <String, List<Map<String, dynamic>>>{};
  for (final j in jobs) {
    final d = _jobDate(j);
    if (d == null) continue;
    final key = _dateKey(d);
    (map[key] ??= <Map<String, dynamic>>[]).add(j);
  }
  return map;
}

const List<String> _daysShortEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const List<String> _daysShortAr = ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];

String _dayShortName(int weekday, bool isEn) {
  // Dart's DateTime.weekday: Mon=1..Sun=7. Map to Sun=0..Sat=6 indexing.
  final idx = weekday % 7;
  return (isEn ? _daysShortEn : _daysShortAr)[idx];
}

const List<String> _daysLongEn = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];
const List<String> _daysLongAr = [
  'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
];

String _dayLongName(int weekday, bool isEn) {
  final idx = weekday % 7;
  return (isEn ? _daysLongEn : _daysLongAr)[idx];
}

const List<String> _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const List<String> _monthsAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String _monthName(int month, bool isEn) =>
    (isEn ? _monthsEn : _monthsAr)[month - 1];

String _formatHour(double h) {
  final hh = h.floor();
  final mm = ((h - hh) * 60).round();
  final ap = hh < 12 ? 'AM' : 'PM';
  final h12 = ((hh + 11) % 12) + 1;
  if (mm == 0) return '$h12 $ap';
  return '$h12:${mm.toString().padLeft(2, '0')} $ap';
}

String _formatRange(double start, double end) {
  String s(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }
  return '${s(start)}–${s(end)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Status palette — maps the canonical 12-state machine onto the design's
// 5-bucket color system. Kept in this file so the schedule UI is the only
// thing that needs to change if product later wants more nuance.
// ─────────────────────────────────────────────────────────────────────────────

class _StatusStyle {
  final Color fg;
  final Color bg;
  final Color dot;
  final IconData icon;
  const _StatusStyle({
    required this.fg,
    required this.bg,
    required this.dot,
    required this.icon,
  });
}

_StatusStyle _styleFor(String status) {
  switch (status) {
    case JobStatus.requested:
    case JobStatus.active:
      return const _StatusStyle(
        fg: Color(0xFF92400E),
        bg: Color(0x1AF59E0B),
        dot: Color(0xFFF59E0B),
        icon: Icons.hourglass_top,
      );
    case JobStatus.technicianAccepted:
      return const _StatusStyle(
        fg: Color(0xFF2A17A0),
        bg: Color(0x1A3C21C8),
        dot: syanatBlue,
        icon: Icons.thumb_up_alt_outlined,
      );
    case JobStatus.onTheWay:
      return const _StatusStyle(
        fg: Color(0xFF1D4ED8),
        bg: Color(0x1A3B82F6),
        dot: Color(0xFF3B82F6),
        icon: Icons.directions_car,
      );
    case JobStatus.technicianArrived:
      return const _StatusStyle(
        fg: Color(0xFF1D4ED8),
        bg: Color(0x1A3B82F6),
        dot: Color(0xFF3B82F6),
        icon: Icons.place,
      );
    case JobStatus.workFinished:
      return const _StatusStyle(
        fg: Color(0xFF5B21B6),
        bg: Color(0x1A8B5CF6),
        dot: Color(0xFF8B5CF6),
        icon: Icons.construction,
      );
    case JobStatus.awaitingCustomerApproval:
    case JobStatus.awaitingPayment:
    case JobStatus.awaitingPaymentVerification:
      return const _StatusStyle(
        fg: Color(0xFF6B21A8),
        bg: Color(0x1AA855F7),
        dot: Color(0xFFA855F7),
        icon: Icons.payments_outlined,
      );
    case JobStatus.completed:
      return const _StatusStyle(
        fg: Color(0xFF065F46),
        bg: Color(0x1A10B981),
        dot: Color(0xFF10B981),
        icon: Icons.check_circle_outline,
      );
    case JobStatus.cancelled:
      return const _StatusStyle(
        fg: Color(0xFF991B1B),
        bg: Color(0x1AEF4444),
        dot: Color(0xFFEF4444),
        icon: Icons.cancel_outlined,
      );
    case JobStatus.receiptDisputed:
      return const _StatusStyle(
        fg: Color(0xFF991B1B),
        bg: Color(0x1AEF4444),
        dot: Color(0xFFEF4444),
        icon: Icons.gavel,
      );
    default:
      return const _StatusStyle(
        fg: Colors.black54,
        bg: Color(0xFFEEEEEE),
        dot: Color(0xFF9E9E9E),
        icon: Icons.help_outline,
      );
  }
}

IconData _serviceIconFor(String? key) {
  switch ((key ?? '').toLowerCase()) {
    case 'plumbing':
      return Icons.plumbing;
    case 'ac':
    case 'ac_repair':
    case 'air_conditioning':
      return Icons.ac_unit;
    case 'electrical':
    case 'electrical_services':
      return Icons.electrical_services;
    case 'carpentry':
      return Icons.carpenter;
    case 'pest_control':
      return Icons.bug_report;
    case 'finishing':
    case 'paint':
    case 'painting':
      return Icons.format_paint;
    case 'appliance':
    case 'appliances':
      return Icons.kitchen;
    case 'aluminum':
      return Icons.meeting_room;
    default:
      return Icons.home_repair_service_outlined;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status pill — used by agenda card + day-timeline blocks.
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  final bool isEn;
  const _StatusPill({required this.status, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: s.dot,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            jobStatusTechLabel(status, isEn: isEn),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: s.fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week strip — 7-day picker centred on the selected date.
// ─────────────────────────────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  final DateTime selectedDate;
  final Map<String, List<Map<String, dynamic>>> jobsByDate;
  final ValueChanged<DateTime> onSelect;

  const _WeekStrip({
    required this.selectedDate,
    required this.jobsByDate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    // Build week containing `selectedDate`, starting Sunday (matches design).
    // Dart weekday: Mon=1..Sun=7. Sunday-aligned offset = weekday % 7.
    final offsetFromSunday = selectedDate.weekday % 7;
    final sunday = selectedDate.subtract(Duration(days: offsetFromSunday));
    final today = _atMidnight(DateTime.now());
    final week = List<DateTime>.generate(7, (i) => sunday.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: week.map((d) {
          final iso = _dateKey(d);
          final isSel = _dateKey(selectedDate) == iso;
          final isToday = _dateKey(today) == iso;
          final count = jobsByDate[iso]?.length ?? 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(d),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? syanatBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dayShortName(d.weekday, isEn),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSel
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSel
                            ? Colors.white
                            : (isToday ? syanatBlue : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (count > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(count > 3 ? 3 : count, (i) {
                          return Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: isSel ? Colors.white : syanatBlue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month grid — calendar with daily-load indicators.
// ─────────────────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final DateTime selectedDate;
  final Map<String, List<Map<String, dynamic>>> jobsByDate;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.selectedDate,
    required this.jobsByDate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final y = selectedDate.year, m = selectedDate.month;
    final first = DateTime(y, m, 1);
    final daysInMonth = DateTime(y, m + 1, 0).day;
    // Sunday-aligned start offset.
    final startOffset = first.weekday % 7;
    final today = _atMidnight(DateTime.now());

    final headerLabels = List<String>.generate(
      7,
      (i) => isEn ? _daysShortEn[i] : _daysShortAr[i],
    );

    final cells = <DateTime?>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(y, m, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: headerLabels
                  .map((s) => Expanded(
                        child: Text(
                          s.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, i) {
              final d = cells[i];
              if (d == null) return const SizedBox.shrink();
              final iso = _dateKey(d);
              final isSel = _dateKey(selectedDate) == iso;
              final isToday = _dateKey(today) == iso;
              final blocks = jobsByDate[iso] ?? const <Map<String, dynamic>>[];
              final hasReq = blocks.any((b) =>
                  b['status'] == JobStatus.requested ||
                  b['status'] == JobStatus.active);
              return GestureDetector(
                onTap: () => onSelect(d),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSel
                        ? syanatBlue
                        : isToday
                            ? const Color(0x143C21C8)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isSel || isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (blocks.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  blocks.length > 3 ? 3 : blocks.length,
                                  (i) => Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: isSel ? Colors.white : syanatBlue,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasReq && !isSel)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: SizedBox(
                            width: 6,
                            height: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day timeline — hour rows 8 AM–9 PM with absolute-positioned booking blocks.
// ─────────────────────────────────────────────────────────────────────────────

class _DayTimeline extends StatelessWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> jobs;
  final void Function(Map<String, dynamic>) onTap;
  final bool isEn;

  static const double _hourPx = 56;
  static const int _firstHour = 8;
  static const int _lastHour = 21; // 9 PM

  const _DayTimeline({
    required this.selectedDate,
    required this.jobs,
    required this.onTap,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return _emptyBlock(isEn);
    }
    final hours = List<int>.generate(_lastHour - _firstHour + 1, (i) => _firstHour + i);
    final today = _atMidnight(DateTime.now());
    final isToday = _dateKey(today) == _dateKey(selectedDate);
    final now = DateTime.now();
    final nowPx = isToday
        ? ((now.hour + now.minute / 60.0) - _firstHour) * _hourPx
        : null;

    // Greedy column assignment for overlaps. Match the design exactly:
    // walk blocks sorted by start; place in the leftmost column whose last
    // occupant ended before this block's start.
    final sorted = [...jobs]..sort(
        (a, b) => _jobStartHour(a).compareTo(_jobStartHour(b)));
    final cols = <Map<String, dynamic>>[]; // last block per column
    final placed = <_PlacedBlock>[];
    for (final j in sorted) {
      final start = _jobStartHour(j);
      final end = _jobEndHour(j);
      var col = 0;
      while (col < cols.length && _jobEndHour(cols[col]) > start) {
        col++;
      }
      if (col >= cols.length) {
        cols.add(j);
      } else {
        cols[col] = j;
      }
      placed.add(_PlacedBlock(job: j, col: col, start: start, end: end));
    }
    final totalCols = cols.isEmpty ? 1 : cols.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const railWidth = 54.0;
          const blocksLeft = railWidth + 12;
          final blocksWidth = constraints.maxWidth - blocksLeft - 12;
          return SizedBox(
            height: hours.length * _hourPx,
            child: Stack(
              children: [
                // Hour rail + row separators
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: hours.asMap().entries.map((e) {
                    final i = e.key;
                    final h = e.value;
                    return Container(
                      height: _hourPx,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: i == 0
                                ? Colors.transparent
                                : const Color(0xFFEEEEEE),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          _formatHour(h.toDouble()),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Now-line indicator
                if (nowPx != null && nowPx >= 0 && nowPx <= hours.length * _hourPx)
                  Positioned(
                    left: blocksLeft - 8,
                    right: 12,
                    top: nowPx - 1,
                    child: Container(
                      height: 2,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                if (nowPx != null && nowPx >= 0 && nowPx <= hours.length * _hourPx)
                  Positioned(
                    right: 12,
                    top: nowPx - 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: Colors.white,
                      child: Text(
                        isEn
                            ? 'NOW · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
                            : 'الآن · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                // Booking blocks
                ...placed.map((p) => _buildBlock(p, blocksLeft, blocksWidth, totalCols)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlock(
      _PlacedBlock p, double blocksLeft, double blocksWidth, int totalCols) {
    final s = _styleFor((p.job['status'] as String?) ?? '');
    final clampedStart = p.start.clamp(_firstHour.toDouble(), _lastHour.toDouble() + 1);
    final clampedEnd = p.end.clamp(clampedStart, _lastHour.toDouble() + 1);
    final top = (clampedStart - _firstHour) * _hourPx;
    final height = ((clampedEnd - clampedStart) * _hourPx - 6).clamp(28.0, double.infinity);
    final colWidth = blocksWidth / totalCols;
    final left = blocksLeft + (p.col * colWidth) + 2;
    final width = colWidth - 4;
    final isCancelled = p.job['status'] == JobStatus.cancelled;
    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height.toDouble(),
      child: GestureDetector(
        onTap: () => onTap(p.job),
        child: Opacity(
          opacity: isCancelled ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: s.bg,
              border: Border(
                top: BorderSide(color: s.dot),
                right: BorderSide(color: s.dot),
                bottom: BorderSide(color: s.dot),
                left: BorderSide(color: s.dot, width: 4),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _serviceIconFor(p.job['serviceKey'] as String?),
                      size: 14,
                      color: s.fg,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatRange(p.start, p.end),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: s.fg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    _blockTitle(p.job, isEn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (height > 60)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _blockSubtitle(p.job, isEn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyBlock(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available_outlined,
                size: 64, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 8),
            Text(
              isEn ? 'No jobs scheduled' : 'لا توجد مهام',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              isEn
                  ? 'Enjoy your day off — toggle availability on Home to take walk-ins.'
                  : 'يوم عطلة — فعّل التوفر من الصفحة الرئيسية لاستقبال طلبات.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacedBlock {
  final Map<String, dynamic> job;
  final int col;
  final double start;
  final double end;
  _PlacedBlock({
    required this.job,
    required this.col,
    required this.start,
    required this.end,
  });
}

String _blockTitle(Map<String, dynamic> job, bool isEn) {
  final cat = (job['serviceCategory'] as String?)?.trim();
  if (cat != null && cat.isNotEmpty) return cat;
  final key = (job['serviceKey'] as String?)?.trim();
  if (key != null && key.isNotEmpty) return key;
  return isEn ? 'Job' : 'مهمة';
}

String _blockSubtitle(Map<String, dynamic> job, bool isEn) {
  final cust = (job['customerName'] as String?)?.trim();
  final price = jobDisplayPrice(job);
  final priceLabel = price == 0 ? '—' : '${price.toStringAsFixed(0)} EGP';
  if (cust != null && cust.isNotEmpty) return '$cust · $priceLabel';
  return priceLabel;
}

// ─────────────────────────────────────────────────────────────────────────────
// Agenda list — chronological cards for the selected day.
// ─────────────────────────────────────────────────────────────────────────────

class _AgendaList extends StatelessWidget {
  final List<Map<String, dynamic>> jobs;
  final void Function(Map<String, dynamic>) onTap;
  final bool isEn;
  const _AgendaList({
    required this.jobs,
    required this.onTap,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available_outlined,
                  size: 64, color: Color(0xFFE0E0E0)),
              const SizedBox(height: 8),
              Text(
                isEn ? 'No jobs scheduled' : 'لا توجد مهام',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? 'New jobs assigned by admin will appear here.'
                    : 'ستظهر المهام المعينة هنا.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
        ),
      );
    }
    final sorted = [...jobs]
      ..sort((a, b) => _jobStartHour(a).compareTo(_jobStartHour(b)));
    return Column(
      children: sorted
          .map((j) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AgendaCard(job: j, onTap: () => onTap(j), isEn: isEn),
              ))
          .toList(),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final bool isEn;
  const _AgendaCard({
    required this.job,
    required this.onTap,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final status = (job['status'] as String?) ?? '';
    final start = _jobStartHour(job);
    final end = _jobEndHour(job);
    final address = ((job['locationAddress'] as String?)?.trim() ?? '');
    final price = jobDisplayPrice(job);
    final shortId = _shortId((job['id'] as String?) ?? '');
    final cust = (job['customerName'] as String?)?.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEEEEEE)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: const BoxDecoration(
                  color: Color(0x0D3C21C8),
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0x1F3C21C8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _serviceIconFor(job['serviceKey'] as String?),
                        size: 20,
                        color: syanatBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _blockTitle(job, isEn),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cust != null && cust.isNotEmpty
                                ? '#$shortId · $cust'
                                : '#$shortId',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: status, isEn: isEn),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      _formatRange(start, end),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.place_outlined,
                          size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Text(
                      price == 0 ? '—' : '${price.toStringAsFixed(0)} EGP',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortId(String id) {
  if (id.isEmpty) return '------';
  final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  return clean.length <= 6 ? clean : clean.substring(0, 6);
}
