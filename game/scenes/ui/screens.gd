class_name Screens
extends RefCounted
## Every screen, by name. A screen moves on with
## [code]Screens.go(Screens.MAP)[/code]; the app shell (main.tscn) does the
## swap, so screens never load each other and each can be tested alone.

const TITLE: StringName = &"title"
const MAP: StringName = &"map"
const AUCTION: StringName = &"auction"
const SHOP: StringName = &"shop"
const SUMMARY: StringName = &"summary"
const LOBBY: StringName = &"lobby"

const PATHS: Dictionary[StringName, String] = {
	TITLE: "res://scenes/ui/title_screen.tscn",
	MAP: "res://scenes/map/map_screen.tscn",
	AUCTION: "res://scenes/auction/auction_yard.tscn",
	SHOP: "res://scenes/shop/shop_screen.tscn",
	SUMMARY: "res://scenes/ui/day_summary.tscn",
	LOBBY: "res://scenes/ui/lobby.tscn",
}


static func path(screen: StringName) -> String:
	return PATHS[screen]


## Asks the app shell to show [param screen].
static func go(screen: StringName) -> void:
	EventBus.screen_requested.emit(screen)


## The screen that shows [param stage] of the day.
static func for_stage(stage: DayFlow.Stage) -> StringName:
	match stage:
		DayFlow.Stage.MAP:
			return MAP
		DayFlow.Stage.SHOP:
			return SHOP
		DayFlow.Stage.SUMMARY:
			return SUMMARY
		_:
			return AUCTION
