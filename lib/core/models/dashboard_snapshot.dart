import 'customer.dart';
import 'visit.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.todaysVisits,
    required this.upcomingVisits,
    required this.overdueVisits,
    required this.newCustomers,
    required this.interestedCustomers,
    required this.totalCustomers,
    required this.neverVisited,
  });

  final int todaysVisits;
  final int upcomingVisits;
  final int overdueVisits;
  final int newCustomers;
  final int interestedCustomers;
  final int totalCustomers;
  final int neverVisited;

  factory DashboardSnapshot.fromData(
    List<Customer> customers,
    List<Visit> visits,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekAgo = now.subtract(const Duration(days: 7));

    return DashboardSnapshot(
      todaysVisits: visits.where((visit) {
        return !visit.scheduledAt.isBefore(today) &&
            visit.scheduledAt.isBefore(tomorrow);
      }).length,
      upcomingVisits:
          visits.where((visit) => visit.scheduledAt.isAfter(now)).length,
      overdueVisits: visits.where((visit) => visit.isOverdue).length,
      newCustomers: customers
          .where((customer) => customer.createdAt.isAfter(weekAgo))
          .length,
      interestedCustomers: customers
          .where((customer) => customer.status == CustomerStatus.interested)
          .length,
      totalCustomers:
          customers.where((customer) => !customer.isArchived).length,
      neverVisited: customers
          .where((customer) => customer.status == CustomerStatus.neverVisited)
          .length,
    );
  }
}
