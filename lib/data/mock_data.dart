import 'package:flutter/material.dart';
import '../models/models.dart';

/// Static UI configuration (NOT mock content).
///
/// Everything here is fixed app config — navigation tiles and the list of
/// supported payment methods. All user-facing content (student profile,
/// invoices, schedule, attendance, events, grading) is loaded live from the
/// API; there is no mock content in the app.

// Quick-access tiles on the home screen. One tile per destination — no
// duplicate routes, no dead-ends. Each maps to a real registered route.
const kQuickCards = <QuickCard>[
  QuickCard('attendance', 'Attendance', Icons.check_circle_outline, Color(0xFF10B981), '/attendance'),
  QuickCard('timetable', 'Timetable', Icons.calendar_month, Color(0xFF0EA5E9), '/schedule'),
  QuickCard('trainer', 'My Trainer', Icons.person, Color(0xFF8B5CF6), '/training'),
  QuickCard('payments', 'Payments', Icons.receipt_long, Color(0xFF14B8A6), '/payments'),
  QuickCard('progress', 'Progress', Icons.trending_up, Color(0xFF6366F1), '/progress'),
  QuickCard('events', 'Events', Icons.emoji_events, Color(0xFFF97316), '/events'),
];

// Supported payment methods shown in the pay sheet.
const kPayMethods = <PayMethod>[
  PayMethod(id: 'card', label: 'Credit / Debit Card', icon: Icons.credit_card),
  PayMethod(id: 'wallet', label: 'FPX / eWallet', icon: Icons.phone_iphone),
  PayMethod(id: 'bank', label: 'Bank Transfer', icon: Icons.account_balance),
];
