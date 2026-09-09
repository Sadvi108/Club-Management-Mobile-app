import 'package:flutter/material.dart';

class Student {
  final String id, name, membership, belt, level, joinDate, photo, phone, email;
  final int attendance, fitness;
  final Parent parent;
  final NextPayment nextPayment;
  final Color beltColor;

  const Student({
    required this.id,
    required this.name,
    required this.membership,
    required this.belt,
    required this.beltColor,
    required this.level,
    required this.joinDate,
    required this.photo,
    required this.phone,
    required this.email,
    required this.parent,
    required this.attendance,
    required this.fitness,
    required this.nextPayment,
  });
}

class Parent {
  final String name, phone, relation;
  const Parent({required this.name, required this.phone, required this.relation});
}

class NextPayment {
  final int amount;
  final String dueDate, label;
  const NextPayment({required this.amount, required this.dueDate, required this.label});
}

class QuickCard {
  final String id, label, route;
  final IconData icon;
  final Color color;
  const QuickCard(this.id, this.label, this.icon, this.color, this.route);
}

class Program {
  final String id, sport, level, trainer, nextMilestone, image;
  final int progress;
  final Color color;
  const Program({
    required this.id,
    required this.sport,
    required this.level,
    required this.trainer,
    required this.progress,
    required this.nextMilestone,
    required this.image,
    required this.color,
  });
}

class Session {
  final String time, title, trainer, duration;
  final Color color;
  const Session({
    required this.time,
    required this.title,
    required this.trainer,
    required this.duration,
    required this.color,
  });
}

class DaySchedule {
  final String day, date;
  final List<Session> sessions;
  const DaySchedule({required this.day, required this.date, required this.sessions});
}

class PaymentRow {
  final String id, label, date, method;
  final int amount;
  const PaymentRow({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    required this.method,
  });
}

class EventItem {
  final String id, title, date, location, category, image;
  final int countdown;
  final bool registered;
  const EventItem({
    required this.id,
    required this.title,
    required this.date,
    required this.countdown,
    required this.location,
    required this.category,
    required this.image,
    required this.registered,
  });
}

class Certificate {
  final String id, title, date, issuer;
  const Certificate({required this.id, required this.title, required this.date, required this.issuer});
}

class Skill {
  final String name;
  final int value;
  final Color color;
  const Skill({required this.name, required this.value, required this.color});
}

class Achievement {
  final String id, title;
  final IconData icon;
  final Color color;
  const Achievement({required this.id, required this.title, required this.icon, required this.color});
}

class TrainerComment {
  final String trainer, comment, date;
  const TrainerComment({required this.trainer, required this.comment, required this.date});
}

enum AttendanceStatus { present, missed, off, future }

class AttendanceDay {
  final int day;
  final AttendanceStatus status;
  const AttendanceDay({required this.day, required this.status});
}

class MissedClass {
  final String date, className, reason;
  const MissedClass({required this.date, required this.className, required this.reason});
}

class Holiday {
  final String date, name;
  const Holiday({required this.date, required this.name});
}

class PayMethod {
  final String id, label;
  final IconData icon;
  const PayMethod({required this.id, required this.label, required this.icon});
}

class BeltStage {
  final String name;
  final Color color;
  final bool done;
  final bool current;
  const BeltStage({required this.name, required this.color, required this.done, this.current = false});
}
