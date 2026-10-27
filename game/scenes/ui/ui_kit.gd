class_name UiKit
extends RefCounted
## Helpers for the graybox UI built in code: labels and buttons with
## translated text, and display names for content. Text passed in is already
## translated, so these nodes switch off Godot's auto-translation.

const ROW_HEIGHT: int = 56
const SMALL: int = 22
const LARGE: int = 40
const HUGE: int = 72

## Placeholder rarity colours until the settings menu adds colour-blind-safe
## ones.
const RARITY_COLORS: Dictionary[StringName, Color] = {
	&"common": Color(0.85, 0.85, 0.85),
	&"uncommon": Color(0.49, 0.82, 0.45),
	&"rare": Color(0.42, 0.66, 1.0),
	&"epic": Color(0.78, 0.53, 1.0),
	&"legendary": Color(1.0, 0.71, 0.27),
}


static func text(key: String) -> String:
	return String(TranslationServer.translate(key))


static func label(content: String, font_size: int = 0) -> Label:
	var made := Label.new()
	made.text = content
	made.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		made.add_theme_font_size_override("font_size", font_size)
	return made


## A button that calls [param on_pressed]. [param node_name] lets a screen
## find it again after rebuilding a list, to put focus back where it was.
static func button(content: String, on_pressed: Callable, node_name: String = "", font_size: int = 0) -> Button:
	var made := Button.new()
	made.text = content
	made.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	made.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	if not node_name.is_empty():
		made.name = node_name
	if font_size > 0:
		made.add_theme_font_size_override("font_size", font_size)
	made.pressed.connect(on_pressed)
	return made


## Sets [param target]'s text and hides it while there's none, so empty
## lines don't leave gaps.
static func show_text(target: Label, content: String) -> void:
	target.text = content
	target.visible = not content.is_empty()


## Frees every child of [param container].
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## The first enabled button in [param container] or anywhere below it, or null.
static func first_button(container: Node) -> Button:
	for child in container.get_children():
		if child is Button and not (child as Button).disabled:
			return child as Button
		var inner := first_button(child)
		if inner != null:
			return inner
	return null


## Gives focus to [param preferred] if it can take it, otherwise to the first
## enabled button in [param fallback].
static func focus(preferred: Control, fallback: Node) -> void:
	if preferred != null and preferred.is_visible_in_tree() and not (preferred is BaseButton and (preferred as BaseButton).disabled):
		preferred.grab_focus()
		return
	var first := first_button(fallback)
	if first != null:
		first.grab_focus()


static func item_name(def_id: StringName) -> String:
	return text("ITEM_" + String(def_id).to_upper())


static func condition_name(condition: StringName) -> String:
	return text("CONDITION_" + String(condition).to_upper())


static func rarity_name(rarity: StringName) -> String:
	return text("RARITY_" + String(rarity).to_upper())


static func rarity_color(rarity: StringName) -> Color:
	return RARITY_COLORS[rarity] if RARITY_COLORS.has(rarity) else Color.WHITE


## "Good" or "Good, dirty".
static func state_of(item: ItemInstance) -> String:
	var shown := condition_name(item.condition)
	return fmt("UI_DIRTY", [shown]) if item.dirty else shown


static func rival_name(rival_id: StringName) -> String:
	return text("RIVAL_" + String(rival_id).to_upper())


## "You" for this machine's player, "Player 2" for a crewmate, otherwise the
## rival's name.
static func bidder_name(bidder: StringName) -> String:
	if bidder == GameState.local_member:
		return text("UI_YOU")
	var seat := Crew.seat_of(bidder)
	if seat >= 0:
		return fmt("UI_PLAYER", [seat + 1])
	return rival_name(bidder)


## The text of [param key] filled in with [param values], printf style.
static func fmt(key: String, values: Array) -> String:
	return text(key) % values
