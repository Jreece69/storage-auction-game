class_name Catalog
extends RefCounted
## Every piece of game content, loaded from game/data and checked in two
## passes: each file against its schema in game/data/schemas, then the
## references between files (a theme's categories have items, a zone's rivals
## exist, and so on). Systems are handed the catalog, or the definitions they
## need; the Content autoload holds the one the running game uses.

const DATA_DIR: String = "res://data"
## Single-file sections, each data/<name>.json checked by
## data/schemas/<name>.schema.json. Items are a folder: data/items/*.json.
const FILE_SECTIONS: Array[String] = ["lockers", "zones", "rivals", "customers", "vehicles", "economy"]

var items: Dictionary[StringName, ItemDef] = {}
var themes: Dictionary[StringName, LockerThemeDef] = {}
var zones: Dictionary[StringName, ZoneDef] = {}
var rivals: Dictionary[StringName, RivalDef] = {}
var customers: Dictionary[StringName, CustomerDef] = {}
var vehicles: Dictionary[StringName, VehicleDef] = {}
var economy: EconomyDef = null
## Problems found while loading, one readable line each. Empty means good.
var errors: PackedStringArray = PackedStringArray()

var _errors: Array[String] = []


## Reads and checks everything under [param dir].
static func load_from(dir: String = DATA_DIR) -> Catalog:
	var read_errors: Array[String] = []
	var data := read_data(dir, read_errors)
	if not read_errors.is_empty():
		var failed := Catalog.new()
		failed._finish(read_errors)
		return failed
	return from_data(data, dir.path_join("schemas"))


## The parsed contents of every data file under [param dir], in the shape
## [method from_data] takes. Files that can't be read are reported in
## [param problems].
static func read_data(dir: String, problems: Array[String]) -> Dictionary:
	var item_files: Dictionary = {}
	var items_dir := dir.path_join("items")
	if DirAccess.dir_exists_absolute(items_dir):
		for file_name in DirAccess.get_files_at(items_dir):
			if file_name.ends_with(".json"):
				item_files["items/" + file_name] = _read_json(items_dir.path_join(file_name), "items/" + file_name, problems)
	if item_files.is_empty():
		problems.append("items/: no item files found")
	var data: Dictionary = {"items": item_files}
	for section in FILE_SECTIONS:
		data[section] = _read_json(dir.path_join(section + ".json"), section + ".json", problems)
	return data


## Builds a catalog from parsed data: [code]{"items": {file name: [...]},
## "lockers": [...], ..., "economy": {...}}[/code]. Tests use this to feed in
## broken content.
static func from_data(data: Dictionary, schema_dir: String = DATA_DIR.path_join("schemas")) -> Catalog:
	var catalog := Catalog.new()
	var problems: Array[String] = []
	_validate_schemas(data, schema_dir, problems)
	if problems.is_empty():
		catalog._build(data, problems)
	if problems.is_empty():
		catalog._check_references(problems)
	catalog._finish(problems)
	return catalog


## Item definitions in [param category], sorted by id.
func items_in_category(category: StringName) -> Array[ItemDef]:
	var found: Array[ItemDef] = []
	for id in sorted_ids(items.keys()):
		var item: ItemDef = items[id]
		if item.category == category:
			found.append(item)
	return found


## Every item category, sorted.
func categories() -> Array[StringName]:
	var found: Array[StringName] = []
	for item: ItemDef in items.values():
		if not found.has(item.category):
			found.append(item.category)
	found.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return found


## [param ids] sorted alphabetically, for walking dictionaries in a fixed order.
static func sorted_ids(ids: Array) -> Array[StringName]:
	var sorted: Array[StringName] = []
	for id: Variant in ids:
		sorted.append(StringName(str(id)))
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return sorted


func _finish(problems: Array[String]) -> void:
	_errors = problems
	errors = PackedStringArray(problems)


static func _validate_schemas(data: Dictionary, schema_dir: String, problems: Array[String]) -> void:
	var item_schema: Variant = _read_json(schema_dir.path_join("items.schema.json"), "schemas/items.schema.json", problems)
	var item_files: Dictionary = data.get("items", {})
	if item_schema is Dictionary:
		var schema: Dictionary = item_schema
		for file_name: Variant in item_files:
			problems.append_array(JsonSchema.validate(item_files[file_name], schema, str(file_name)))
	for section in FILE_SECTIONS:
		var label := "schemas/%s.schema.json" % section
		var section_schema: Variant = _read_json(schema_dir.path_join(section + ".schema.json"), label, problems)
		if section_schema is Dictionary:
			var schema: Dictionary = section_schema
			problems.append_array(JsonSchema.validate(data.get(section), schema, section + ".json"))


func _build(data: Dictionary, problems: Array[String]) -> void:
	var economy_data: Dictionary = data["economy"]
	economy = EconomyDef.from_dict(economy_data)
	var item_files: Dictionary = data["items"]
	for file_name: Variant in item_files:
		var entries: Array = item_files[file_name]
		for entry: Dictionary in entries:
			var item := ItemDef.from_dict(entry)
			if items.has(item.id):
				problems.append("%s: item id \"%s\" is used twice" % [file_name, item.id])
			items[item.id] = item
	for entry: Dictionary in _array(data, "lockers"):
		var theme := LockerThemeDef.from_dict(entry)
		_add_unique(themes, theme.id, theme, "lockers.json", problems)
	for entry: Dictionary in _array(data, "zones"):
		var zone := ZoneDef.from_dict(entry)
		_add_unique(zones, zone.id, zone, "zones.json", problems)
	for entry: Dictionary in _array(data, "rivals"):
		var rival := RivalDef.from_dict(entry)
		_add_unique(rivals, rival.id, rival, "rivals.json", problems)
	for entry: Dictionary in _array(data, "customers"):
		var customer := CustomerDef.from_dict(entry)
		_add_unique(customers, customer.id, customer, "customers.json", problems)
	for entry: Dictionary in _array(data, "vehicles"):
		var vehicle := VehicleDef.from_dict(entry)
		_add_unique(vehicles, vehicle.id, vehicle, "vehicles.json", problems)


func _check_references(problems: Array[String]) -> void:
	var order := economy.condition_order
	var item_categories := categories()
	for id in sorted_ids(items.keys()):
		var item: ItemDef = items[id]
		var where := "item %s" % id
		_check_range(item.value_min, item.value_max, where + " value", problems)
		var lowest := order.find(item.condition_min)
		var highest := order.find(item.condition_max)
		if lowest < 0 or highest < 0:
			problems.append("%s: condition must be from %s" % [where, order])
		elif lowest > highest:
			problems.append("%s: condition %s is better than %s" % [where, item.condition_min, item.condition_max])
		if item.size > economy.shop.slots_per_shelf:
			problems.append("%s: size %d won't fit on a %d-slot shelf" % [where, item.size, economy.shop.slots_per_shelf])
	for id in sorted_ids(themes.keys()):
		var theme: LockerThemeDef = themes[id]
		var where := "locker theme %s" % id
		_check_range(theme.item_count_min, theme.item_count_max, where + " item_count", problems)
		_check_range(theme.junk_weight_min, theme.junk_weight_max, where + " junk_weight", problems)
		for category: StringName in theme.category_weights:
			if not item_categories.has(category):
				problems.append("%s: no items in category \"%s\"" % [where, category])
	for id in sorted_ids(zones.keys()):
		var zone: ZoneDef = zones[id]
		var where := "zone %s" % id
		_check_range(zone.opening_noise_min, zone.opening_noise_max, where + " opening_noise", problems)
		for theme_id: StringName in zone.theme_weights:
			if not themes.has(theme_id):
				problems.append("%s: unknown locker theme \"%s\"" % [where, theme_id])
		for rival_id in zone.rivals:
			if not rivals.has(rival_id):
				problems.append("%s: unknown rival \"%s\"" % [where, rival_id])
	for id in sorted_ids(rivals.keys()):
		var rival: RivalDef = rivals[id]
		var where := "rival %s" % id
		_check_range(rival.budget_min, rival.budget_max, where + " budget", problems)
		_check_range(rival.risk_min, rival.risk_max, where + " risk_appetite", problems)
		_check_range(rival.reaction_min, rival.reaction_max, where + " reaction_seconds", problems)
		if rival.reaction_max >= economy.auction.countdown_seconds:
			problems.append("%s: reaction_seconds must stay under the %s-second countdown" % [where, JsonSchema.format_number(economy.auction.countdown_seconds)])
		if rival.favorite_category != &"" and not item_categories.has(rival.favorite_category):
			problems.append("%s: no items in favorite category \"%s\"" % [where, rival.favorite_category])
	for id in sorted_ids(customers.keys()):
		var customer: CustomerDef = customers[id]
		var where := "customer %s" % id
		_check_range(customer.pay_min, customer.pay_max, where + " will_pay", problems)
		_check_range(customer.offer_min, customer.offer_max, where + " opening_offer", problems)
	if not vehicles.has(economy.starting_vehicle):
		problems.append("economy: unknown starting_vehicle \"%s\"" % economy.starting_vehicle)
	if not zones.has(economy.starting_zone):
		problems.append("economy: unknown starting_zone \"%s\"" % economy.starting_zone)
	elif zones[economy.starting_zone].unlock_net_worth > 0:
		problems.append("economy: the starting zone must be open from the start")
	for condition in order:
		if not economy.condition_multipliers.has(condition) or not economy.condition_weights.has(condition):
			problems.append("economy: condition \"%s\" needs a multiplier and a weight" % condition)
	for condition: StringName in economy.condition_multipliers:
		if not order.has(condition):
			problems.append("economy: multiplier for unknown condition \"%s\"" % condition)
	for condition: StringName in economy.condition_weights:
		if not order.has(condition):
			problems.append("economy: weight for unknown condition \"%s\"" % condition)
	for customer_id: StringName in economy.shop.customer_weights:
		if not customers.has(customer_id):
			problems.append("economy: unknown shop customer \"%s\"" % customer_id)


static func _check_range(low: float, high: float, where: String, problems: Array[String]) -> void:
	if low > high:
		problems.append("%s: %s is above %s" % [where, JsonSchema.format_number(low), JsonSchema.format_number(high)])


static func _add_unique(target: Dictionary, id: StringName, def: Resource, file: String, problems: Array[String]) -> void:
	if target.has(id):
		problems.append("%s: id \"%s\" is used twice" % [file, id])
	target[id] = def


static func _array(data: Dictionary, section: String) -> Array:
	var entries: Array = data[section]
	return entries


static func _read_json(path: String, label: String, problems: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		problems.append("%s: file not found" % label)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		problems.append("%s: line %d: %s" % [label, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
