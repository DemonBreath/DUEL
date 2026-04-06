extends Node

const SLOT_HEAD := "head"

const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_LEGENDARY := "legendary"

const FALLBACK_HAT_ID := "plastic_hat_01"

const ITEMS := {
	"alien_brain_01": {
		"id": "alien_brain_01",
		"display_name": "Alien Brain",
		"slot": SLOT_HEAD,
		"rarity": RARITY_LEGENDARY,
		"flavor_text": "It pulses like it's still thinking.",
		"scene_path": "res://items/head/AlienBrain_01.tscn",
		"is_fallback": false
	},
	"brick_hat_01": {
		"id": "brick_hat_01",
		"display_name": "Brick Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_COMMON,
		"flavor_text": "Heavy, stupid, and weirdly confidence-boosting.",
		"scene_path": "res://items/head/BrickHat_01.tscn",
		"is_fallback": false
	},
	"clock_hat_01": {
		"id": "clock_hat_01",
		"display_name": "Clock Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_UNCOMMON,
		"flavor_text": "Always late, never subtle.",
		"scene_path": "res://items/head/ClockHat_01.tscn",
		"is_fallback": false
	},
	"crimson_hat_01": {
		"id": "crimson_hat_01",
		"display_name": "Crimson Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_UNCOMMON,
		"flavor_text": "Looks expensive from far away.",
		"scene_path": "res://items/head/CrimsonHat_01.tscn",
		"is_fallback": false
	},
	"disco_hat_01": {
		"id": "disco_hat_01",
		"display_name": "Disco Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_RARE,
		"flavor_text": "Every angle begs for a spotlight.",
		"scene_path": "res://items/head/DiscoHat_01.tscn",
		"is_fallback": false
	},
	"diver_hat_01": {
		"id": "diver_hat_01",
		"display_name": "Diver Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_UNCOMMON,
		"flavor_text": "Built for pressure. Mostly emotional.",
		"scene_path": "res://items/head/DiverHat_01.tscn",
		"is_fallback": false
	},
	"entanglement_hat_01": {
		"id": "entanglement_hat_01",
		"display_name": "Entanglement Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_LEGENDARY,
		"flavor_text": "No one agrees where it begins or ends.",
		"scene_path": "res://items/head/EntanglementHat_01.tscn",
		"is_fallback": false
	},
	"gilded_hat_01": {
		"id": "gilded_hat_01",
		"display_name": "Gilded Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_RARE,
		"flavor_text": "Too polished for honest work.",
		"scene_path": "res://items/head/GildedHat_01.tscn",
		"is_fallback": false
	},
	"horn_hat_01": {
		"id": "horn_hat_01",
		"display_name": "Horn Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_UNCOMMON,
		"flavor_text": "Points first, questions later.",
		"scene_path": "res://items/head/HornHat_01.tscn",
		"is_fallback": false
	},
	"Ice_hat_01": {
		"id": "Ice_hat_01",
		"display_name": "Ice Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_RARE,
		"flavor_text": "Cold enough to make bad ideas feel sharp.",
		"scene_path": "res://items/head/IceHat_01.tscn",
		"is_fallback": false
	},
	"inferno_ring_01": {
		"id": "inferno_ring_01",
		"display_name": "Inferno Ring",
		"slot": SLOT_HEAD,
		"rarity": RARITY_RARE,
		"flavor_text": "It glows hottest when its owner starts winning.",
		"scene_path": "res://items/head/InfernoRing_01.tscn",
		"is_fallback": false
	},
	"mech_hat_01": {
		"id": "mech_hat_01",
		"display_name": "Mech Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_RARE,
		"flavor_text": "All rivets, no mercy.",
		"scene_path": "res://items/head/MechHat_01.tscn",
		"is_fallback": false
	},
	"mushroom_hat_01": {
		"id": "mushroom_hat_01",
		"display_name": "Mushroom Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_COMMON,
		"flavor_text": "Soft, damp, and strangely respected.",
		"scene_path": "res://items/head/MushroomHat_01.tscn",
		"is_fallback": false
	},
	"plastic_hat_01": {
		"id": "plastic_hat_01",
		"display_name": "Plastic Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_COMMON,
		"flavor_text": "Cheap, cracked, and always replaceable.",
		"scene_path": "res://items/head/PlasticHat_01.tscn",
		"is_fallback": true
	},
	"skull_hat_01": {
		"id": "skull_hat_01",
		"display_name": "Skull Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_RARE,
		"flavor_text": "A reminder that somebody already lost.",
		"scene_path": "res://items/head/SkullHat_01.tscn",
		"is_fallback": false
	},
	"slime_hat_01": {
		"id": "slime_hat_01",
		"display_name": "Slime Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_COMMON,
		"flavor_text": "Still dripping. No one knows from where.",
		"scene_path": "res://items/head/SlimeHat_01.tscn",
		"is_fallback": false
	},
	"toxic_hat_01": {
		"id": "toxic_hat_01",
		"display_name": "Toxic Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_UNCOMMON,
		"flavor_text": "The fumes do half the talking.",
		"scene_path": "res://items/head/ToxicHat_01.tscn",
		"is_fallback": false
	},
	"tv_hat_01": {
		"id": "tv_hat_01",
		"display_name": "TV Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_LEGENDARY,
		"flavor_text": "Always on. Never tuned right.",
		"scene_path": "res://items/head/TVHat_01.tscn",
		"is_fallback": false
	},
	"wizard_hat_01": {
		"id": "wizard_hat_01",
		"display_name": "Wizard Hat",
		"slot": SLOT_HEAD,
		"rarity": RARITY_RARE,
		"flavor_text": "More swagger than spellcraft.",
		"scene_path": "res://items/head/WizardHat_01.tscn",
		"is_fallback": false
	}
}

func has_item_def(item_id: String) -> bool:
	return ITEMS.has(item_id)

func get_item_def(item_id: String) -> Dictionary:
	if not ITEMS.has(item_id):
		push_error("ItemDatabase: Missing item definition for id: %s" % item_id)
		return {}
	return ITEMS[item_id].duplicate(true)

func get_item_slot(item_id: String) -> String:
	var item_def: Dictionary = get_item_def(item_id)
	if item_def.is_empty():
		return ""
	return str(item_def.get("slot", ""))

func get_item_scene_path(item_id: String) -> String:
	var item_def: Dictionary = get_item_def(item_id)
	if item_def.is_empty():
		return ""
	return str(item_def.get("scene_path", ""))

func get_item_display_name(item_id: String) -> String:
	var item_def: Dictionary = get_item_def(item_id)
	if item_def.is_empty():
		return item_id
	return str(item_def.get("display_name", item_id))

func get_item_rarity(item_id: String) -> String:
	var item_def: Dictionary = get_item_def(item_id)
	if item_def.is_empty():
		return RARITY_COMMON
	return str(item_def.get("rarity", RARITY_COMMON))

func get_item_flavor_text(item_id: String) -> String:
	var item_def: Dictionary = get_item_def(item_id)
	if item_def.is_empty():
		return ""
	return str(item_def.get("flavor_text", ""))

func is_fallback_hat(item_id: String) -> bool:
	var item_def: Dictionary = get_item_def(item_id)
	if item_def.is_empty():
		return false
	return bool(item_def.get("is_fallback", false))

func is_valid_slot(slot_name: String) -> bool:
	return slot_name == SLOT_HEAD

func get_all_hat_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in ITEMS.keys():
		result.append(str(item_id))
	return result
