class_name GameCommand
extends RefCounted

enum Kind {
	START_RESEARCH,
	PAUSE_RESEARCH,
	CREATE_BLUEPRINT,
	CONFIGURE_PRODUCTION,
	SET_PRODUCTION_ENABLED,
	PURCHASE_MATERIAL, # Retired: preserve numeric command IDs.
	SELL_MATERIAL, # Retired: storage staff handle surplus sales.
	SET_PRICE,
	STOP_SALE,
	PLACE_ROOM,
	RESIZE_ROOM,
	PLACE_STATION,
	ASSIGN_STAFF,
	HIRE_STAFF,
	DISMISS_STAFF,
	TAKE_LOAN,
	ACCEPT_CONTRACT,
	SUBMIT_CONTRACT,
	CHOOSE_PROFESSION,
	SET_WAGE_LEVEL,
	ASSIGN_RESEARCH_TEAM,
	CHANGE_FOCUS,
	SUBMIT_PROTOTYPES,
	SUBMIT_FINAL_PROJECT,
	RESTART_MASTER_SALES,
	CONTINUE_GAME,
}

var kind: Kind
var payload: Dictionary

func _init(command_kind: Kind, command_payload: Dictionary = {}) -> void:
	kind = command_kind
	payload = command_payload.duplicate(true)

static func start_research(project_id: String, team_id: int = 0) -> GameCommand:
	return GameCommand.new(Kind.START_RESEARCH, {"project_id": project_id, "team_id":team_id})

static func pause_research(team_id: int = 0) -> GameCommand:
	return GameCommand.new(Kind.PAUSE_RESEARCH, {"team_id":team_id})

## Material is derived from body_id; an explicit material_id must match.
static func create_blueprint(data: Dictionary) -> GameCommand:
	return GameCommand.new(Kind.CREATE_BLUEPRINT, data)

static func configure_production(station_id: String, blueprint_id: String) -> GameCommand:
	return GameCommand.new(Kind.CONFIGURE_PRODUCTION, {"station_id":station_id, "blueprint_id":blueprint_id})

static func set_production_enabled(station_id: String, enabled: bool) -> GameCommand:
	return GameCommand.new(Kind.SET_PRODUCTION_ENABLED, {"station_id":station_id, "enabled":enabled})

static func purchase_material(material_id: String, quantity: int) -> GameCommand:
	return GameCommand.new(Kind.PURCHASE_MATERIAL, {"material_id":material_id, "quantity":quantity})

static func sell_material(material_id: String, quantity: int) -> GameCommand:
	return GameCommand.new(Kind.SELL_MATERIAL, {"material_id":material_id, "quantity":quantity})

static func set_price(blueprint_id: String, price: float) -> GameCommand:
	return GameCommand.new(Kind.SET_PRICE, {"blueprint_id": blueprint_id, "price": price})

static func stop_sale(blueprint_id: String) -> GameCommand:
	return GameCommand.new(Kind.STOP_SALE, {"blueprint_id": blueprint_id})

static func place_room(room_type: String, rect: Rect2i) -> GameCommand:
	return GameCommand.new(Kind.PLACE_ROOM, {"room_type": room_type, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})

static func resize_room(room_id: String, rect: Rect2i) -> GameCommand:
	return GameCommand.new(Kind.RESIZE_ROOM, {"room_id": room_id, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})

static func place_station(station_type: String, position: Vector2i) -> GameCommand:
	return GameCommand.new(Kind.PLACE_STATION, {"station_type": station_type, "position": [position.x, position.y]})

static func assign_staff(staff_id: String, station_id: String) -> GameCommand:
	return GameCommand.new(Kind.ASSIGN_STAFF, {"staff_id":staff_id, "station_id":station_id})

static func hire_staff(staff_id: String) -> GameCommand:
	return GameCommand.new(Kind.HIRE_STAFF, {"staff_id":staff_id})

static func dismiss_staff(staff_id: String) -> GameCommand:
	return GameCommand.new(Kind.DISMISS_STAFF, {"staff_id":staff_id})

static func take_loan() -> GameCommand:
	return GameCommand.new(Kind.TAKE_LOAN)

static func accept_contract(contract_id: String) -> GameCommand:
	return GameCommand.new(Kind.ACCEPT_CONTRACT, {"contract_id": contract_id})

static func submit_contract(contract_id: String) -> GameCommand:
	return GameCommand.new(Kind.SUBMIT_CONTRACT, {"contract_id": contract_id})

static func choose_profession(profession_id: String) -> GameCommand:
	return GameCommand.new(Kind.CHOOSE_PROFESSION, {"profession_id":profession_id})

static func set_wage_level(value: float) -> GameCommand:
	return GameCommand.new(Kind.SET_WAGE_LEVEL, {"value":value})

static func assign_research_team(station_id: String, team_id: int) -> GameCommand:
	return GameCommand.new(Kind.ASSIGN_RESEARCH_TEAM, {"station_id":station_id, "team_id":team_id})

static func change_focus(branch_id: String, team_id: int = 0) -> GameCommand:
	return GameCommand.new(Kind.CHANGE_FOCUS, {"branch_id":branch_id, "team_id":team_id})

static func submit_prototypes(project_id: String, selection: Array) -> GameCommand:
	return GameCommand.new(Kind.SUBMIT_PROTOTYPES, {"project_id":project_id, "selection":selection})

static func submit_final_project(project_id: String, selection: Array) -> GameCommand:
	return GameCommand.new(Kind.SUBMIT_FINAL_PROJECT, {"project_id":project_id, "selection":selection})

static func restart_master_sales() -> GameCommand:
	return GameCommand.new(Kind.RESTART_MASTER_SALES)

static func continue_game() -> GameCommand:
	return GameCommand.new(Kind.CONTINUE_GAME)
