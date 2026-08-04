extends Node2D

const SAMPLE_RATE_HZ := 44100
const CLICK_DURATION_SECONDS := 0.045
const CLICK_FREQUENCY_HZ := 1050.0
const CLICK_DECAY_RATE := 72.0
const CLICK_AMPLITUDE := 0.48
const QUIET_FEEDBACK := Color(0.0, 0.898, 0.816, 0.24)
const ACTIVE_FEEDBACK := Color(1.0, 1.0, 1.0, 0.95)

@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var feedback: ColorRect = $Center/Content/Feedback
@onready var feedback_timer: Timer = $FeedbackTimer


func _ready() -> void:
	audio_player.stream = _create_click_stream()
	feedback_timer.timeout.connect(_reset_feedback)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		audio_player.play()
		feedback.color = ACTIVE_FEEDBACK
		feedback_timer.start()
		get_viewport().set_input_as_handled()


func _create_click_stream() -> AudioStreamWAV:
	var frame_count := int(SAMPLE_RATE_HZ * CLICK_DURATION_SECONDS)
	var pcm_data := PackedByteArray()
	pcm_data.resize(frame_count * 2)

	for frame_index in frame_count:
		var elapsed_seconds := float(frame_index) / SAMPLE_RATE_HZ
		var envelope := exp(-CLICK_DECAY_RATE * elapsed_seconds)
		var waveform := sin(TAU * CLICK_FREQUENCY_HZ * elapsed_seconds)
		var sample := int(clampf(waveform * envelope * CLICK_AMPLITUDE, -1.0, 1.0) * 32767.0)
		pcm_data.encode_s16(frame_index * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE_HZ
	stream.stereo = false
	stream.data = pcm_data
	return stream


func _reset_feedback() -> void:
	feedback.color = QUIET_FEEDBACK
