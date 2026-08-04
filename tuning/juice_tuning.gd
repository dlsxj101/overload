class_name JuiceTuning
extends Resource

const PARAMETER_SPECS := [
	{"key": "hitstop_duration", "label": "히트스톱", "min": 0.0, "max": 0.15, "step": 0.005, "integer": false},
	{"key": "windup_time", "label": "준비동작", "min": 0.05, "max": 0.35, "step": 0.005, "integer": false},
	{"key": "swing_time", "label": "휘두르기", "min": 0.02, "max": 0.12, "step": 0.005, "integer": false},
	{"key": "flash_frames", "label": "흰색 플래시", "min": 1.0, "max": 8.0, "step": 1.0, "integer": true},
	{"key": "knockback_distance", "label": "넉백 거리", "min": 0.0, "max": 80.0, "step": 1.0, "integer": false},
	{"key": "knockback_decay", "label": "넉백 감속", "min": 0.03, "max": 0.4, "step": 0.005, "integer": false},
	{"key": "shake_distance", "label": "화면 밀림", "min": 0.0, "max": 25.0, "step": 0.5, "integer": false},
	{"key": "shake_return_time", "label": "화면 복귀", "min": 0.03, "max": 0.4, "step": 0.005, "integer": false},
	{"key": "sword_arc_degrees", "label": "칼 궤적 각도", "min": 45.0, "max": 180.0, "step": 1.0, "integer": false},
	{"key": "sword_reach", "label": "칼 사거리", "min": 25.0, "max": 90.0, "step": 1.0, "integer": false},
	{"key": "attack_cooldown", "label": "공격 쿨다운", "min": 0.04, "max": 0.35, "step": 0.005, "integer": false},
]

@export_range(0.0, 0.15, 0.005) var hitstop_duration := 0.05
@export_range(0.05, 0.35, 0.005) var windup_time := 0.15
@export_range(0.02, 0.12, 0.005) var swing_time := 0.04
@export_range(1, 8, 1) var flash_frames := 3
@export_range(0.0, 80.0, 1.0) var knockback_distance := 21.6
@export_range(0.03, 0.4, 0.005) var knockback_decay := 0.12
@export_range(0.0, 25.0, 0.5) var shake_distance := 5.4
@export_range(0.03, 0.4, 0.005) var shake_return_time := 0.1
@export_range(45.0, 180.0, 1.0) var sword_arc_degrees := 110.0
@export_range(25.0, 90.0, 1.0) var sword_reach := 44.0
@export_range(0.04, 0.35, 0.005) var attack_cooldown := 0.12


func copy_from(source: Resource) -> void:
	for spec: Dictionary in PARAMETER_SPECS:
		var key: String = spec["key"]
		set(key, source.get(key))
	emit_changed()


func make_snapshot() -> JuiceTuning:
	var snapshot := JuiceTuning.new()
	snapshot.copy_from(self)
	return snapshot


func values_text() -> String:
	var lines := PackedStringArray()
	for spec: Dictionary in PARAMETER_SPECS:
		var key: String = spec["key"]
		lines.append("%s = %s" % [key, str(get(key))])
	return "\n".join(lines)
