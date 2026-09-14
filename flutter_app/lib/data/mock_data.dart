import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// Static UI configuration (NOT mock content).
///
/// Everything here is fixed app config — navigation tiles and the list of
/// supported payment methods. All user-facing content (student profile,
/// invoices, schedule, attendance, events, grading) is loaded live from the
/// API; there is no mock content in the app.

// Quick Access order and destinations from Expo v2.11.1.
const kQuickCards = <QuickCard>[
  QuickCard('attendance', 'Attendance', AppIcons.check_circle,
      Color(0xFF10B981), '/attendance'),
  QuickCard('classes', "Today's Classes", AppIcons.flash_on, Color(0xFFF59E0B),
      '/schedule'),
  QuickCard('trainer', 'My Trainer', AppIcons.account_circle, Color(0xFF8B5CF6),
      '/training'),
  QuickCard('timetable', 'Timetable', AppIcons.calendar_month,
      Color(0xFF0EA5E9), '/schedule'),
  QuickCard('fees', 'Fees Due', AppIcons.account_balance_wallet,
      Color(0xFFEF4444), '/payments'),
  QuickCard('payments', 'Payment History', AppIcons.receipt, Color(0xFF14B8A6),
      '/payments?tab=history'),
  QuickCard('progress', 'Progress Report', Icons.trending_up, Color(0xFF6366F1),
      '/progress'),
  QuickCard('belt', 'Belt / Rank', AppIcons.military_tech, Color(0xFFEAB308),
      '/progress'),
  QuickCard('events', 'Events', AppIcons.event, Color(0xFFF97316), '/events'),
  QuickCard('competition', 'Competition', AppIcons.military_tech,
      Color(0xFFDB2777), '/competition'),
  QuickCard('purchase', 'Purchase Request', AppIcons.shopping_bag,
      Color(0xFFF59E0B), '/purchase-request'),
  QuickCard('chat', 'Chat Academy', AppIcons.forum, Color(0xFF22C55E), '/chat'),
  QuickCard('more', 'More', AppIcons.grid_view, Color(0xFF64748B), '/more'),
];

// Supported payment methods shown in the pay sheet.
const kPayMethods = <PayMethod>[
  PayMethod(
      id: 'card', label: 'Credit / Debit Card', icon: AppIcons.credit_card),
  PayMethod(id: 'wallet', label: 'FPX / eWallet', icon: Icons.phone_iphone),
  PayMethod(id: 'bank', label: 'Bank Transfer', icon: Icons.account_balance),
];
