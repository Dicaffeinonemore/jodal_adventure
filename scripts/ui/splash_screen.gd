extends Control
## Opening cards before the title (main scene): the 조달청 logo on white
## (assets/splash/pps_logo.png, the official symbol), then the credit line
## (Story.CREDIT) on black, each fading in and out of black. Any key, click or tap
## skips the current card. Ends on black and opens the title without the door sound.

const LOGO := "res://assets/splash/pps_logo.png"
const FADE := 0.5
const HOLD_LOGO := 1.6
const HOLD_CREDIT := 1.4
const CREDIT_SIZE := 32

var _skip := false
var _curtain: ColorRect  # black on top; fading it (not the cards) keeps the logo's white box invisible


func _ready() -> void:
	UiTheme.apply(self)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	var card := ColorRect.new()
	card.color = Color.WHITE
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.hide()
	add_child(card)
	var logo := TextureRect.new()
	logo.texture = load(LOGO) as Texture2D
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # a smooth image, not pixel art
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.18
	logo.anchor_right = 0.82
	logo.anchor_top = 0.25
	logo.anchor_bottom = 0.75
	card.add_child(logo)

	var credit := UiTheme.make_label(Story.CREDIT, CREDIT_SIZE, Color.WHITE, true)
	credit.set_anchors_preset(Control.PRESET_FULL_RECT)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credit.hide()
	add_child(credit)
	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)
	_run(card, credit)


func _run(card: Control, credit: Control) -> void:
	await _show(card, HOLD_LOGO)
	await _show(credit, HOLD_CREDIT)
	SceneRouter.goto(SceneRouter.TITLE, "", false)


func _show(node: Control, hold: float) -> void:
	_skip = false
	node.show()
	await _fade(0.0)
	var t := 0.0
	while t < hold and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _fade(1.0)
	node.hide()


func _fade(curtain_alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(_curtain, "color:a", curtain_alpha, FADE)
	await tw.finished


func _input(event: InputEvent) -> void:
	# Pointers count on release, like the title (a touch is followed by an emulated click).
	if (event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo()) \
			or (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed):
		_skip = true
		get_viewport().set_input_as_handled()
