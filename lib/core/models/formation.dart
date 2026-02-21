class FormationSlot {
  const FormationSlot({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
  });

  final String id;
  final String label;
  final double x;
  final double y;
}

class FormationTemplate {
  const FormationTemplate({
    required this.id,
    required this.name,
    required this.slots,
  });

  final String id;
  final String name;
  final List<FormationSlot> slots;

  static final List<FormationTemplate> defaults = [
    FormationTemplate(
      id: '442',
      name: '4-4-2',
      slots: const [
        FormationSlot(id: '442-gk', label: 'GK', x: 0.50, y: 0.92),
        FormationSlot(id: '442-lb', label: 'LB', x: 0.18, y: 0.72),
        FormationSlot(id: '442-lcb', label: 'CB', x: 0.38, y: 0.72),
        FormationSlot(id: '442-rcb', label: 'CB', x: 0.62, y: 0.72),
        FormationSlot(id: '442-rb', label: 'RB', x: 0.82, y: 0.72),
        FormationSlot(id: '442-lm', label: 'LM', x: 0.18, y: 0.52),
        FormationSlot(id: '442-lcm', label: 'CM', x: 0.38, y: 0.52),
        FormationSlot(id: '442-rcm', label: 'CM', x: 0.62, y: 0.52),
        FormationSlot(id: '442-rm', label: 'RM', x: 0.82, y: 0.52),
        FormationSlot(id: '442-lst', label: 'ST', x: 0.40, y: 0.24),
        FormationSlot(id: '442-rst', label: 'ST', x: 0.60, y: 0.24),
      ],
    ),
    FormationTemplate(
      id: '433',
      name: '4-3-3',
      slots: const [
        FormationSlot(id: '433-gk', label: 'GK', x: 0.50, y: 0.92),
        FormationSlot(id: '433-lb', label: 'LB', x: 0.18, y: 0.72),
        FormationSlot(id: '433-lcb', label: 'CB', x: 0.38, y: 0.72),
        FormationSlot(id: '433-rcb', label: 'CB', x: 0.62, y: 0.72),
        FormationSlot(id: '433-rb', label: 'RB', x: 0.82, y: 0.72),
        FormationSlot(id: '433-lcm', label: 'CM', x: 0.30, y: 0.50),
        FormationSlot(id: '433-cdm', label: 'DM', x: 0.50, y: 0.56),
        FormationSlot(id: '433-rcm', label: 'CM', x: 0.70, y: 0.50),
        FormationSlot(id: '433-lw', label: 'LW', x: 0.22, y: 0.25),
        FormationSlot(id: '433-st', label: 'ST', x: 0.50, y: 0.20),
        FormationSlot(id: '433-rw', label: 'RW', x: 0.78, y: 0.25),
      ],
    ),
    FormationTemplate(
      id: '352',
      name: '3-5-2',
      slots: const [
        FormationSlot(id: '352-gk', label: 'GK', x: 0.50, y: 0.92),
        FormationSlot(id: '352-lcb', label: 'CB', x: 0.28, y: 0.72),
        FormationSlot(id: '352-cb', label: 'CB', x: 0.50, y: 0.75),
        FormationSlot(id: '352-rcb', label: 'CB', x: 0.72, y: 0.72),
        FormationSlot(id: '352-lwb', label: 'WB', x: 0.14, y: 0.54),
        FormationSlot(id: '352-lcm', label: 'CM', x: 0.36, y: 0.54),
        FormationSlot(id: '352-cdm', label: 'DM', x: 0.50, y: 0.60),
        FormationSlot(id: '352-rcm', label: 'CM', x: 0.64, y: 0.54),
        FormationSlot(id: '352-rwb', label: 'WB', x: 0.86, y: 0.54),
        FormationSlot(id: '352-lst', label: 'ST', x: 0.42, y: 0.25),
        FormationSlot(id: '352-rst', label: 'ST', x: 0.58, y: 0.25),
      ],
    ),
  ];

  static FormationTemplate findById(String id) {
    return defaults.firstWhere((formation) => formation.id == id);
  }
}
