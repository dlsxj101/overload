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
	{"key": "combo_grace_time", "label": "콤보 유지", "min": 0.0, "max": 5.0, "step": 0.1, "integer": false},
	{"key": "combo_decay_per_second", "label": "콤보 초당 감소", "min": 1.0, "max": 20.0, "step": 0.5, "integer": false},
	{"key": "tier_1_threshold", "label": "티어1 기준", "min": 1.0, "max": 200.0, "step": 1.0, "integer": true},
	{"key": "tier_2_threshold", "label": "티어2 기준", "min": 1.0, "max": 200.0, "step": 1.0, "integer": true},
	{"key": "tier_3_threshold", "label": "티어3 기준", "min": 1.0, "max": 200.0, "step": 1.0, "integer": true},
	{"key": "tier_4_threshold", "label": "티어4 기준", "min": 1.0, "max": 200.0, "step": 1.0, "integer": true},
	{"key": "tier_0_sword_scale", "label": "티어0 칼 배율", "min": 0.5, "max": 4.0, "step": 0.05, "integer": false},
	{"key": "tier_1_sword_scale", "label": "티어1 칼 배율", "min": 0.5, "max": 4.0, "step": 0.05, "integer": false},
	{"key": "tier_2_sword_scale", "label": "티어2 칼 배율", "min": 0.5, "max": 4.0, "step": 0.05, "integer": false},
	{"key": "tier_3_sword_scale", "label": "티어3 칼 배율", "min": 0.5, "max": 4.0, "step": 0.05, "integer": false},
	{"key": "tier_4_sword_scale", "label": "티어4 칼 배율", "min": 0.5, "max": 4.0, "step": 0.05, "integer": false},
	{"key": "tier_1_hitstop", "label": "티어1 히트스톱", "min": 0.0, "max": 0.15, "step": 0.005, "integer": false},
	{"key": "tier_2_hitstop", "label": "티어2 히트스톱", "min": 0.0, "max": 0.15, "step": 0.005, "integer": false},
	{"key": "tier_3_hitstop", "label": "티어3 히트스톱", "min": 0.0, "max": 0.15, "step": 0.005, "integer": false},
	{"key": "tier_4_hitstop", "label": "티어4 히트스톱", "min": 0.0, "max": 0.15, "step": 0.005, "integer": false},
	{"key": "tier_transition_duration", "label": "티어 전환 시간", "min": 0.05, "max": 0.2, "step": 0.005, "integer": false},
	{"key": "combo_font_size", "label": "콤보 숫자 크기", "min": 64.0, "max": 220.0, "step": 1.0, "integer": true},
	{"key": "combo_opacity", "label": "콤보 투명도", "min": 0.03, "max": 0.4, "step": 0.01, "integer": false},
	{"key": "combo_pulse_scale", "label": "콤보 확대 배율", "min": 1.0, "max": 2.0, "step": 0.05, "integer": false},
	{"key": "tier_flash_opacity", "label": "티어 화면 플래시", "min": 0.0, "max": 0.8, "step": 0.01, "integer": false},
	{"key": "blade_glow_width", "label": "칼날 발광 폭", "min": 6.0, "max": 32.0, "step": 1.0, "integer": false},
	{"key": "blade_glow_opacity", "label": "칼날 발광 농도", "min": 0.0, "max": 1.0, "step": 0.01, "integer": false},
	{"key": "afterimage_lifetime", "label": "잔상 유지", "min": 0.04, "max": 0.3, "step": 0.01, "integer": false},
	{"key": "afterimage_max_count", "label": "잔상 최대 수", "min": 1.0, "max": 24.0, "step": 1.0, "integer": true},
	{"key": "afterimage_opacity", "label": "잔상 농도", "min": 0.0, "max": 0.8, "step": 0.01, "integer": false},
	{"key": "electric_bolt_count", "label": "전류 스파크 수", "min": 1.0, "max": 12.0, "step": 1.0, "integer": true},
	{"key": "electric_bolt_length", "label": "전류 스파크 길이", "min": 10.0, "max": 80.0, "step": 1.0, "integer": false},
	{"key": "electric_bolt_lifetime", "label": "전류 유지", "min": 0.04, "max": 0.3, "step": 0.01, "integer": false},
	{"key": "electric_bolt_width", "label": "전류 굵기", "min": 1.0, "max": 6.0, "step": 0.5, "integer": false},
	{"key": "electric_bolt_jitter", "label": "전류 굴곡", "min": 0.0, "max": 24.0, "step": 1.0, "integer": false},
	{"key": "tier_4_saturation", "label": "티어4 채도", "min": 1.0, "max": 2.0, "step": 0.05, "integer": false},
	{"key": "blade_volume_db", "label": "칼날음 볼륨", "min": -18.0, "max": 3.0, "step": 0.5, "integer": false},
	{"key": "tail_volume_db", "label": "꼬리음 볼륨", "min": -18.0, "max": 3.0, "step": 0.5, "integer": false},
	{"key": "tier_0_body_volume_db", "label": "티어0 저역 볼륨", "min": -18.0, "max": 3.0, "step": 0.5, "integer": false},
	{"key": "tier_1_body_volume_db", "label": "티어1 저역 볼륨", "min": -18.0, "max": 3.0, "step": 0.5, "integer": false},
	{"key": "tier_2_body_volume_db", "label": "티어2 저역 볼륨", "min": -18.0, "max": 3.0, "step": 0.5, "integer": false},
	{"key": "tier_3_body_volume_db", "label": "티어3 저역 볼륨", "min": -18.0, "max": 3.0, "step": 0.5, "integer": false},
	{"key": "tier_4_body_volume_db", "label": "티어4 저역 볼륨", "min": -18.0, "max": 3.0, "step": 0.5, "integer": false},
	{"key": "tier_0_body_pitch", "label": "티어0 저역 피치", "min": 0.5, "max": 1.2, "step": 0.01, "integer": false},
	{"key": "tier_1_body_pitch", "label": "티어1 저역 피치", "min": 0.5, "max": 1.2, "step": 0.01, "integer": false},
	{"key": "tier_2_body_pitch", "label": "티어2 저역 피치", "min": 0.5, "max": 1.2, "step": 0.01, "integer": false},
	{"key": "tier_3_body_pitch", "label": "티어3 저역 피치", "min": 0.5, "max": 1.2, "step": 0.01, "integer": false},
	{"key": "tier_4_body_pitch", "label": "티어4 저역 피치", "min": 0.5, "max": 1.2, "step": 0.01, "integer": false},
	{"key": "tier_rise_start_hz", "label": "상승음 시작 Hz", "min": 40.0, "max": 180.0, "step": 1.0, "integer": false},
	{"key": "tier_rise_end_hz", "label": "상승음 종료 Hz", "min": 60.0, "max": 300.0, "step": 1.0, "integer": false},
	{"key": "tier_rise_volume_db", "label": "상승음 볼륨", "min": -30.0, "max": 0.0, "step": 0.5, "integer": false},
	{"key": "tier_4_hum_hz", "label": "티어4 지속음 Hz", "min": 40.0, "max": 120.0, "step": 1.0, "integer": false},
	{"key": "tier_4_hum_volume_db", "label": "티어4 지속음", "min": -40.0, "max": -6.0, "step": 0.5, "integer": false},
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
@export_range(0.0, 5.0, 0.1) var combo_grace_time := 3.0
@export_range(1.0, 20.0, 0.5) var combo_decay_per_second := 5.0
@export_range(1, 200, 1) var tier_1_threshold := 10
@export_range(1, 200, 1) var tier_2_threshold := 25
@export_range(1, 200, 1) var tier_3_threshold := 50
@export_range(1, 200, 1) var tier_4_threshold := 100
@export_range(0.5, 4.0, 0.05) var tier_0_sword_scale := 1.0
@export_range(0.5, 4.0, 0.05) var tier_1_sword_scale := 1.3
@export_range(0.5, 4.0, 0.05) var tier_2_sword_scale := 1.7
@export_range(0.5, 4.0, 0.05) var tier_3_sword_scale := 2.2
@export_range(0.5, 4.0, 0.05) var tier_4_sword_scale := 3.0
@export_range(0.0, 0.15, 0.005) var tier_1_hitstop := 0.06
@export_range(0.0, 0.15, 0.005) var tier_2_hitstop := 0.08
@export_range(0.0, 0.15, 0.005) var tier_3_hitstop := 0.1
@export_range(0.0, 0.15, 0.005) var tier_4_hitstop := 0.12
@export_range(0.05, 0.2, 0.005) var tier_transition_duration := 0.18
@export_range(64, 220, 1) var combo_font_size := 148
@export_range(0.03, 0.4, 0.01) var combo_opacity := 0.13
@export_range(1.0, 2.0, 0.05) var combo_pulse_scale := 1.35
@export_range(0.0, 0.8, 0.01) var tier_flash_opacity := 0.28
@export_range(6.0, 32.0, 1.0) var blade_glow_width := 17.0
@export_range(0.0, 1.0, 0.01) var blade_glow_opacity := 0.36
@export_range(0.04, 0.3, 0.01) var afterimage_lifetime := 0.12
@export_range(1, 24, 1) var afterimage_max_count := 10
@export_range(0.0, 0.8, 0.01) var afterimage_opacity := 0.24
@export_range(1, 12, 1) var electric_bolt_count := 6
@export_range(10.0, 80.0, 1.0) var electric_bolt_length := 46.0
@export_range(0.04, 0.3, 0.01) var electric_bolt_lifetime := 0.14
@export_range(1.0, 6.0, 0.5) var electric_bolt_width := 2.5
@export_range(0.0, 24.0, 1.0) var electric_bolt_jitter := 9.0
@export_range(1.0, 2.0, 0.05) var tier_4_saturation := 1.35
@export_range(-18.0, 3.0, 0.5) var blade_volume_db := -3.0
@export_range(-18.0, 3.0, 0.5) var tail_volume_db := -5.0
@export_range(-18.0, 3.0, 0.5) var tier_0_body_volume_db := -1.0
@export_range(-18.0, 3.0, 0.5) var tier_1_body_volume_db := -1.5
@export_range(-18.0, 3.0, 0.5) var tier_2_body_volume_db := -2.0
@export_range(-18.0, 3.0, 0.5) var tier_3_body_volume_db := -2.5
@export_range(-18.0, 3.0, 0.5) var tier_4_body_volume_db := -3.0
@export_range(0.5, 1.2, 0.01) var tier_0_body_pitch := 1.0
@export_range(0.5, 1.2, 0.01) var tier_1_body_pitch := 0.96
@export_range(0.5, 1.2, 0.01) var tier_2_body_pitch := 0.91
@export_range(0.5, 1.2, 0.01) var tier_3_body_pitch := 0.85
@export_range(0.5, 1.2, 0.01) var tier_4_body_pitch := 0.78
@export_range(40.0, 180.0, 1.0) var tier_rise_start_hz := 58.0
@export_range(60.0, 300.0, 1.0) var tier_rise_end_hz := 132.0
@export_range(-30.0, 0.0, 0.5) var tier_rise_volume_db := -13.0
@export_range(40.0, 120.0, 1.0) var tier_4_hum_hz := 60.0
@export_range(-40.0, -6.0, 0.5) var tier_4_hum_volume_db := -25.0


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
