import 'dart:async';

import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'technician_payment_screen.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class TechnicianActiveJobScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final String technicianId;

  const TechnicianActiveJobScreen({
    super.key,
    required this.job,
    required this.technicianId,
  });

  @override
  State<TechnicianActiveJobScreen> createState() =>
      _TechnicianActiveJobScreenState();
}

class _TechnicianActiveJobScreenState extends State<TechnicianActiveJobScreen> {
  bool _loading = false;

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  Future<void> _markArrived() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _loading = true);
    try {
      await FirebaseService.markArrived(
        widget.job['id'] as String? ?? '',
        widget.technicianId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Error: $e' : 'خطأ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markComplete() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _loading = true);
    try {
      await FirebaseService.markJobComplete(
        widget.job['id'] as String? ?? '',
        widget.technicianId,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TechnicianPaymentScreen(
            jobId: widget.job['id'] as String? ?? '',
            technicianId: widget.technicianId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Error: $e' : 'خطأ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final status = widget.job['status'] as String? ?? '';
    final serviceCategory = (widget.job['serviceCategory'] as String?)?.trim();
    final serviceKey = (widget.job['serviceKey'] as String?)?.trim() ?? '';
    final address = (widget.job['locationAddress'] as String?)?.trim() ?? '';
    final paymentAmount =
        (widget.job['technicianPaymentAmount'] as num?)?.toDouble();

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          foregroundColor: Colors.white,
          title: Text(
            serviceCategory?.isNotEmpty == true
                ? serviceCategory!
                : serviceKey,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _addressCard(address, isEn),
              const SizedBox(height: 20),
              if (status == 'accepted')
                _SlideToConfirmBar(
                  label: _t(
                    isEn,
                    'Slide to confirm arrival',
                    'اسحب لتأكيد الوصول',
                  ),
                  onConfirmed: _loading ? () async {} : _markArrived,
                  enabled: !_loading,
                )
              else if (status == 'en_route')
                _SlideToConfirmBar(
                  label: _t(
                    isEn,
                    'Slide to mark job complete',
                    'اسحب لإتمام العمل',
                  ),
                  onConfirmed: _loading ? () async {} : _markComplete,
                  enabled: !_loading,
                )
              else if (status == 'payment_pending')
                _waitingCard(isEn, paymentAmount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressCard(String address, bool isEn) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x143C21C8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on, color: _syanatBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Service Address' : 'عنوان الخدمة',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  address.isEmpty
                      ? (isEn ? 'Address unavailable' : 'العنوان غير متاح')
                      : address,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingCard(bool isEn, double? paymentAmount) {
    final amountText = paymentAmount == null
        ? ''
        : ' ${paymentAmount.toStringAsFixed(2)} EGP';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _syanatBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isEn
                  ? 'Waiting for customer to confirm payment$amountText.'
                  : 'في انتظار تأكيد العميل للدفع$amountText.',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideToConfirmBar extends StatefulWidget {
  final String label;
  final Future<void> Function() onConfirmed;
  final bool enabled;

  const _SlideToConfirmBar({
    required this.label,
    required this.onConfirmed,
    required this.enabled,
  });

  @override
  State<_SlideToConfirmBar> createState() => _SlideToConfirmBarState();
}

class _SlideToConfirmBarState extends State<_SlideToConfirmBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _resetAnimation;
  double _progress = 0;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_resetAnimation != null) {
          setState(() => _progress = _resetAnimation!.value);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    double maxTravel,
    bool isRtl,
  ) {
    if (!widget.enabled || _confirmed) return;
    _controller.stop();
    final delta = isRtl
        ? -(details.primaryDelta ?? 0)
        : (details.primaryDelta ?? 0);
    final next = (_progress * maxTravel + delta).clamp(0.0, maxTravel);
    final progress = maxTravel == 0 ? 0.0 : next / maxTravel;

    if (progress >= 1.0) {
      setState(() {
        _progress = 1.0;
        _confirmed = true;
      });
      unawaited(widget.onConfirmed().catchError((_) {
        if (mounted) {
          setState(() {
            _confirmed = false;
            _progress = 0.0;
          });
        }
      }));
      return;
    }

    setState(() => _progress = progress);
  }

  void _handleDragEnd() {
    if (!widget.enabled || _confirmed || _progress >= 1.0) return;
    _resetAnimation = Tween<double>(
      begin: _progress,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 56.0;
        final maxTravel = (constraints.maxWidth - thumbSize - 8)
            .clamp(0.0, double.infinity)
            .toDouble();
        final thumbLeft = 4 + (maxTravel * _progress);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final isRtl = Directionality.of(context) == TextDirection.rtl;
            _handleDragUpdate(details, maxTravel, isRtl);
          },
          onHorizontalDragEnd: (_) => _handleDragEnd(),
          onHorizontalDragCancel: _handleDragEnd,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: _syanatBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _syanatBlue,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: isRtl ? null : thumbLeft,
                  right: isRtl ? thumbLeft : null,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed ? Icons.check : Icons.arrow_forward,
                      color: _syanatBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
