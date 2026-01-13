class PartnerData {
  final String name;
  final int level;
  final String iconUrl;
  final String type; // BALANCE, etc.
  final int step;
  final int frag;
  final int overdrive;
  final String? skill; // The text description like "CHUNITHM - 通关需求：7"
  final bool isAwakened; // Maybe derived from visual cues, but not strictly asked.
  final bool isSelected; // Usually local state, but useful context.

  PartnerData({
    required this.name,
    required this.level,
    required this.iconUrl,
    required this.type,
    required this.step,
    required this.frag,
    required this.overdrive,
    this.skill,
    this.isAwakened = false,
    this.isSelected = false,
  });

  factory PartnerData.fromJson(Map<String, dynamic> json) {
    return PartnerData(
      name: json['name'] as String,
      level: json['level'] as int,
      iconUrl: json['iconUrl'] as String,
      type: json['type'] as String,
      step: json['step'] as int,
      frag: json['frag'] as int,
      overdrive: json['overdrive'] as int,
      skill: json['skill'] as String?,
      isAwakened: json['isAwakened'] as bool? ?? false,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      'iconUrl': iconUrl,
      'type': type,
      'step': step,
      'frag': frag,
      'overdrive': overdrive,
      'skill': skill,
      'isAwakened': isAwakened,
      'isSelected': isSelected,
    };
  }

  @override
  String toString() {
    return 'PartnerData(name: $name, level: $level, type: $type, step: $step)';
  }
}
