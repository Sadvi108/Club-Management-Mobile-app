import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/tabs_shell.dart';
import '../screens/home_screen.dart';
import '../screens/training_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/events_screen.dart';
import '../screens/qr_scan_screen.dart';
import '../screens/debug_screen.dart';
import '../screens/notification_detail_screen.dart';
import '../screens/outstanding_invoices_screen.dart';
import '../screens/instructor_tabs_shell.dart';
import '../screens/instructor_attendance_screen.dart';
import '../screens/instructor_home_screen.dart';
import '../screens/instructor_collections_screen.dart';
import '../screens/instructor_reports_screen.dart';
import '../screens/instructor_settings_screen.dart';
import '../screens/instructor_report_list_screen.dart';
import '../screens/instructor_reports/report_spec.dart';
import '../screens/instructor_reports/student_detail_screen.dart';
import '../services/api.dart';
import '../services/user_session.dart';

/// Bare report fetcher: a no-argument call returning the raw response.
typedef ReportFetcher = Future<dynamic> Function();

/// Fade-through page: the outgoing screen fades out as the incoming one
/// fades in and lifts slightly. Calmer than the default platform slide,
/// and consistent across Android / iOS / web.
CustomTransitionPage<void> _fadeThrough(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    child: child,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Quick cross-fade for bottom-nav tab switches. No slide: lateral motion
/// reads wrong when the tab bar itself doesn't move.
CustomTransitionPage<void> _tabFade(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

GoRoute _reportRoute(String path, String title, ReportFetcher fetcher) {
  final slug = path.split('/').last;
  final spec = kReportSpecs[slug] ??
      ReportSpec(title: title, fetch: (_) => fetcher());
  return GoRoute(
    path: path,
    pageBuilder: (_, state) => _fadeThrough(
      state.pageKey,
      InstructorReportListScreen(spec: spec),
    ),
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loc = state.matchedLocation;
    // /debug is always reachable (helpful for diagnosing data issues).
    if (loc == '/debug') return null;
    if (loc.startsWith('/instructor') && !UserSession.instance.isInstructor) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) =>
          TabsShell(child: child, location: state.matchedLocation),
      routes: [
        GoRoute(
            path: '/home',
            pageBuilder: (_, s) => _tabFade(s.pageKey, const HomeScreen())),
        GoRoute(
            path: '/schedule',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const ScheduleScreen())),
        GoRoute(
            path: '/progress',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const ProgressScreen())),
        GoRoute(
            path: '/profile',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const ProfileScreen())),
        // Reachable from quick-access tiles + home Pay Now / Today's Class.
        GoRoute(
            path: '/training',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const TrainingScreen())),
        GoRoute(
            path: '/payments',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const PaymentsScreen())),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => InstructorTabsShell(
        child: child,
        location: state.matchedLocation,
      ),
      routes: [
        GoRoute(
            path: '/instructor/home',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const InstructorHomeScreen())),
        GoRoute(
            path: '/instructor/collections',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const InstructorCollectionsScreen())),
        GoRoute(
            path: '/instructor/reports',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const InstructorReportsScreen())),
        GoRoute(
            path: '/instructor/settings',
            pageBuilder: (_, s) =>
                _tabFade(s.pageKey, const InstructorSettingsScreen())),
      ],
    ),
    // Drill-down report routes (outside the shell so they appear full-screen
    // with their own back button).
    _reportRoute('/instructor/reports/student-centers', 'Student Centers',
        Api.reportsStudentCenters),
    _reportRoute('/instructor/reports/training-centers', 'Training Centers',
        Api.reportsTrainingCenters),
    _reportRoute('/instructor/reports/exam-centers', 'Exam Centers',
        Api.reportsExamCenters),
    _reportRoute('/instructor/reports/student-list', 'Student List',
        Api.reportsStudentDetails),
    _reportRoute('/instructor/reports/training-time', 'Training Time',
        Api.listingTrainingCenters),
    _reportRoute('/instructor/reports/grading-schedule', 'Grading Schedule',
        Api.reportsGradingSchedule),
    _reportRoute('/instructor/reports/outstanding', 'Outstanding Report',
        Api.outstandingFetch),
    _reportRoute('/instructor/reports/attendance', 'Attendance Report',
        Api.reportsAttendance),
    _reportRoute('/instructor/reports/receipt', 'Receipt',
        Api.reportsReceipts),
    _reportRoute('/instructor/reports/grading-past', 'Grading Past',
        Api.reportsGradingSchedule),
    _reportRoute('/instructor/reports/purchase-request', 'Purchase Request',
        Api.reportsPurchaseRequests),
    _reportRoute('/instructor/reports/activity', 'Activities',
        Api.reportsActivity),
    _reportRoute('/instructor/reports/tournament', 'Tournament Schedule',
        Api.reportsTournamentSummary),
    _reportRoute('/instructor/reports/missing-invoice', 'Missing Invoice',
        Api.outstandingFetch),
    _reportRoute('/instructor/reports/fee-master', 'Fee Master',
        Api.listingInvoceTypes),
    _reportRoute('/instructor/reports/new-student', 'New Student',
        Api.reportsStudentDetails),
    _reportRoute('/instructor/reports/payment-slip', 'Payment Slip',
        Api.reportsPaymentSlips),
    _reportRoute('/instructor/reports/reimbursement', 'Reimbursement',
        Api.reportsReimbursement),
    GoRoute(
      path: '/instructor/student-detail',
      pageBuilder: (_, state) {
        final extra = state.extra;
        final student = extra is Map
            ? Map<String, dynamic>.from(extra)
            : <String, dynamic>{};
        return MaterialPage(
          key: state.pageKey,
          child: InstructorStudentDetailScreen(student: student),
        );
      },
    ),
    _reportRoute('/instructor/reports/contribution', 'Contribution',
        Api.reportsContribution),
    GoRoute(
        path: '/instructor/attendance',
        pageBuilder: (_, s) =>
            _fadeThrough(s.pageKey, const InstructorAttendanceScreen())),
    GoRoute(
      path: '/instructor/qr-scan',
      pageBuilder: (_, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const QRScanScreen(),
      ),
    ),
    GoRoute(
        path: '/invoices',
        pageBuilder: (_, s) =>
            _fadeThrough(s.pageKey, const OutstandingInvoicesScreen())),
    GoRoute(path: '/debug', builder: (_, __) => const DebugScreen()),
    GoRoute(
        path: '/attendance',
        pageBuilder: (_, s) =>
            _fadeThrough(s.pageKey, const AttendanceScreen())),
    GoRoute(
        path: '/events',
        pageBuilder: (_, s) => _fadeThrough(s.pageKey, const EventsScreen())),
    GoRoute(
      path: '/notification/:groupId',
      pageBuilder: (_, state) => _fadeThrough(
        state.pageKey,
        NotificationDetailScreen(
          groupId: state.pathParameters['groupId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/qr-scan',
      pageBuilder: (_, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const QRScanScreen(),
      ),
    ),
  ],
);
