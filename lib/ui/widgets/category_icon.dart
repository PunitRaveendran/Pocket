import 'package:flutter/material.dart';

IconData categoryIcon(String key) {
  switch (key) {
    case 'food':
      return Icons.restaurant_outlined;
    case 'snacks':
      return Icons.local_cafe_outlined;
    case 'study':
      return Icons.menu_book_outlined;
    case 'misc':
      return Icons.more_horiz;
    case 'outing':
      return Icons.directions_walk_outlined;
    case 'travel':
    case 'commute':
      return Icons.directions_bus_outlined;
    case 'gym':
      return Icons.fitness_center_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'health':
      return Icons.medical_services_outlined;
    case 'tech':
      return Icons.devices_outlined;
    case 'income':
    case 'savings':
      return Icons.savings_outlined;
    default:
      return Icons.label_outline;
  }
}

const availableCategoryIcons = [
  ('custom', Icons.label_outline, 'General'),
  ('study', Icons.menu_book_outlined, 'Study'),
  ('food', Icons.restaurant_outlined, 'Food'),
  ('snacks', Icons.local_cafe_outlined, 'Snacks'),
  ('commute', Icons.directions_bus_outlined, 'Travel'),
  ('gym', Icons.fitness_center_outlined, 'Fitness'),
  ('shopping', Icons.shopping_bag_outlined, 'Shopping'),
  ('health', Icons.medical_services_outlined, 'Health'),
  ('tech', Icons.devices_outlined, 'Tech'),
];
