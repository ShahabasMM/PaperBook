import 'package:flutter/material.dart';

/// Automatic folder icon selection based on the folder name.
///
/// Matching is word-based and case-insensitive, so "Petrol bills", "petrol"
/// and "PETROL" all resolve to the same icon. Unknown names fall back to a
/// neutral folder icon.
abstract final class FolderIcons {
  static const _rules = <(Set<String>, IconData)>[
    (
      {'petrol', 'fuel', 'fuels', 'gas', 'diesel', 'gasoline', 'petroleum'},
      Icons.local_gas_station_outlined,
    ),
    (
      {'grocery', 'groceries', 'food', 'supermarket', 'market', 'produce'},
      Icons.shopping_basket_outlined,
    ),
    (
      {'shopping', 'clothes', 'clothing', 'fashion', 'mall', 'retail'},
      Icons.shopping_bag_outlined,
    ),
    (
      {'bill', 'bills', 'receipt', 'receipts', 'expense', 'expenses'},
      Icons.receipt_long_outlined,
    ),
    (
      {'electricity', 'electric', 'power', 'energy', 'utility', 'utilities'},
      Icons.bolt_outlined,
    ),
    ({'water', 'sewer'}, Icons.water_drop_outlined),
    ({'internet', 'wifi', 'broadband', 'network'}, Icons.wifi_rounded),
    ({'phone', 'mobile', 'sim', 'telecom'}, Icons.smartphone_rounded),
    (
      {'rent', 'home', 'house', 'mortgage', 'property', 'apartment'},
      Icons.home_work_outlined,
    ),
    (
      {'travel', 'flight', 'flights', 'airline', 'trip', 'holiday', 'vacation'},
      Icons.flight_takeoff_outlined,
    ),
    (
      {
        'health',
        'medical',
        'medicine',
        'doctor',
        'hospital',
        'pharmacy',
        'clinic',
      },
      Icons.health_and_safety_outlined,
    ),
    (
      {'insurance', 'policy', 'warranty', 'warranties', 'protection'},
      Icons.verified_user_outlined,
    ),
    (
      {'car', 'vehicle', 'auto', 'service', 'repair', 'maintenance'},
      Icons.directions_car_outlined,
    ),
    (
      {'school', 'education', 'tuition', 'university', 'college', 'course'},
      Icons.school_outlined,
    ),
    (
      {'restaurant', 'cafe', 'coffee', 'dining', 'meal'},
      Icons.restaurant_outlined,
    ),
    ({'pet', 'pets', 'vet', 'veterinary'}, Icons.pets_outlined),
    ({'gift', 'gifts', 'present'}, Icons.card_giftcard_outlined),
    (
      {'subscription', 'subscriptions', 'netflix', 'spotify', 'streaming'},
      Icons.subscriptions_outlined,
    ),
    (
      {'tax', 'taxes', 'bank', 'banking', 'finance', 'loan', 'credit'},
      Icons.account_balance_outlined,
    ),
    ({'work', 'office', 'salary', 'business'}, Icons.work_outline_rounded),
    ({'baby', 'kids', 'child', 'childcare'}, Icons.child_care_outlined),
    ({'gym', 'fitness', 'sports', 'training'}, Icons.fitness_center_outlined),
    ({'laundry', 'drycleaning'}, Icons.local_laundry_service_outlined),
  ];

  static IconData forName(String name) {
    final words = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toSet();

    for (final (keywords, icon) in _rules) {
      if (keywords.any(words.contains)) return icon;
    }
    return Icons.folder_outlined;
  }
}
