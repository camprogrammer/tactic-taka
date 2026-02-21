const List<String> kPreferredPositions = [
  'GK',
  'CB',
  'LB',
  'RB',
  'WB',
  'DM',
  'CM',
  'LM',
  'RM',
  'LW',
  'RW',
  'ST',
];

String normalizePosition(String value) {
  return value.trim().toUpperCase();
}

bool matchesPreferredForSlot(String preferredPosition, String slotLabel) {
  final preferred = normalizePosition(preferredPosition);
  final slot = normalizePosition(slotLabel);
  if (preferred == slot) {
    return true;
  }
  final map = <String, Set<String>>{
    'CB': {'LCB', 'RCB', 'CB'},
    'CM': {'LCM', 'RCM', 'CM'},
    'DM': {'CDM', 'DM'},
    'ST': {'LST', 'RST', 'ST'},
    'WB': {'LWB', 'RWB', 'WB'},
    'LM': {'LM', 'LW'},
    'RM': {'RM', 'RW'},
    'LW': {'LW', 'LM'},
    'RW': {'RW', 'RM'},
  };
  final allowed = map[preferred];
  if (allowed == null) {
    return false;
  }
  return allowed.contains(slot);
}
