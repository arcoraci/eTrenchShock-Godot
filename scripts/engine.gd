extends RefCounted
class_name Engine
## Trench Shock rules, browser version 0.10.0.
## Action die: 2 boots, 1 whistle, 1 wild, 1 shovel, 1 bayonet.
## Attack die: 3 Hit / 3 Miss. Mortar die: enemy Zone 1, 1, 2, 2, 3, 3. One hit, exposed first.

const VERSION := "0.10.0"
const BATTLEFIELD: Array = ["uk1", "uk2", "uk3", "obj", "de3", "de2", "de1"]
const UK_SIDE: Array = ["uk1", "uk2", "uk3"]
const DE_SIDE: Array = ["de1", "de2", "de3"]
const ACTION_FACES: Array = ["boot", "boot", "whistle", "wild", "shovel", "bayonet"]
const ATTACK_FACES: Array = ["hit", "hit", "hit", "miss", "miss", "miss"]
const MORTAR_FACES: Array = ["z1", "z1", "z2", "z2", "z3", "z3"]
const STEPS: Array = ["shock", "tank", "event", "deploy", "move", "cover", "attack"]
const SYMBOL_RANK := {"bayonet": 4, "whistle": 3, "shovel": 2, "boot": 1}
const COMBO_RANK := {
	"five": 6, "four": 5, "fullHouse": 4, "three": 3, "twoPair": 2, "pair": 1, "none": 0,
}
const FORMATS := {
	"short": {"rounds": 8, "missions": 10, "remove": 6},
	"standard": {"rounds": 10, "missions": 12, "remove": 4},
	"extended": {"rounds": 12, "missions": 16, "remove": 0},
}
const ZONE_LABELS := {
	"ukTrench": "British Trench",
	"uk1": "British Zone 1",
	"uk2": "British Zone 2",
	"uk3": "British Zone 3",
	"obj": "Objective Zone",
	"de3": "German Zone 3",
	"de2": "German Zone 2",
	"de1": "German Zone 1",
	"deTrench": "German Trench",
}
const FACE_LABELS := {
	"boot": "Boot", "whistle": "Whistle", "wild": "Wild", "shovel": "Shovel",
	"bayonet": "Bayonet", "hit": "Hit", "miss": "Miss", "z1": "Zone 1", "z2": "Zone 2", "z3": "Zone 3",
}
const COMBO_NAMES := {
	"five": "Five of a Kind", "four": "Four of a Kind", "fullHouse": "Full House",
	"three": "Three of a Kind", "twoPair": "Two Pairs", "pair": "One Pair", "none": "No combination",
}
const SKIP := {
	"shock": "SKIP_SHOCK", "tank": "SKIP_TANK", "event": "SKIP_EVENT", "deploy": "SKIP_DEPLOY",
	"move": "SKIP_MOVE", "cover": "SKIP_COVER", "attack": "SKIP_ATTACK",
}
const HOSTILE: Array = ["Bayonet Charge", "Bombing Run", "Heavy Barrage", "Sniper", "Trench Fever"]
const FORMAT_NAMES := {"short": "Short Battle", "standard": "Standard Battle", "extended": "Extended Battle"}


static func load_catalog() -> Dictionary:
	return {
		"events": _read_json("res://data/events.json"),
		"missions": _read_json("res://data/missions.json"),
	}


static func _read_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		return parsed
	return []


static func clone_value(value):
	if value is Dictionary:
		var copied := {}
		for key in value.keys():
			copied[key] = clone_value(value[key])
		return copied
	if value is Array:
		var copied: Array = []
		for item in value:
			copied.append(clone_value(item))
		return copied
	return value


static func coerce_numbers(value):
	if value is float:
		if is_finite(value) and absf(value) < 9007199254740992.0 and is_equal_approx(value, roundf(value)):
			return int(roundf(value))
		return value
	if value is Dictionary:
		var copied := {}
		for key in value.keys():
			copied[key] = coerce_numbers(value[key])
		return copied
	if value is Array:
		var copied: Array = []
		for item in value:
			copied.append(coerce_numbers(item))
		return copied
	return value


static func other(side: String) -> String:
	return "de" if side == "uk" else "uk"


static func side_zones(side: String) -> Array:
	return UK_SIDE if side == "uk" else DE_SIDE


static func enemy_side_zones(side: String) -> Array:
	return DE_SIDE if side == "uk" else UK_SIDE


static func own_zone1(side: String) -> String:
	return "uk1" if side == "uk" else "de1"


static func own_trench(side: String) -> String:
	return "ukTrench" if side == "uk" else "deTrench"


static func enemy_trench(side: String) -> String:
	return "deTrench" if side == "uk" else "ukTrench"


static func forward_path(side: String) -> Array:
	if side == "uk":
		return ["ukTrench", "uk1", "uk2", "uk3", "obj", "de3", "de2", "de1", "deTrench"]
	return ["deTrench", "de1", "de2", "de3", "obj", "uk3", "uk2", "uk1", "ukTrench"]


static func step_zone(side: String, zone: String, direction: String) -> String:
	var path := forward_path(side)
	var index := path.find(zone)
	if index < 0:
		return ""
	var next := index + 1 if direction == "forward" else index - 1
	if next < 0 or next >= path.size():
		return ""
	return str(path[next])


static func zone_distance(a: String, b: String) -> int:
	var ia := BATTLEFIELD.find(a)
	var ib := BATTLEFIELD.find(b)
	if ia < 0 or ib < 0:
		return 99
	return absi(ia - ib)


static func is_battlefield(zone: String) -> bool:
	return BATTLEFIELD.has(zone)


static func label_side(side: String) -> String:
	return "Britain" if side == "uk" else "Germany"


static func zone_label(zone: String) -> String:
	return str(ZONE_LABELS.get(zone, zone))


static func face_label(face: String) -> String:
	return str(FACE_LABELS.get(face, face.capitalize() if face != "" else face))


static func cap_type(kind: String) -> String:
	if kind == "mg":
		return "Machine Gun"
	if kind == "mortar":
		return "Mortar"
	if kind == "tank":
		return "Tank"
	return kind


static func _uid(state: Dictionary, prefix: String) -> String:
	var number := int(state.get("next_id", 1))
	state["next_id"] = number + 1
	return "%s-%d" % [prefix, number]


static func next_seed(state: Dictionary) -> int:
	var seed := int(state.get("seed", 1)) & 0xFFFFFFFF
	seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
	state["seed"] = seed
	return seed


static func rng(state: Dictionary) -> float:
	return float(next_seed(state)) / float(0xFFFFFFFF)


static func roll_face(state: Dictionary, faces: Array) -> String:
	if faces.is_empty():
		return ""
	var roll := rng(state)
	var index := int(floor(roll * float(faces.size()))) % faces.size()
	return str(faces[index])


static func shuffle(state: Dictionary, items: Array) -> Array:
	var pile: Array = items.duplicate()
	var index := pile.size() - 1
	while index > 0:
		var roll := rng(state)
		var swap_at := int(floor(roll * float(index + 1)))
		if swap_at > index:
			swap_at = index
		var swap = pile[index]
		pile[index] = pile[swap_at]
		pile[swap_at] = swap
		index -= 1
	return pile


static func log_line(state: Dictionary, text: String) -> void:
	if not (state.get("log") is Array):
		state["log"] = []
	state["log"].push_front({"round": int(state.get("round", 1)), "text": text})
	if state["log"].size() > 80:
		state["log"].resize(80)


static func push_brief(state: Dictionary, text: String) -> void:
	if text == "":
		return
	if not (state.get("roundBrief") is Array):
		state["roundBrief"] = []
	var round_no := int(state.get("round", 1))
	for line in state["roundBrief"]:
		if int(line.get("round", 0)) == round_no and str(line.get("text", "")) == text:
			return
	state["roundBrief"].append({"round": round_no, "text": text})
	var kept: Array = []
	for line in state["roundBrief"]:
		if int(line.get("round", 0)) >= round_no - 1:
			kept.append(line)
	if kept.size() > 16:
		kept = kept.slice(kept.size() - 16)
	state["roundBrief"] = kept


static func push_fx(state: Dictionary, beat: Dictionary) -> void:
	if str(beat.get("kind", "")) == "":
		return
	if not (state.get("fx") is Array):
		state["fx"] = []
	var seq := int(state.get("fxSeq", 0)) + 1
	state["fxSeq"] = seq
	beat["id"] = seq
	state["fx"].append(beat)
	if state["fx"].size() > 48:
		state["fx"] = state["fx"].slice(state["fx"].size() - 48)


static func note_moved(state: Dictionary, side: String, id: String) -> void:
	var who: Dictionary = state["players"][side]
	if not (who.get("movedIds") is Array):
		who["movedIds"] = []
	if not who["movedIds"].has(id):
		who["movedIds"].append(id)


static func soldiers_in(state: Dictionary, zone: String, opts: Dictionary = {}) -> Array:
	var found: Array = []
	var want_side := str(opts.get("side", ""))
	var exposed = opts.get("exposed", null)
	var cover_id := str(opts.get("coverId", ""))
	var match_cover := bool(opts.get("matchCover", false))
	for soldier in state["soldiers"]:
		if str(soldier.get("loc", "")) != zone:
			continue
		if want_side != "" and str(soldier.get("owner", "")) != want_side:
			continue
		var dug := str(soldier.get("coverId", "")) != ""
		if exposed == true and dug:
			continue
		if exposed == false and not dug:
			continue
		if match_cover and str(soldier.get("coverId", "")) != cover_id:
			continue
		found.append(soldier)
	return found


static func units_in(state: Dictionary, zone: String, opts: Dictionary = {}) -> Array:
	var found: Array = []
	var want_side := str(opts.get("side", ""))
	var want_type := str(opts.get("type", ""))
	for unit in state["equipment"]:
		if str(unit.get("loc", "")) != zone:
			continue
		if want_side != "" and str(unit.get("owner", "")) != want_side:
			continue
		if want_type != "" and str(unit.get("type", "")) != want_type:
			continue
		found.append(unit)
	return found


static func covers_in(state: Dictionary, zone: String) -> Array:
	var found: Array = []
	for cover in state["covers"]:
		if str(cover.get("loc", "")) == zone and not bool(cover.get("destroyed", false)):
			found.append(cover)
	return found


static func control_value(state: Dictionary, zone: String, side: String) -> int:
	if not is_battlefield(zone):
		return 0
	var total := 0
	for soldier in soldiers_in(state, zone, {"side": side}):
		total += 2 if str(soldier.get("coverId", "")) != "" else 1
	for unit in units_in(state, zone, {"side": side}):
		if str(unit.get("type", "")) == "tank":
			continue
		if int(unit.get("damage", 0)) >= 1:
			continue
		total += 2
	return total


static func is_contested(state: Dictionary, zone: String) -> bool:
	for unit in units_in(state, zone):
		if str(unit.get("type", "")) == "tank":
			return true
	return false


static func controller_of(state: Dictionary, zone: String) -> String:
	if not is_battlefield(zone) or is_contested(state, zone):
		return ""
	var britain := control_value(state, zone, "uk")
	var germany := control_value(state, zone, "de")
	if britain > germany:
		return "uk"
	if germany > britain:
		return "de"
	return ""


static func refresh_control(state: Dictionary, opts: Dictionary = {}) -> void:
	var before := {}
	var contested := {}
	for zone in BATTLEFIELD:
		before[zone] = controller_of(state, zone)
		contested[zone] = is_contested(state, zone)
	for zone in BATTLEFIELD:
		var now := "" if contested[zone] else str(before[zone])
		var prev := str(state["control"].get(zone, ""))
		if now != "" and now != prev:
			var gained_because_tank := bool(opts.get("tankLeft", false)) and bool(state["hadTank"].get(zone, false))
			if not gained_because_tank:
				var last := str(state["territoryOwner"].get(zone, ""))
				if last != now:
					if zone == "obj":
						state["vp"][now] = int(state["vp"][now]) + 2
						log_line(state, "%s gains the Objective Zone (+2 VP)." % label_side(now))
					elif enemy_side_zones(now).has(zone):
						state["vp"][now] = int(state["vp"][now]) + 1
						log_line(state, "%s takes %s (+1 VP)." % [label_side(now), zone_label(zone)])
					state["territoryOwner"][zone] = now
		state["control"][zone] = now
		state["hadTank"][zone] = contested[zone]


static func smoked(state: Dictionary, origin: String, dest: String) -> bool:
	if origin == "" or dest == "" or origin == dest:
		return false
	var smoke: Array = state.get("effects", {}).get("smoke", [])
	return smoke.has(origin) or smoke.has(dest)


static func can_soldier_target(soldier: Dictionary, target: Dictionary) -> bool:
	if str(target.get("kind", "")) == "tank":
		return str(soldier.get("loc", "")) == str(target.get("zone", ""))
	return zone_distance(str(soldier.get("loc", "")), str(target.get("zone", ""))) <= 1


static func soldier_may_fire(soldier: Dictionary, attacked: Array) -> bool:
	if soldier.is_empty() or str(soldier.get("type", "")) != "":
		return false
	if not is_battlefield(str(soldier.get("loc", ""))):
		return false
	return not attacked.has(soldier.get("id"))


static func soldier_strike_targets(state: Dictionary, side: String, zone: String) -> Array:
	if not is_battlefield(zone):
		return []
	var foe := other(side)
	var targets: Array = []
	if not soldiers_in(state, zone, {"side": foe, "exposed": true}).is_empty():
		targets.append({"kind": "exposed", "zone": zone})
	for cover in covers_in(state, zone):
		var inside := soldiers_in(state, zone, {"matchCover": true, "coverId": cover.get("id")})
		for soldier in inside:
			if str(soldier.get("owner", "")) == foe:
				targets.append({"kind": "cover", "zone": zone, "coverId": cover.get("id")})
				break
	return targets


static func machine_gun_operational(state: Dictionary, unit: Dictionary) -> bool:
	if unit.is_empty() or str(unit.get("type", "")) != "mg":
		return false
	if not is_battlefield(str(unit.get("loc", ""))) or int(unit.get("damage", 0)) >= 1:
		return false
	var who: Dictionary = state["players"][unit["owner"]]
	if who["attackedIds"].has(unit["id"]) or who["movedEquip"].has(unit["id"]):
		return false
	var effects: Dictionary = state["effects"]
	if str(effects.get("suppression", "")) == "mg" and str(unit.get("owner", "")) != str(effects.get("suppressionBy", "")):
		return false
	return true


static func machine_gun_targets(state: Dictionary, unit: Dictionary) -> Array:
	if unit.is_empty() or str(unit.get("type", "")) != "mg" or not is_battlefield(str(unit.get("loc", ""))):
		return []
	var foe := other(str(unit.get("owner", "")))
	var targets: Array = []
	for zone in BATTLEFIELD:
		var dist := zone_distance(str(unit.get("loc", "")), zone)
		if dist > 2:
			continue
		if smoked(state, str(unit.get("loc", "")), zone):
			continue
		if not soldiers_in(state, zone, {"side": foe, "exposed": true}).is_empty():
			targets.append({"kind": "exposed", "zone": zone, "dist": dist})
		for cover in covers_in(state, zone):
			var inside := soldiers_in(state, zone, {"matchCover": true, "coverId": cover.get("id")})
			var enemy_inside := false
			for soldier in inside:
				if str(soldier.get("owner", "")) == foe:
					enemy_inside = true
					break
			if enemy_inside:
				targets.append({"kind": "cover", "zone": zone, "coverId": cover.get("id"), "dist": dist})
			elif inside.is_empty():
				targets.append({"kind": "cover-empty", "zone": zone, "coverId": cover.get("id"), "dist": dist})
		for gear in units_in(state, zone, {"side": foe}):
			var gear_type := str(gear.get("type", ""))
			if gear_type == "mg" or gear_type == "mortar":
				targets.append({"kind": gear_type, "zone": zone, "unitId": gear.get("id"), "dist": dist})
	return targets


static func roll_action_die(state: Dictionary) -> String:
	return roll_face(state, ACTION_FACES)


static func roll_attack_die(state: Dictionary) -> String:
	return roll_face(state, ATTACK_FACES)


static func roll_mortar_die(state: Dictionary) -> String:
	return roll_face(state, MORTAR_FACES)


static func roll_all_action(state: Dictionary, side: String) -> void:
	var faces: Array = []
	for _i in 5:
		faces.append(roll_action_die(state))
	state["players"][side]["dice"] = faces
	state["players"][side]["kept"] = [true, true, true, true, true]


static func reroll_kept(state: Dictionary, side: String, keep: Array) -> void:
	var who: Dictionary = state["players"][side]
	var next: Array = []
	for index in who["dice"].size():
		if index < keep.size() and bool(keep[index]):
			next.append(who["dice"][index])
		else:
			next.append(roll_action_die(state))
	who["dice"] = next
	who["rollsUsed"] = int(who.get("rollsUsed", 1)) + 1
	who["kept"] = [true, true, true, true, true]


static func natural_faces(dice: Array) -> Array:
	var faces: Array = []
	for face in dice:
		var name := str(face) if face != null else ""
		if name != "" and name != "wild":
			faces.append(name)
	return faces


static func has_wild_face(dice: Array) -> bool:
	return dice.has("wild")


static func _kind_before(a, b) -> bool:
	if int(a[1]) != int(b[1]):
		return int(a[1]) > int(b[1])
	return int(SYMBOL_RANK.get(a[0], 0)) > int(SYMBOL_RANK.get(b[0], 0))


static func combo_of(dice: Array) -> Dictionary:
	var natural := natural_faces(dice)
	var counts := {}
	for face in natural:
		counts[face] = int(counts.get(face, 0)) + 1
	var vals: Array = []
	for face in counts.keys():
		vals.append(int(counts[face]))
	vals.sort()
	vals.reverse()
	var kinds: Array = []
	for face in counts.keys():
		kinds.append([face, int(counts[face])])
	kinds.sort_custom(_kind_before)
	var symbols: Array = []
	for pair in kinds:
		symbols.append(pair[0])
	var top := int(vals[0]) if not vals.is_empty() else 0
	var second := int(vals[1]) if vals.size() > 1 else 0
	var combo := "none"
	if top >= 5:
		combo = "five"
	elif top == 4:
		combo = "four"
	elif top == 3 and second == 2:
		combo = "fullHouse"
	elif top == 3:
		combo = "three"
	elif top == 2 and second == 2:
		combo = "twoPair"
	elif top == 2:
		combo = "pair"
	return {"type": combo, "rank": int(COMBO_RANK[combo]), "symbols": symbols, "counts": counts}


static func _best_rank(dice: Array) -> int:
	var best := 0
	for face in natural_faces(dice):
		best = maxi(best, int(SYMBOL_RANK.get(face, 0)))
	return best


static func compare_initiative(a_dice: Array, b_dice: Array) -> int:
	var a := combo_of(a_dice)
	var b := combo_of(b_dice)
	if int(a["rank"]) != int(b["rank"]):
		return int(a["rank"]) - int(b["rank"])
	var length := maxi(a["symbols"].size(), b["symbols"].size())
	for index in length:
		var ar := int(SYMBOL_RANK.get(a["symbols"][index], 0)) if index < a["symbols"].size() else 0
		var br := int(SYMBOL_RANK.get(b["symbols"][index], 0)) if index < b["symbols"].size() else 0
		if ar != br:
			return ar - br
	return _best_rank(a_dice) - _best_rank(b_dice)


static func combo_label(dice: Array) -> String:
	if dice.is_empty():
		return ""
	var combo := combo_of(dice)
	var name := str(COMBO_NAMES.get(combo["type"], "No combination"))
	var symbols: Array = combo["symbols"]
	var lead := str(symbols[0]) if not symbols.is_empty() else ""
	if combo["type"] == "none":
		return "High %s" % face_label(lead) if lead != "" else "No combination"
	if combo["type"] == "fullHouse" and symbols.size() > 1:
		return "Full House (%s over %s)" % [face_label(lead), face_label(str(symbols[1]))]
	if combo["type"] == "twoPair" and symbols.size() > 1:
		return "Two Pairs (%s and %s)" % [face_label(lead), face_label(str(symbols[1]))]
	if lead != "":
		return "%s (%s)" % [name, face_label(lead)]
	return name


static func lock_initiative(state: Dictionary, tie_rolls: int = 0) -> Dictionary:
	var britain: Array = state["players"]["uk"]["dice"].duplicate()
	var germany: Array = state["players"]["de"]["dice"].duplicate()
	var cmp := compare_initiative(britain, germany)
	if cmp == 0:
		return {}
	var winner := "uk" if cmp > 0 else "de"
	state["initiative"] = {
		"winner": winner,
		"tieRolls": tie_rolls,
		"uk": {"dice": britain, "label": combo_label(britain)},
		"de": {"dice": germany, "label": combo_label(germany)},
	}
	return state["initiative"]


static func spendable(state: Dictionary, side: String) -> Dictionary:
	var counts := {"boot": 0, "shovel": 0, "bayonet": 0, "whistle": 0, "wild": 0}
	var who: Dictionary = state["players"][side]
	if not bool(who.get("committed", false)):
		return counts
	for face in who["dice"]:
		var name := str(face) if face != null else ""
		if name == "wild":
			if str(who.get("wildAs", "")) != "":
				var wild_as := str(who["wildAs"])
				counts[wild_as] = int(counts.get(wild_as, 0)) + 1
		elif name != "":
			counts[name] = int(counts.get(name, 0)) + 1
	var stolen = state["effects"].get("stolenDie", null)
	if stolen is Dictionary and str(stolen.get("owner", "")) == side:
		var stolen_face := str(stolen.get("face", ""))
		if stolen_face == "wild" and str(who.get("wildAs", "")) != "":
			var wild_as := str(who["wildAs"])
			counts[wild_as] = int(counts.get(wild_as, 0)) + 1
		elif stolen_face != "" and stolen_face != "wild":
			counts[stolen_face] = int(counts.get(stolen_face, 0)) + 1
	return counts


static func spend(state: Dictionary, side: String, face: String, count: int = 1) -> void:
	var who: Dictionary = state["players"][side]
	if not (who.get("spent") is Dictionary):
		who["spent"] = {"boot": 0, "shovel": 0, "bayonet": 0, "whistle": 0}
	who["spent"][face] = int(who["spent"].get(face, 0)) + count


static func remaining(state: Dictionary, side: String, face: String) -> int:
	return int(spendable(state, side).get(face, 0)) - int(state["players"][side]["spent"].get(face, 0))


static func spend_selected(state: Dictionary, side: String, face: String, indexes: Array) -> String:
	var who: Dictionary = state["players"][side]
	if not (who.get("spent") is Dictionary):
		who["spent"] = {"boot": 0, "shovel": 0, "bayonet": 0, "whistle": 0}
	if not (who.get("spentDice") is Array):
		who["spentDice"] = []
	var picked: Array = []
	for raw in indexes:
		var index := int(raw)
		if index < 0 or index >= who["dice"].size():
			return "That die cannot be spent."
		if picked.has(index) or who["spentDice"].has(index):
			return "That die is already spent."
		var raw_face := str(who["dice"][index]) if who["dice"][index] != null else ""
		var effective := str(who.get("wildAs", "")) if raw_face == "wild" else raw_face
		if effective != face:
			return "Select bayonet dice."
		picked.append(index)
	if remaining(state, side, face) < picked.size():
		var word := "Bayonet" if picked.size() == 1 else "Bayonets"
		return "Need %d %s." % [picked.size(), word]
	for index in picked:
		who["spentDice"].append(index)
	who["spent"][face] = int(who["spent"].get(face, 0)) + picked.size()
	return ""


static func assign_wilds(state: Dictionary, side: String, symbol: String) -> bool:
	var who: Dictionary = state["players"][side]
	if not natural_faces(who["dice"]).has(symbol):
		return false
	who["wildAs"] = symbol
	return true


static func auto_assign_wilds(state: Dictionary, side: String) -> void:
	var who: Dictionary = state["players"][side]
	var natural := natural_faces(who["dice"])
	if natural.is_empty():
		who["wildAs"] = null
		return
	var counts := {}
	for face in natural:
		counts[face] = int(counts.get(face, 0)) + 1
	var best := ""
	var best_count := -1
	var best_rank := -1
	for face in counts.keys():
		var count := int(counts[face])
		var rank := int(SYMBOL_RANK.get(face, 0))
		if count > best_count or (count == best_count and rank > best_rank):
			best = str(face)
			best_count = count
			best_rank = rank
	who["wildAs"] = best


static func has_shock(state: Dictionary, side: String) -> bool:
	var who: Dictionary = state["players"][side]
	if not bool(who.get("committed", false)):
		return false
	var faces: Array = []
	for face in who["dice"]:
		var name := str(face) if face != null else ""
		faces.append(str(who.get("wildAs", "")) if name == "wild" else name)
	if faces.is_empty():
		return false
	for face in faces:
		if str(face) == "":
			return false
	var first := str(faces[0])
	for face in faces:
		if str(face) != first:
			return false
	return who["dice"].has(first)


static func describe_pool(who: Dictionary) -> String:
	var parts: Array = []
	for face in who["dice"]:
		var name := str(face) if face != null else ""
		if name == "":
			continue
		if name == "wild" and str(who.get("wildAs", "")) != "":
			parts.append(face_label(str(who["wildAs"])))
		else:
			parts.append(face_label(name))
	return ", ".join(parts)


static func commit_dice(state: Dictionary, side: String, wild_as = null) -> void:
	var who: Dictionary = state["players"][side]
	if wild_as != null and str(wild_as) != "":
		assign_wilds(state, side, str(wild_as))
	else:
		auto_assign_wilds(state, side)
	who["committed"] = true
	who["spent"] = {"boot": 0, "shovel": 0, "bayonet": 0, "whistle": 0}
	who["spentDice"] = []
	log_line(state, "%s commits %s." % [label_side(side), describe_pool(who)])


static func roll_hits(state: Dictionary, count: int) -> Dictionary:
	var faces: Array = []
	var hits := 0
	for _i in maxi(0, count):
		var face := roll_attack_die(state)
		faces.append(face)
		if face == "hit":
			hits += 1
	state["lastRoll"] = {"kind": "attack", "faces": faces, "hits": hits}
	return {"faces": faces, "hits": hits}


static func unused_dice(state: Dictionary, side: String) -> int:
	var total := 0
	for face in ["boot", "shovel", "bayonet", "whistle"]:
		total += maxi(0, remaining(state, side, face))
	return total


static func can_regroup(state: Dictionary, side: String) -> bool:
	var who: Dictionary = state["players"][side]
	var trench := soldiers_in_loc(state, side, own_trench(side))
	var available := not soldiers_in_loc_list(state, side, "available").is_empty()
	var can_exchange := int(who.get("regroupExchanged", 0)) < 2 and unused_dice(state, side) > 0 and trench < 5 and available
	var can_draw := not bool(who.get("regroupDrew", false)) and who["eventHand"].size() < 7 and (not state["eventDisplay"].is_empty() or not state["eventDeck"].is_empty())
	return can_exchange or can_draw


static func soldiers_in_loc(state: Dictionary, side: String, loc: String) -> int:
	var count := 0
	for soldier in state["soldiers"]:
		if str(soldier.get("owner", "")) == side and str(soldier.get("loc", "")) == loc:
			count += 1
	return count


static func soldiers_in_loc_list(state: Dictionary, side: String, loc: String) -> Array:
	var found: Array = []
	for soldier in state["soldiers"]:
		if str(soldier.get("owner", "")) == side and str(soldier.get("loc", "")) == loc:
			found.append(soldier)
	return found


static func find_by_id(items: Array, id: String) -> Dictionary:
	for item in items:
		if str(item.get("id", "")) == id or str(item.get("inst", "")) == id:
			return item
	return {}


static func eliminate_soldier(state: Dictionary, soldier: Dictionary) -> void:
	var zone := str(soldier.get("loc", ""))
	soldier["coverId"] = null
	soldier["loc"] = "casualties"
	push_fx(state, {"kind": "elim", "soldierId": soldier.get("id"), "owner": soldier.get("owner"), "zone": zone})
	log_line(state, "%s Soldier is eliminated." % label_side(str(soldier.get("owner", ""))))


static func take_cover_trophy(state: Dictionary, side: String, cover: Dictionary) -> void:
	push_fx(state, {"kind": "cover", "coverId": cover.get("id"), "zone": cover.get("loc"), "defense": cover.get("defense")})
	cover["destroyed"] = true
	cover["loc"] = "trophy"
	cover["trophyOwner"] = side
	state["players"][side]["destroyedCover"].append(cover.get("id"))
	log_line(state, "%s destroys Cover (Defense %s)." % [label_side(side), str(cover.get("defense", ""))])


static func damage_equipment(state: Dictionary, side: String, unit: Dictionary, hits: int) -> void:
	var cap := 3 if str(unit.get("type", "")) == "tank" else 2
	unit["damage"] = int(unit.get("damage", 0)) + hits
	log_line(state, "%s takes %d Damage (now %d)." % [cap_type(str(unit.get("type", ""))), hits, mini(int(unit["damage"]), cap)])
	if int(unit["damage"]) >= cap:
		log_line(state, "%s %s is destroyed." % [label_side(str(unit.get("owner", ""))), cap_type(str(unit.get("type", "")))])
		if str(unit.get("type", "")) == "mg" or str(unit.get("type", "")) == "mortar":
			state["roundSupportKill"][side] = true
		if str(unit.get("type", "")) == "tank":
			state["roundTankKill"][side] = true
		unit["loc"] = "supply"
		unit["damage"] = 0


static func note_elim(state: Dictionary, side: String, count: int) -> void:
	state["roundElim"][side] = int(state["roundElim"].get(side, 0)) + count
	if count >= 3:
		state["roundBurst"][side] = true


static func reveal_cover(state: Dictionary, cover: Dictionary) -> void:
	if cover.is_empty() or bool(cover.get("revealed", false)):
		return
	cover["revealed"] = true
	log_line(state, "Cover Defense %s revealed." % str(cover.get("defense", "")))


static func reveal_attacked_cover(state: Dictionary, target: Dictionary) -> void:
	var kind := str(target.get("kind", ""))
	if kind != "cover" and kind != "cover-empty":
		return
	reveal_cover(state, find_by_id(state["covers"], str(target.get("coverId", ""))))


static func _free_cover(state: Dictionary, cover: Dictionary) -> void:
	for soldier in state["soldiers"]:
		if str(soldier.get("coverId", "")) == str(cover.get("id", "")):
			soldier["coverId"] = null


static func _destroy_cover(state: Dictionary, side: String, cover: Dictionary) -> void:
	_free_cover(state, cover)
	take_cover_trophy(state, side, cover)


static func apply_hits(state: Dictionary, side: String, target: Dictionary, hits: int) -> void:
	var foe := other(side)
	var kind := str(target.get("kind", ""))
	if kind == "exposed":
		var list := soldiers_in(state, str(target.get("zone", "")), {"side": foe, "exposed": true})
		var count := mini(hits, list.size())
		for index in count:
			eliminate_soldier(state, list[index])
		note_elim(state, side, count)
		if hits > 0 and count == 0:
			log_line(state, "No exposed soldiers there.")
		return
	if kind == "cover" or kind == "cover-empty":
		var cover := find_by_id(state["covers"], str(target.get("coverId", "")))
		if cover.is_empty():
			return
		reveal_cover(state, cover)
		if kind == "cover-empty":
			if hits >= int(cover.get("defense", 0)):
				_destroy_cover(state, side, cover)
			else:
				log_line(state, "Cover holds. %d Hit(s) did not meet Defense %s." % [hits, str(cover.get("defense", ""))])
			return
		var defense := int(cover.get("defense", 0))
		var against := mini(maxi(0, hits), defense)
		var leftover := maxi(0, hits - defense)
		var occupants := soldiers_in(state, str(cover.get("loc", "")), {"side": foe, "matchCover": true, "coverId": cover.get("id")})
		var count := mini(leftover, occupants.size())
		for index in count:
			eliminate_soldier(state, occupants[index])
		note_elim(state, side, count)
		if against >= defense:
			_destroy_cover(state, side, cover)
		elif count == 0:
			log_line(state, "Cover absorbs the fire (%d Hit(s), Defense %d)." % [hits, defense])
		return
	if kind == "mg" or kind == "mortar" or kind == "tank":
		var unit := find_by_id(state["equipment"], str(target.get("unitId", "")))
		if unit.is_empty():
			return
		damage_equipment(state, side, unit, hits)
		return
	if kind == "allocate":
		log_line(state, "%d Hit(s) in %s." % [hits, zone_label(str(target.get("zone", "")))])
		apply_hits(state, side, {"kind": "exposed", "zone": target.get("zone")}, hits)


static func _soldier_rows(soldiers: Array) -> Array:
	var rows: Array = []
	for soldier in soldiers:
		var dug := " · in cover" if str(soldier.get("coverId", "")) != "" else ""
		var nation := "British" if str(soldier.get("owner", "")) == "uk" else "German"
		rows.append({
			"id": soldier.get("id"),
			"kind": "soldier",
			"soldierId": soldier.get("id"),
			"zone": soldier.get("loc"),
			"coverId": soldier.get("coverId"),
			"label": "%s Soldier · %s%s" % [nation, zone_label(str(soldier.get("loc", ""))), dug],
		})
	var totals := {}
	for row in rows:
		totals[row["label"]] = int(totals.get(row["label"], 0)) + 1
	var seen := {}
	var numbered: Array = []
	for row in rows:
		if int(totals[row["label"]]) < 2:
			numbered.append(row)
			continue
		seen[row["label"]] = int(seen.get(row["label"], 0)) + 1
		var copy: Dictionary = row.duplicate()
		copy["label"] = str(row["label"]).replace(" Soldier · ", " Soldier %d · " % int(seen[row["label"]]))
		numbered.append(copy)
	return numbered


static func allocation_options(state: Dictionary, side: String, target: Dictionary) -> Array:
	var foe := other(side)
	var zone := str(target.get("zone", ""))
	var kind := str(target.get("kind", ""))
	if zone == "" or kind == "":
		return []
	if kind == "exposed":
		return _soldier_rows(soldiers_in(state, zone, {"side": foe, "exposed": true}))
	if kind == "cover":
		return _soldier_rows(soldiers_in(state, zone, {"side": foe, "matchCover": true, "coverId": target.get("coverId")}))
	if kind == "cover-empty":
		var cover := find_by_id(state["covers"], str(target.get("coverId", "")))
		if cover.is_empty() or bool(cover.get("destroyed", false)):
			return []
		var defense := " · defense %s" % str(cover.get("defense", "")) if bool(cover.get("revealed", false)) else ""
		return [{
			"id": cover.get("id"),
			"kind": "cover-empty",
			"coverId": cover.get("id"),
			"zone": zone,
			"label": "Empty cover · %s%s" % [zone_label(zone), defense],
		}]
	if kind == "mg" or kind == "mortar" or kind == "tank":
		var unit := find_by_id(state["equipment"], str(target.get("unitId", "")))
		if unit.is_empty() or str(unit.get("loc", "")) != zone:
			return []
		var nation := "British" if str(unit.get("owner", "")) == "uk" else "German"
		return [{
			"id": unit.get("id"),
			"kind": unit.get("type"),
			"unitId": unit.get("id"),
			"zone": zone,
			"label": "%s %s · %s" % [nation, cap_type(str(unit.get("type", ""))), zone_label(zone)],
		}]
	return []


static func allocation_ready(pending: Dictionary, picks: Array) -> bool:
	if str(pending.get("type", "")) != "allocate-hits":
		return false
	var options: Array = pending.get("options", [])
	var known: Array = []
	for option in options:
		known.append(option.get("id"))
	for pick in picks:
		if not known.has(pick):
			return false
	if picks.size() > int(pending.get("hits", 0)):
		return false
	if picks.size() == int(pending.get("hits", 0)):
		return true
	if str(pending.get("target", {}).get("kind", "")) != "exposed":
		return false
	var counts := {}
	for pick in picks:
		counts[pick] = int(counts.get(pick, 0)) + 1
	for option in options:
		if int(counts.get(option.get("id"), 0)) < 1:
			return false
	return true


static func apply_allocated_hits(state: Dictionary, side: String, target: Dictionary, picks: Array, rolled_hits: int) -> void:
	var allowed: Array = []
	for option in allocation_options(state, side, target):
		allowed.append(option.get("id"))
	var hits: Array = []
	for pick in picks:
		if allowed.has(pick):
			hits.append(pick)
	var kind := str(target.get("kind", ""))
	if kind == "exposed":
		var count := 0
		for id in hits:
			var soldier := find_by_id(state["soldiers"], str(id))
			if soldier.is_empty() or str(soldier.get("loc", "")) != str(target.get("zone", "")) or str(soldier.get("coverId", "")) != "":
				continue
			eliminate_soldier(state, soldier)
			count += 1
		note_elim(state, side, count)
		if rolled_hits > 0 and count == 0:
			log_line(state, "No exposed soldiers there.")
		return
	if kind == "cover":
		var cover := find_by_id(state["covers"], str(target.get("coverId", "")))
		if cover.is_empty() or bool(cover.get("destroyed", false)):
			return
		reveal_cover(state, cover)
		var shield := int(cover.get("defense", 0))
		var defense := shield
		var against := 0
		var count := 0
		for id in hits:
			if shield > 0:
				shield -= 1
				against += 1
				continue
			var soldier := find_by_id(state["soldiers"], str(id))
			if soldier.is_empty() or str(soldier.get("coverId", "")) != str(cover.get("id", "")):
				continue
			eliminate_soldier(state, soldier)
			count += 1
		note_elim(state, side, count)
		if against >= defense:
			_destroy_cover(state, side, cover)
		elif count == 0:
			log_line(state, "Cover absorbs the fire (%d Hit(s), Defense %d)." % [rolled_hits, defense])
		return
	if kind == "cover-empty" or kind == "mg" or kind == "mortar" or kind == "tank":
		apply_hits(state, side, target, hits.size())


static func draw_mission(state: Dictionary, required: bool):
	if state["missionDeck"].is_empty():
		if required:
			state["missionExhausted"] = true
			log_line(state, "Mission Exhaustion — no Mission remains to draw.")
		return null
	return state["missionDeck"].pop_front()


static func trim_missions(state: Dictionary, side: String) -> void:
	var hand: Array = state["players"][side]["missionHand"]
	while hand.size() > 5:
		state["missionDeck"].append(hand.pop_back())


static func _mission_taken(state: Dictionary, side: String) -> bool:
	return bool(state.get("roundMissions", {}).get(side, false))


static func _side_chooses(state: Dictionary, side: String) -> bool:
	if str(state.get("mode", "")) == "sim":
		return false
	if str(state.get("mode", "")) == "hotseat":
		return true
	return side == str(state.get("human", ""))


static func _highest_mission(ready: Array) -> Dictionary:
	var best: Dictionary = ready[0]
	for mission in ready:
		if int(mission.get("vp", 0)) > int(best.get("vp", 0)):
			best = mission
	return best


static func is_mission_complete(state: Dictionary, side: String, mission: Dictionary, ctx: Dictionary) -> bool:
	var title := str(mission.get("title", ""))
	if title == "Hold in Cover":
		return controller_of(state, "obj") == side and not soldiers_in(state, "obj", {"side": side, "exposed": false}).is_empty()
	if title == "Over the Top":
		var count := soldiers_in(state, "obj", {"side": side}).size()
		for zone in enemy_side_zones(side):
			count += soldiers_in(state, zone, {"side": side}).size()
		return count >= 3
	if title == "Guns Silenced":
		return str(mission.get("type", "")) == "EVENT" and str(ctx.get("timing", "")) == "combat" and bool(state["roundSupportKill"].get(side, false))
	if title == "Tank Hunter":
		return str(mission.get("type", "")) == "EVENT" and str(ctx.get("timing", "")) == "combat" and bool(state["roundTankKill"].get(side, false))
	if title == "No Shelter":
		return state["players"][side]["destroyedCover"].size() >= 3
	if title == "Deep Push":
		var held := 0
		for zone in enemy_side_zones(side):
			if controller_of(state, zone) == side:
				held += 1
		return held >= 2
	if title == "Shock Action":
		return str(mission.get("type", "")) == "EVENT" and str(ctx.get("timing", "")) == "combat" and bool(state["roundBurst"].get(side, false))
	if title == "In the Wire":
		for zone in enemy_side_zones(side):
			if soldiers_in(state, zone, {"side": side}).size() >= 4:
				return true
		return false
	if title == "Dug In":
		if str(mission.get("type", "")) != "STATE" or str(ctx.get("timing", "")) != "end":
			return false
		var dug := 0
		for zone in BATTLEFIELD:
			dug += soldiers_in(state, zone, {"side": side, "exposed": false}).size()
		return dug >= 3
	if title == "Breakthrough":
		if str(mission.get("type", "")) != "STATE" or str(ctx.get("timing", "")) != "end":
			return false
		if controller_of(state, "obj") != side:
			return false
		for zone in enemy_side_zones(side):
			if controller_of(state, zone) == side:
				return true
		return false
	if title == "Attrition":
		return str(mission.get("type", "")) == "EVENT" and (str(ctx.get("timing", "")) == "combat" or str(ctx.get("timing", "")) == "immediate") and int(state["roundElim"].get(side, 0)) >= 5
	return false


static func _complete_mission(state: Dictionary, side: String, mission: Dictionary) -> void:
	if _mission_taken(state, side):
		return
	state["roundMissions"][side] = true
	state["vp"][side] = int(state["vp"][side]) + int(mission.get("vp", 0))
	var who: Dictionary = state["players"][side]
	var kept: Array = []
	for card in who["missionHand"]:
		if str(card.get("inst", "")) != str(mission.get("inst", "")):
			kept.append(card)
	who["missionHand"] = kept
	who["completedMissions"].append(mission)
	if not (state.get("missionPulse") is Array):
		state["missionPulse"] = []
	state["missionPulse"].append({"side": side, "inst": mission.get("inst"), "title": mission.get("title"), "vp": mission.get("vp")})
	var text := "%s completes %s (+%s VP)." % [label_side(side), str(mission.get("title", "")), str(mission.get("vp", 0))]
	log_line(state, text)
	push_brief(state, text)
	var replacement = draw_mission(state, true)
	if replacement != null:
		who["missionHand"].append(replacement)
		check_missions(state, side, {"timing": "immediate"})


static func check_missions(state: Dictionary, side: String, ctx: Dictionary = {}) -> String:
	if str(state.get("pending", {}).get("type", "")) == "pick-mission":
		return "choose"
	if _mission_taken(state, side):
		return "none"
	var ready: Array = []
	for mission in state["players"][side]["missionHand"]:
		if is_mission_complete(state, side, mission, ctx):
			ready.append(mission)
	if ready.is_empty():
		return "none"
	if ready.size() > 1 and _side_chooses(state, side):
		var insts: Array = []
		for mission in ready:
			insts.append(mission.get("inst"))
		state["pending"] = {
			"type": "pick-mission",
			"side": side,
			"insts": insts,
			"ctx": {"timing": ctx.get("timing", null)},
			"after": null,
		}
		return "choose"
	_complete_mission(state, side, ready[0] if ready.size() == 1 else _highest_mission(ready))
	return "done"


static func choose_mission(state: Dictionary, inst: String):
	var pending: Dictionary = state.get("pending", {})
	if str(pending.get("type", "")) != "pick-mission":
		return "No mission choice is waiting."
	var side := str(pending.get("side", ""))
	if _mission_taken(state, side):
		return "A mission is already complete this round."
	var mission := {}
	for card in state["players"][side]["missionHand"]:
		if str(card.get("inst", "")) == inst:
			mission = card
			break
	var allowed: Array = pending.get("insts", [])
	if mission.is_empty() or not allowed.has(mission.get("inst")):
		return "Choose one of those missions."
	if not is_mission_complete(state, side, mission, pending.get("ctx", {})):
		return "That mission is not complete."
	var after = pending.get("after", null)
	state["pending"] = null
	_complete_mission(state, side, mission)
	return after


static func preferred_mission_action(state: Dictionary) -> Dictionary:
	var pending: Dictionary = state.get("pending", {})
	if str(pending.get("type", "")) != "pick-mission":
		return {}
	var hand: Array = state["players"][pending.get("side", "")]["missionHand"]
	var options: Array = []
	for inst in pending.get("insts", []):
		for mission in hand:
			if str(mission.get("inst", "")) == str(inst):
				options.append(mission)
	if options.is_empty():
		return {}
	return {"type": "PICK_MISSION", "inst": _highest_mission(options).get("inst")}


static func _copy_card(definition: Dictionary, inst: String) -> Dictionary:
	var card: Dictionary = definition.duplicate(true)
	card["inst"] = inst
	if card.has("qty"):
		card["qty"] = int(card["qty"])
	if card.has("vp"):
		card["vp"] = int(card["vp"])
	if card.has("defense"):
		card["defense"] = int(card["defense"])
	return card


static func _empty_player(side: String) -> Dictionary:
	return {
		"side": side,
		"dice": [],
		"kept": [true, true, true, true, true],
		"rollsUsed": 1,
		"committed": false,
		"wildAs": null,
		"eventHand": [],
		"missionHand": [],
		"completedMissions": [],
		"destroyedCover": [],
		"generalsOrderUsed": false,
		"attackedIds": [],
		"movedIds": [],
		"movedEquip": [],
		"firedEquip": [],
		"spent": {"boot": 0, "shovel": 0, "bayonet": 0, "whistle": 0},
		"spentDice": [],
		"regroupDraws": 0,
		"regroupExchanged": 0,
		"regroupDrew": false,
		"soldierDeployed": false,
		"eventsAtStep": null,
		"movedTanks": [],
	}


static func empty_effects() -> Dictionary:
	return {
		"christmasTruce": false,
		"boggedDown": false,
		"trenchFoot": false,
		"cavalryCharge": null,
		"smoke": [],
		"suppression": null,
		"mobility": [],
		"precision": [],
		"spotter": [],
		"stolenDie": null,
		"boggedDownBy": null,
		"trenchFootBy": null,
		"suppressionBy": null,
	}


static func _blank_map() -> Dictionary:
	var mapped := {}
	for zone in BATTLEFIELD:
		mapped[zone] = null
	return mapped


static func _build_soldiers(state: Dictionary) -> void:
	for side in ["uk", "de"]:
		for _i in 5:
			state["soldiers"].append({"id": _uid(state, "s"), "owner": side, "loc": own_zone1(side), "coverId": null})
		var zone2 := "uk2" if side == "uk" else "de2"
		for _i in 5:
			state["soldiers"].append({"id": _uid(state, "s"), "owner": side, "loc": zone2, "coverId": null})
		for _i in 3:
			state["soldiers"].append({"id": _uid(state, "s"), "owner": side, "loc": own_trench(side), "coverId": null})
		for _i in 12:
			state["soldiers"].append({"id": _uid(state, "s"), "owner": side, "loc": "available", "coverId": null})


static func _build_equipment(state: Dictionary) -> void:
	for side in ["uk", "de"]:
		for _n in 3:
			state["equipment"].append({"id": _uid(state, "mg"), "owner": side, "type": "mg", "loc": "supply", "damage": 0})
		for _n in 3:
			state["equipment"].append({"id": _uid(state, "mor"), "owner": side, "type": "mortar", "loc": "supply", "damage": 0})
		for _n in 3:
			state["equipment"].append({"id": _uid(state, "tk"), "owner": side, "type": "tank", "loc": "supply", "damage": 0})


static func _build_cover(state: Dictionary) -> void:
	var defenses: Array = [1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 4]
	var tokens: Array = []
	for defense in defenses:
		tokens.append({
			"id": _uid(state, "cv"),
			"defense": defense,
			"revealed": false,
			"loc": "supply",
			"destroyed": false,
			"trophyOwner": null,
		})
	state["coverSupply"] = shuffle(state, tokens)


static func _resolve_cover_zone(side: String, requested) -> String:
	if requested == null or str(requested) == "":
		return own_zone1(side)
	if not side_zones(side).has(str(requested)):
		return own_zone1(side)
	return str(requested)


static func _place_starting_cover(state: Dictionary, cover_zones: Dictionary) -> void:
	for side in ["uk", "de"]:
		if state["coverSupply"].is_empty():
			break
		var token: Dictionary = state["coverSupply"].pop_front()
		var zone := _resolve_cover_zone(side, cover_zones.get(side, null))
		token["loc"] = zone
		state["covers"].append(token)
		log_line(state, "%s places starting Cover in %s." % [label_side(side), zone_label(zone)])


static func _build_events(state: Dictionary, catalog: Array) -> void:
	var regular: Array = []
	var starters := {"Reinforce": [], "General's Order": [], "Patrol": [], "Charge": [], "other": []}
	for definition in catalog:
		var copies := int(definition.get("qty", 0))
		for _n in copies:
			var card := _copy_card(definition, _uid(state, "ev"))
			if bool(definition.get("starter", false)):
				var key := str(definition.get("title", ""))
				if not starters.has(key):
					key = "other"
				starters[key].append(card)
			else:
				regular.append(card)
	var shuffled: Array = shuffle(state, regular)
	for side in ["uk", "de"]:
		var hand: Array = []
		for key in ["Reinforce", "Reinforce", "General's Order", "Patrol", "Charge"]:
			if not starters[key].is_empty():
				hand.append(starters[key].pop_back())
		if not shuffled.is_empty():
			hand.append(shuffled.pop_back())
		if not shuffled.is_empty():
			hand.append(shuffled.pop_back())
		state["players"][side]["eventHand"] = hand
	state["eventDeck"] = shuffle(state, shuffled)
	var display: Array = []
	for _i in 3:
		if not state["eventDeck"].is_empty():
			display.append(state["eventDeck"].pop_back())
	state["eventDisplay"] = display


static func _build_missions(state: Dictionary, catalog: Array, spec: Dictionary) -> void:
	var deck: Array = []
	for definition in catalog:
		for _n in int(definition.get("qty", 0)):
			var card := _copy_card(definition, _uid(state, "ms"))
			card["scored"] = false
			deck.append(card)
	deck = shuffle(state, deck)
	var remove := int(spec.get("remove", 0))
	if remove > 0:
		deck = deck.slice(mini(remove, deck.size()))
	var take := int(spec.get("missions", deck.size()))
	state["missionDeck"] = deck.slice(0, mini(take, deck.size()))
	for side in ["uk", "de"]:
		var hand: Array = []
		if not state["missionDeck"].is_empty():
			hand.append(state["missionDeck"].pop_front())
		if not state["missionDeck"].is_empty():
			hand.append(state["missionDeck"].pop_front())
		state["players"][side]["missionHand"] = hand


static func begin_initiative(state: Dictionary) -> void:
	state["phase"] = "initiative"
	state["actionStep"] = null
	state["active"] = null
	state["player1"] = null
	state["initiative"] = null
	state["effects"] = empty_effects()
	state["regroupDone"] = {"uk": false, "de": false}
	state["roundMissions"] = {"uk": false, "de": false}
	for side in ["uk", "de"]:
		var who: Dictionary = state["players"][side]
		who["dice"] = []
		who["kept"] = [true, true, true, true, true]
		who["rollsUsed"] = 1
		who["committed"] = false
		who["wildAs"] = null
		who["generalsOrderUsed"] = false
		who["attackedIds"] = []
		who["movedIds"] = []
		who["movedEquip"] = []
		who["firedEquip"] = []
		who["spent"] = {"boot": 0, "shovel": 0, "bayonet": 0, "whistle": 0}
		who["spentDice"] = []
		who["regroupDraws"] = 0
		who["regroupExchanged"] = 0
		who["regroupDrew"] = false
		who["soldierDeployed"] = false
		who["eventsAtStep"] = null
		who["movedTanks"] = []
	state["pending"] = {"type": "roll1"}
	state["lastRoll"] = null


static func _difficulty(mode: String, value) -> Variant:
	if mode != "solo":
		return null
	var name := str(value) if value != null else ""
	if name == "Easy" or name == "Hard" or name == "Difficult":
		return name
	return "Hard"


static func create_game(events: Array, missions: Array, options: Dictionary = {}) -> Dictionary:
	var format := str(options.get("format", "standard"))
	if not FORMATS.has(format):
		format = "standard"
	var human := "de" if str(options.get("human", "uk")) == "de" else "uk"
	var mode := str(options.get("mode", "solo"))
	if mode != "hotseat" and mode != "sim":
		mode = "solo"
	var spec: Dictionary = FORMATS[format]
	var seed := int(options["seed"]) & 0xFFFFFFFF if options.get("seed", null) != null else (int(Time.get_unix_time_from_system() * 1000.0) & 0xFFFFFFFF)
	var state := {
		"format": format,
		"mode": mode,
		"maxRounds": int(spec["rounds"]),
		"round": 1,
		"seed": seed,
		"initialSeed": seed,
		"human": human,
		"ai": other(human),
		"difficulty": _difficulty(mode, options.get("difficulty", "Hard")),
		"phase": "setup",
		"actionStep": null,
		"active": null,
		"player1": null,
		"initiative": null,
		"vp": {"uk": 0, "de": 0},
		"control": _blank_map(),
		"territoryOwner": _blank_map(),
		"hadTank": {},
		"soldiers": [],
		"equipment": [],
		"covers": [],
		"coverSupply": [],
		"players": {"uk": _empty_player("uk"), "de": _empty_player("de")},
		"eventDeck": [],
		"eventDisplay": [],
		"eventDiscard": [],
		"missionDeck": [],
		"effects": empty_effects(),
		"combat": null,
		"pending": null,
		"regroupDone": {"uk": false, "de": false},
		"winner": null,
		"tiebreak": null,
		"log": [],
		"lastRoll": null,
		"error": null,
		"roundElim": {"uk": 0, "de": 0},
		"roundBurst": {"uk": false, "de": false},
		"roundSupportKill": {"uk": false, "de": false},
		"roundTankKill": {"uk": false, "de": false},
		"missionExhausted": false,
		"missionPulse": [],
		"killPulse": [],
		"roundBrief": [],
		"fx": [],
		"fxSeq": 0,
		"next_id": 1,
		"version": VERSION,
	}
	for zone in BATTLEFIELD:
		state["hadTank"][zone] = false
	_build_soldiers(state)
	_build_equipment(state)
	_build_cover(state)
	_build_events(state, events)
	_build_missions(state, missions, spec)
	var cover_zones: Dictionary = options.get("coverZones", {})
	_place_starting_cover(state, cover_zones)
	refresh_control(state)
	var who := label_side(human)
	var battle := str(FORMAT_NAMES.get(format, "Battle"))
	if mode == "hotseat":
		log_line(state, "%s — %d rounds. Pass-and-play." % [battle, int(spec["rounds"])])
	elif mode == "sim":
		log_line(state, "%s — %d rounds." % [battle, int(spec["rounds"])])
	else:
		log_line(state, "%s — %d rounds. You command %s. Headquarters: %s." % [battle, int(spec["rounds"]), who, str(state["difficulty"])])
	begin_initiative(state)
	return state


static func event_needs(title: String) -> Array:
	var table := {
		"Reinforce": [],
		"Patrol": ["zone", "soldiers"],
		"Charge": ["zone", "soldiers"],
		"Bayonet Charge": ["zone", "soldiers"],
		"Bogged Down": [],
		"Bombing Run": ["zone"],
		"Carrier Pigeon": [],
		"Cavalry Charge": [],
		"Christmas Truce": [],
		"Entrench": ["soldiers", "covers"],
		"Espionage": [],
		"Field Hospital": [],
		"Field Repairs": ["friendlyEquip"],
		"Heavy Barrage": ["enemyZone"],
		"Mobility": ["friendlyMortar"],
		"Precision Barrage": ["friendlyMortar"],
		"Raid": ["zone", "soldiers"],
		"Recon Flight": ["zone"],
		"Sabotage": ["enemyDie"],
		"Scout": ["enemyCover"],
		"Smoke Screen": ["zone"],
		"Sniper": ["enemySoldier"],
		"Spotter": ["friendlyMortar"],
		"Suppression": ["supportType"],
		"Trench Fever": ["zone"],
		"Trench Foot": [],
		"Armored Advance": ["friendlyTank"],
		"Tunnel": ["soldiers", "controlledZone"],
	}
	return table.get(title, []).duplicate()


static func discard_event(state: Dictionary, side: String, inst: String) -> void:
	var hand: Array = state["players"][side]["eventHand"]
	for index in hand.size():
		if str(hand[index].get("inst", "")) == inst:
			state["eventDiscard"].append(hand[index])
			hand.remove_at(index)
			return


static func _soldiers_by_id(state: Dictionary, side: String, ids: Array) -> Array:
	var found: Array = []
	for id in ids:
		for soldier in state["soldiers"]:
			if str(soldier.get("id", "")) == str(id) and str(soldier.get("owner", "")) == side:
				found.append(soldier)
				break
	return found


static func _foot_locked(state: Dictionary, side: String) -> bool:
	return bool(state["effects"].get("trenchFoot", false)) and side != str(state["effects"].get("trenchFootBy", ""))


static func bayonet_destinations(state: Dictionary, side: String, origin: String) -> Array:
	if not is_battlefield(origin) or controller_of(state, origin) != side:
		return []
	var found: Array = []
	for direction in ["forward", "back"]:
		var dest := step_zone(side, origin, direction)
		if dest != "" and is_battlefield(dest) and controller_of(state, dest) == other(side):
			found.append(dest)
	return found


static func play_event(state: Dictionary, side: String, card: Dictionary, params: Dictionary) -> String:
	var title := str(card.get("title", ""))
	if state["effects"].get("christmasTruce", false) and HOSTILE.has(title):
		return "Christmas Truce: that Event cannot cause casualties."
	log_line(state, "%s plays %s." % [label_side(side), title])
	return _resolve_event(state, side, title, params)


static func _move_group(state: Dictionary, side: String, params: Dictionary, maximum: int, allow_back: bool) -> String:
	if _foot_locked(state, side):
		return "Trench Foot prevents Soldier movement."
	var direction := str(params.get("dir", "forward"))
	if not allow_back and direction != "forward":
		return "Charge is forward only."
	var ids: Array = params.get("soldierIds", [])
	if ids.size() > maximum:
		ids = ids.slice(0, maximum)
	var group := _soldiers_by_id(state, side, ids)
	if group.is_empty():
		return "Choose soldiers for this Event."
	var origin := str(group[0].get("loc", ""))
	for soldier in group:
		if str(soldier.get("loc", "")) != origin:
			return "Choose soldiers in the same zone."
	if not is_battlefield(origin):
		return "Cannot move from the Trench with this Event."
	var dest := step_zone(side, origin, direction)
	if dest == "" or not is_battlefield(dest):
		return "Illegal destination."
	for soldier in group:
		soldier["coverId"] = null
		soldier["loc"] = dest
		note_moved(state, side, str(soldier.get("id", "")))
	log_line(state, "%d Soldier(s) move to %s." % [group.size(), zone_label(dest)])
	return ""


static func _reinforce(state: Dictionary, side: String) -> void:
	var avail := soldiers_in_loc_list(state, side, "available")
	var trench := own_trench(side)
	var room := 5 - soldiers_in_loc(state, side, trench)
	var count := 0
	for soldier in avail:
		if room <= 0 or count >= 3:
			break
		soldier["loc"] = trench
		room -= 1
		count += 1
	log_line(state, "%d Soldier(s) enter the Trench reinforcement area." % count)


static func _bayonet_charge(state: Dictionary, side: String, params: Dictionary) -> String:
	if _foot_locked(state, side):
		return "Trench Foot prevents Soldier movement."
	var ids: Array = params.get("soldierIds", [])
	if ids.size() > 3:
		ids = ids.slice(0, 3)
	var group := _soldiers_by_id(state, side, ids)
	if group.is_empty():
		return "Choose soldiers for Bayonet Charge."
	var origin := str(group[0].get("loc", ""))
	for soldier in group:
		if str(soldier.get("loc", "")) != origin:
			return "Choose soldiers in the same zone."
	var options := bayonet_destinations(state, side, origin)
	if options.is_empty():
		if not is_battlefield(origin) or controller_of(state, origin) != side:
			return "Must start in a friendly-controlled zone."
		return "Must charge into an adjacent enemy-controlled zone."
	var dest := ""
	var requested := str(params.get("zone", ""))
	if options.has(requested):
		dest = requested
	elif requested != "" and requested != origin and is_battlefield(requested):
		return "Must charge into an adjacent enemy-controlled zone."
	else:
		var forward := step_zone(side, origin, "forward")
		dest = forward if options.has(forward) else str(options[0])
	var charged: Array = []
	for soldier in group:
		charged.append(soldier.get("id"))
		soldier["coverId"] = null
		soldier["loc"] = dest
	push_fx(state, {"kind": "charge", "owner": side, "from": origin, "zone": dest, "soldierIds": charged})
	log_line(state, "%d Soldier(s) charge into %s." % [group.size(), zone_label(dest)])
	var first := roll_hits(state, group.size())
	var misses := 0
	for face in first["faces"]:
		if str(face) == "miss":
			misses += 1
	var reroll := roll_hits(state, misses)
	var total := int(first["hits"]) + int(reroll["hits"])
	log_line(state, "Bayonet Charge: %d dice, reroll misses -> %d Hit(s)." % [group.size(), total])
	apply_hits(state, side, {"kind": "exposed", "zone": dest}, total)
	for soldier in group:
		state["players"][side]["attackedIds"].append(soldier.get("id"))
	return ""


static func _bombing_run(state: Dictionary, side: String, params: Dictionary) -> String:
	var zone := str(params.get("zone", ""))
	if not is_battlefield(zone):
		return "Choose a battlefield zone."
	var targets := soldiers_in(state, zone, {"side": other(side)})
	var result := roll_hits(state, targets.size())
	log_line(state, "Bombing Run rolls %d dice -> %d Hit(s)." % [targets.size(), int(result["hits"])])
	var kind := str(params.get("targetKind", "exposed"))
	if kind == "":
		kind = "exposed"
	apply_hits(state, side, {"kind": kind, "zone": zone, "coverId": params.get("coverId", null), "unitId": params.get("unitId", null)}, int(result["hits"]))
	return ""


static func _entrench(state: Dictionary, side: String, params: Dictionary) -> String:
	var trench := own_trench(side)
	var ids: Array = params.get("soldierIds", [])
	if ids.size() > 3:
		ids = ids.slice(0, 3)
	var cover := find_by_id(state["covers"], str(params.get("coverId", "")))
	if cover.is_empty() or bool(cover.get("destroyed", false)):
		return "Choose a Cover position."
	if controller_of(state, str(cover.get("loc", ""))) != side:
		return "That Cover is not in a zone you control."
	var count := 0
	for id in ids:
		var soldier := {}
		for candidate in state["soldiers"]:
			if str(candidate.get("id", "")) == str(id) and str(candidate.get("owner", "")) == side and str(candidate.get("loc", "")) == trench:
				soldier = candidate
				break
		if soldier.is_empty():
			continue
		var occupants := soldiers_in(state, str(cover.get("loc", "")), {"matchCover": true, "coverId": cover.get("id")})
		var foreign := false
		for occupant in occupants:
			if str(occupant.get("owner", "")) != side:
				foreign = true
				break
		if occupants.size() >= 3 or foreign:
			continue
		soldier["loc"] = cover.get("loc")
		soldier["coverId"] = cover.get("id")
		count += 1
	if count == 0:
		return "No trench soldiers could enter that Cover."
	log_line(state, "%d Soldier(s) entrench." % count)
	refresh_control(state)
	return ""


static func _espionage(state: Dictionary, side: String) -> void:
	var foe_hand: Array = state["players"][other(side)]["eventHand"]
	if foe_hand.is_empty():
		log_line(state, "Opponent has no Events.")
		return
	var seed := next_seed(state)
	var index := int(floor((float(seed) / float(0xFFFFFFFF)) * float(foe_hand.size()))) % foe_hand.size()
	var taken: Dictionary = foe_hand[index]
	foe_hand.remove_at(index)
	if state["players"][side]["eventHand"].size() < 7:
		state["players"][side]["eventHand"].append(taken)
	else:
		state["eventDiscard"].append(taken)
	log_line(state, "%s steals %s." % [label_side(side), str(taken.get("title", ""))])


static func _field_hospital(state: Dictionary, side: String) -> void:
	var trench := own_trench(side)
	var room := 5 - soldiers_in_loc(state, side, trench)
	var casualties: Array = []
	for soldier in state["soldiers"]:
		if str(soldier.get("owner", "")) == side and str(soldier.get("loc", "")) == "casualties" and not bool(soldier.get("overflow", false)):
			casualties.append(soldier)
	var count := 0
	for soldier in casualties:
		if count >= 3 or room <= 0:
			break
		soldier["loc"] = trench
		room -= 1
		count += 1
	log_line(state, "Field Hospital returns %d Soldier(s)." % count)


static func _field_repairs(state: Dictionary, side: String, params: Dictionary) -> String:
	var unit := find_by_id(state["equipment"], str(params.get("unitId", "")))
	if unit.is_empty() or str(unit.get("owner", "")) != side or int(unit.get("damage", 0)) < 1:
		return "Choose a damaged friendly Unit."
	var count := mini(2, int(unit["damage"])) if str(unit.get("type", "")) == "tank" else 1
	unit["damage"] = int(unit["damage"]) - count
	log_line(state, "Field Repairs removes %d Damage from the %s." % [count, str(unit.get("type", ""))])
	return ""


static func _heavy_barrage(state: Dictionary, side: String, params: Dictionary) -> String:
	var zone := str(params.get("zone", ""))
	if controller_of(state, zone) != other(side):
		return "Must target an enemy-controlled zone."
	var kind := str(params.get("targetKind", "exposed"))
	if kind == "" or kind == "tank":
		kind = "exposed"
	apply_hits(state, side, {"kind": kind, "zone": zone, "coverId": params.get("coverId", null), "unitId": params.get("unitId", null)}, 3)
	return ""


static func _mark_mortar(state: Dictionary, side: String, params: Dictionary, key: String) -> String:
	var unit := find_by_id(state["equipment"], str(params.get("unitId", "")))
	if unit.is_empty() or str(unit.get("type", "")) != "mortar" or str(unit.get("owner", "")) != side or int(unit.get("damage", 0)) >= 1:
		return "Choose an undamaged Mortar."
	state["effects"][key].append(unit.get("id"))
	log_line(state, "%s marks a Mortar for %s." % [label_side(side), key])
	return ""


static func _raid(state: Dictionary, side: String, params: Dictionary) -> String:
	var ids: Array = params.get("soldierIds", [])
	if ids.size() > 2:
		ids = ids.slice(0, 2)
	var group := _soldiers_by_id(state, side, ids)
	if group.is_empty():
		return "Choose soldiers for Raid."
	var origin := str(group[0].get("loc", ""))
	for soldier in group:
		if str(soldier.get("loc", "")) != origin:
			return "Choose soldiers in the same zone."
	if controller_of(state, origin) != side:
		return "Raid starts in a zone you control."
	var dest := step_zone(side, origin, "forward")
	if dest == "" or not is_battlefield(dest):
		return "Illegal destination."
	for soldier in group:
		soldier["loc"] = dest
		soldier["coverId"] = null
		note_moved(state, side, str(soldier.get("id", "")))
	var cover := {}
	for token in covers_in(state, dest):
		var occupants := soldiers_in(state, dest, {"matchCover": true, "coverId": token.get("id")})
		var foreign := false
		for occupant in occupants:
			if str(occupant.get("owner", "")) != side:
				foreign = true
				break
		if occupants.size() < 3 and not foreign:
			cover = token
			break
	if not cover.is_empty():
		for soldier in group:
			var occupants := soldiers_in(state, dest, {"matchCover": true, "coverId": cover.get("id")})
			if occupants.size() < 3:
				soldier["coverId"] = cover.get("id")
	log_line(state, "%d Soldier(s) raid %s." % [group.size(), zone_label(dest)])
	return ""


static func _recon(state: Dictionary, params: Dictionary) -> String:
	var zone := str(params.get("zone", ""))
	if not is_battlefield(zone):
		return "Choose a battlefield zone."
	var tokens := covers_in(state, zone)
	for cover in tokens:
		cover["revealed"] = true
	log_line(state, "%d Cover position(s) revealed." % tokens.size() if not tokens.is_empty() else "No Cover there.")
	return ""


static func _sabotage(state: Dictionary, side: String, params: Dictionary) -> String:
	var foe := other(side)
	var dice: Array = state["players"][foe]["dice"]
	if not params.has("dieIndex"):
		return "Choose an enemy Action Die."
	var index := int(params.get("dieIndex", -1))
	if index < 0 or index >= dice.size():
		return "Choose an enemy Action Die."
	var face = dice[index]
	var name := str(face) if face != null else ""
	if name == "":
		return "That die is already gone."
	var bucket := str(state["players"][foe].get("wildAs", "")) if name == "wild" else name
	if bucket == "" or remaining(state, foe, bucket) < 1:
		return "That die is already used."
	dice[index] = null
	state["effects"]["stolenDie"] = {"owner": side, "face": name, "from": foe}
	log_line(state, "%s steals a %s die." % [label_side(side), name])
	return ""


static func _scout(state: Dictionary, side: String, params: Dictionary) -> String:
	var cover := find_by_id(state["covers"], str(params.get("coverId", "")))
	if cover.is_empty() or bool(cover.get("destroyed", false)):
		return "Choose an enemy Cover."
	var near := false
	for soldier in state["soldiers"]:
		if str(soldier.get("owner", "")) == side and is_battlefield(str(soldier.get("loc", ""))) and zone_distance(str(soldier.get("loc", "")), str(cover.get("loc", ""))) <= 1:
			near = true
			break
	if not near:
		return "Need a Soldier in or adjacent to that zone."
	cover["revealed"] = true
	var occupants := soldiers_in(state, str(cover.get("loc", "")), {"side": other(side), "matchCover": true, "coverId": cover.get("id")})
	if not occupants.is_empty():
		occupants[0]["coverId"] = null
		log_line(state, "Scout reveals the Cover and drives one Soldier into the open.")
	else:
		log_line(state, "Scout reveals Cover Defense %s." % str(cover.get("defense", "")))
	return ""


static func _sniper(state: Dictionary, side: String, params: Dictionary) -> String:
	var soldier := {}
	for candidate in state["soldiers"]:
		if str(candidate.get("id", "")) == str(params.get("soldierId", "")) and str(candidate.get("owner", "")) == other(side) and is_battlefield(str(candidate.get("loc", ""))):
			soldier = candidate
			break
	if soldier.is_empty():
		return "Choose an enemy Soldier."
	var result := roll_hits(state, 2)
	if int(result["hits"]) >= 1:
		eliminate_soldier(state, soldier)
		state["roundElim"][side] = int(state["roundElim"].get(side, 0)) + 1
	else:
		log_line(state, "Sniper misses.")
	return ""


static func _trench_fever(state: Dictionary, side: String, params: Dictionary) -> String:
	var zone := str(params.get("zone", ""))
	if not is_battlefield(zone):
		return "Choose a battlefield zone."
	var list := soldiers_in(state, zone, {"side": other(side), "exposed": true})
	if list.size() > 2:
		list = list.slice(0, 2)
	for soldier in list:
		eliminate_soldier(state, soldier)
		state["roundElim"][side] = int(state["roundElim"].get(side, 0)) + 1
	if list.is_empty():
		log_line(state, "No exposed enemy soldiers there.")
	return ""


static func _armored_advance(state: Dictionary, side: String, params: Dictionary) -> String:
	var tank := find_by_id(state["equipment"], str(params.get("unitId", "")))
	if tank.is_empty() or str(tank.get("type", "")) != "tank" or str(tank.get("owner", "")) != side or not is_battlefield(str(tank.get("loc", ""))):
		return "Choose a Tank on the battlefield."
	var dest := step_zone(side, str(tank.get("loc", "")), "forward")
	if dest == "":
		return "That Tank cannot advance."
	var moved: Array = state["players"][side]["movedTanks"]
	if not moved.has(tank.get("id")):
		moved.append(tank.get("id"))
	if dest == enemy_trench(side):
		state["vp"][side] = int(state["vp"][side]) + 1
		tank["loc"] = "supply"
		tank["damage"] = 0
		log_line(state, "Armored Advance — Tank enters the enemy Trench (+1 VP).")
		refresh_control(state, {"tankLeft": true})
		return ""
	tank["loc"] = dest
	log_line(state, "Tank advances to %s." % zone_label(dest))
	refresh_control(state)
	return ""


static func _tunnel(state: Dictionary, side: String, params: Dictionary) -> String:
	var trench := own_trench(side)
	var dest := str(params.get("zone", ""))
	if controller_of(state, dest) != side:
		return "Tunnel into a zone you control."
	var ids: Array = params.get("soldierIds", [])
	if ids.size() > 2:
		ids = ids.slice(0, 2)
	var count := 0
	for id in ids:
		for soldier in state["soldiers"]:
			if str(soldier.get("id", "")) == str(id) and str(soldier.get("owner", "")) == side and str(soldier.get("loc", "")) == trench:
				soldier["loc"] = dest
				soldier["coverId"] = null
				state["players"][side]["attackedIds"].append(soldier.get("id"))
				count += 1
				break
	if count == 0:
		return "Choose soldiers in your Trench."
	log_line(state, "%d Soldier(s) tunnel to %s." % [count, zone_label(dest)])
	return ""


static func _resolve_event(state: Dictionary, side: String, title: String, params: Dictionary) -> String:
	if title == "Reinforce":
		_reinforce(state, side)
	elif title == "Patrol":
		return _move_group(state, side, params, 2, true)
	elif title == "Charge":
		return _move_group(state, side, params, 3, false)
	elif title == "Bayonet Charge":
		return _bayonet_charge(state, side, params)
	elif title == "Bogged Down":
		state["effects"]["boggedDown"] = true
		state["effects"]["boggedDownBy"] = side
	elif title == "Bombing Run":
		return _bombing_run(state, side, params)
	elif title == "Carrier Pigeon":
		var mission = draw_mission(state, true)
		if mission != null:
			state["players"][side]["missionHand"].append(mission)
		trim_missions(state, side)
	elif title == "Cavalry Charge":
		state["effects"]["cavalryCharge"] = side
	elif title == "Christmas Truce":
		state["effects"]["christmasTruce"] = true
	elif title == "Entrench":
		return _entrench(state, side, params)
	elif title == "Espionage":
		_espionage(state, side)
	elif title == "Field Hospital":
		_field_hospital(state, side)
	elif title == "Field Repairs":
		return _field_repairs(state, side, params)
	elif title == "Heavy Barrage":
		return _heavy_barrage(state, side, params)
	elif title == "Mobility":
		return _mark_mortar(state, side, params, "mobility")
	elif title == "Precision Barrage":
		return _mark_mortar(state, side, params, "precision")
	elif title == "Raid":
		return _raid(state, side, params)
	elif title == "Recon Flight":
		return _recon(state, params)
	elif title == "Sabotage":
		return _sabotage(state, side, params)
	elif title == "Scout":
		return _scout(state, side, params)
	elif title == "Smoke Screen":
		var zone := str(params.get("zone", ""))
		if not is_battlefield(zone):
			return "Choose a battlefield zone."
		state["effects"]["smoke"].append(zone)
		log_line(state, "Smoke fills %s." % zone_label(zone))
	elif title == "Sniper":
		return _sniper(state, side, params)
	elif title == "Spotter":
		return _mark_mortar(state, side, params, "spotter")
	elif title == "Suppression":
		state["effects"]["suppression"] = "mortar" if str(params.get("supportType", "")) == "mortar" else "mg"
		state["effects"]["suppressionBy"] = side
		var word := "Mortars" if str(state["effects"]["suppression"]) == "mortar" else "Machine Guns"
		log_line(state, "Enemy %s are suppressed." % word)
	elif title == "Trench Fever":
		return _trench_fever(state, side, params)
	elif title == "Trench Foot":
		state["effects"]["trenchFoot"] = true
		state["effects"]["trenchFootBy"] = side
	elif title == "Armored Advance":
		return _armored_advance(state, side, params)
	elif title == "Tunnel":
		return _tunnel(state, side, params)
	else:
		log_line(state, "%s is not implemented yet." % title)
	return ""


static func is_interactive(state: Dictionary, side: String) -> bool:
	if str(state.get("mode", "")) == "sim":
		return false
	if str(state.get("mode", "")) == "hotseat":
		return true
	return side == str(state.get("human", ""))


static func actor_side(state: Dictionary) -> String:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	var kind := str(pending.get("type", ""))
	if kind == "generals-order" or kind == "spotter" or kind == "mortar-target" or kind == "gambit" or kind == "pick-mission" or kind == "allocate-hits":
		return str(pending.get("side", ""))
	var phase := str(state.get("phase", ""))
	if phase == "reroll" or phase == "action" or phase == "regroup":
		return str(state.get("active", ""))
	return ""


static func _has_general_order(state: Dictionary, side: String) -> bool:
	var who: Dictionary = state["players"][side]
	if bool(who.get("generalsOrderUsed", false)):
		return false
	for card in who["eventHand"]:
		if str(card.get("title", "")) == "General's Order":
			return true
	return false


static func _controls_a_zone(state: Dictionary, side: String) -> bool:
	var zones: Array = ["obj"]
	zones.append_array(side_zones(side))
	zones.append_array(enemy_side_zones(side))
	for zone in zones:
		if controller_of(state, zone) == side:
			return true
	return false


static func tank_may_advance(state: Dictionary, unit: Dictionary) -> bool:
	if unit.is_empty() or str(unit.get("type", "")) != "tank" or not is_battlefield(str(unit.get("loc", ""))):
		return false
	if bool(state["effects"].get("boggedDown", false)) and str(unit.get("owner", "")) != str(state["effects"].get("boggedDownBy", "")):
		return false
	if state["players"][unit["owner"]]["movedTanks"].has(unit.get("id")):
		return false
	if not units_in(state, str(unit.get("loc", "")), {"side": other(str(unit.get("owner", ""))), "type": "tank"}).is_empty():
		return false
	return true


static func tanks_ready(state: Dictionary, side: String) -> Array:
	var ready: Array = []
	for unit in state["equipment"]:
		if str(unit.get("owner", "")) == side and tank_may_advance(state, unit):
			ready.append(unit)
	return ready


static func should_skip_step(state: Dictionary, side: String, step: String) -> bool:
	if step == "shock":
		return not has_shock(state, side)
	if step == "tank":
		return tanks_ready(state, side).is_empty()
	if step == "event":
		if remaining(state, side, "whistle") < 1:
			return true
		for card in state["players"][side]["eventHand"]:
			if str(card.get("title", "")) != "General's Order":
				return false
		return true
	if step == "deploy":
		var bayonets := remaining(state, side, "bayonet")
		var supply := false
		var damaged := false
		for unit in state["equipment"]:
			if str(unit.get("owner", "")) != side:
				continue
			if str(unit.get("loc", "")) == "supply":
				supply = true
			if is_battlefield(str(unit.get("loc", ""))) and int(unit.get("damage", 0)) >= 1:
				damaged = true
		var available := not soldiers_in_loc_list(state, side, "available").is_empty()
		var held := _controls_a_zone(state, side)
		if bayonets >= 1 and not bool(state["players"][side].get("soldierDeployed", false)) and available and held:
			return false
		if bayonets >= 2 and supply:
			return false
		if bayonets >= 1 and damaged:
			return false
		return true
	if step == "move":
		return remaining(state, side, "boot") < 1
	if step == "cover":
		return remaining(state, side, "shovel") < 1
	if step == "attack":
		if bool(state["effects"].get("christmasTruce", false)):
			return true
		var who: Dictionary = state["players"][side]
		for soldier in state["soldiers"]:
			if str(soldier.get("owner", "")) == side and is_battlefield(str(soldier.get("loc", ""))) and not who["attackedIds"].has(soldier.get("id")):
				return false
		for unit in state["equipment"]:
			if str(unit.get("owner", "")) != side or not is_battlefield(str(unit.get("loc", ""))):
				continue
			if who["attackedIds"].has(unit.get("id")):
				continue
			if str(unit.get("type", "")) == "tank" or int(unit.get("damage", 0)) < 1:
				return false
		return true
	return false


static func _mission_paused(state: Dictionary, after) -> bool:
	if str(state.get("pending", {}).get("type", "")) != "pick-mission":
		return false
	if after != null and state["pending"].get("after", null) == null:
		state["pending"]["after"] = after
	return true


static func _settle_pending(state: Dictionary) -> void:
	if str(state.get("phase", "")) == "end" or str(state.get("pending", {}).get("type", "")) == "pick-mission":
		return
	if str(state.get("phase", "")) == "action" and str(state.get("actionStep", "")) != "":
		state["pending"] = {"type": "action", "step": state.get("actionStep")}
		return
	if str(state.get("phase", "")) == "regroup" and str(state.get("active", "")) != "":
		state["pending"] = {"type": "regroup", "side": state.get("active")}
		return
	if str(state.get("phase", "")) == "reroll" and str(state.get("active", "")) != "":
		state["pending"] = {"type": "reroll", "side": state.get("active")}


static func _end_game(state: Dictionary, why: String) -> void:
	if str(state.get("phase", "")) == "end":
		return
	state["phase"] = "end"
	state["pending"] = {"type": "end"}
	state["actionStep"] = null
	var britain := int(state["vp"]["uk"])
	var germany := int(state["vp"]["de"])
	if britain > germany:
		state["winner"] = "uk"
	elif germany > britain:
		state["winner"] = "de"
	elif controller_of(state, "obj") != "":
		state["winner"] = controller_of(state, "obj")
	else:
		var uk_enemy := 0
		var de_enemy := 0
		for zone in enemy_side_zones("uk"):
			if controller_of(state, zone) == "uk":
				uk_enemy += 1
		for zone in enemy_side_zones("de"):
			if controller_of(state, zone) == "de":
				de_enemy += 1
		if uk_enemy > de_enemy:
			state["winner"] = "uk"
		elif de_enemy > uk_enemy:
			state["winner"] = "de"
		else:
			var uk_cover := state["players"]["uk"]["destroyedCover"].size()
			var de_cover := state["players"]["de"]["destroyedCover"].size()
			if uk_cover > de_cover:
				state["winner"] = "uk"
			elif de_cover > uk_cover:
				state["winner"] = "de"
			else:
				state["winner"] = null
	state["tiebreak"] = why
	if state["winner"] != null and str(state["winner"]) != "":
		log_line(state, "%s wins (%s)." % [label_side(str(state["winner"])), why])
	else:
		log_line(state, "Draw (%s)." % why)


static func _show_notice(state: Dictionary, side: String, text: String) -> void:
	log_line(state, text)
	push_brief(state, text)
	if not (state.get("killPulse") is Array):
		state["killPulse"] = []
	state["killPulse"].append({"id": state["killPulse"].size(), "side": side, "text": text})


static func _clear_roll(state: Dictionary) -> void:
	state["lastRoll"] = null


static func _close_direct_fire(state: Dictionary, side: String, target: Dictionary, hits: int) -> void:
	refresh_control(state)
	var choosing := check_missions(state, side, {"timing": "combat", "hits": hits, "target": target}) == "choose"
	state["combat"] = null
	_clear_roll(state)
	if choosing:
		return
	state["pending"] = {"type": "action", "step": "attack"}
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")


static func _spend_attackers(state: Dictionary, side: String, attackers: Array) -> void:
	var who: Dictionary = state["players"][side]
	for attacker in attackers:
		if not who["attackedIds"].has(attacker.get("id")):
			who["attackedIds"].append(attacker.get("id"))
		var kind := str(attacker.get("type", ""))
		if kind != "" and kind != "tank" and not who["firedEquip"].has(attacker.get("id")):
			who["firedEquip"].append(attacker.get("id"))


static func _settle_direct_hits(state: Dictionary, side: String, target: Dictionary, result: Dictionary, attackers: Array) -> void:
	reveal_attacked_cover(state, target)
	var hits := int(result.get("hits", 0))
	if hits <= 0 or not is_interactive(state, side):
		apply_hits(state, side, target, hits)
		_spend_attackers(state, side, attackers)
		_close_direct_fire(state, side, target, hits)
		return
	var options := allocation_options(state, side, target)
	if options.is_empty():
		apply_hits(state, side, target, hits)
		_spend_attackers(state, side, attackers)
		_close_direct_fire(state, side, target, hits)
		return
	_spend_attackers(state, side, attackers)
	state["combat"] = null
	state["pending"] = {
		"type": "allocate-hits",
		"side": side,
		"hits": hits,
		"zone": target.get("zone"),
		"target": {
			"kind": target.get("kind"),
			"zone": target.get("zone"),
			"coverId": target.get("coverId", null),
			"unitId": target.get("unitId", null),
		},
		"options": options,
		"faces": result.get("faces", []).duplicate(),
	}


static func _do_roll1(state: Dictionary) -> String:
	roll_all_action(state, "uk")
	roll_all_action(state, "de")
	log_line(state, "Roll 1 — Britain: %s. Germany: %s. Wilds ignored." % [combo_label(state["players"]["uk"]["dice"]), combo_label(state["players"]["de"]["dice"])])
	var waiting: Array = []
	for side in ["uk", "de"]:
		if _has_general_order(state, side):
			waiting.append(side)
	var queue: Array = []
	for side in waiting:
		if not is_interactive(state, side):
			queue.append(side)
	for side in waiting:
		if is_interactive(state, side):
			queue.append(side)
	if not queue.is_empty():
		state["pending"] = {"type": "generals-order", "side": queue[0], "queue": queue}
		return ""
	return _after_roll1(state)


static func _finish_generals_order(state: Dictionary) -> String:
	var queue: Array = []
	if state.get("pending") is Dictionary:
		queue = state["pending"].get("queue", []).duplicate()
	if not queue.is_empty():
		queue.pop_front()
	if not queue.is_empty():
		state["pending"] = {"type": "generals-order", "side": queue[0], "queue": queue}
		return ""
	return _after_roll1(state)


static func _do_generals_order(state: Dictionary, action: Dictionary) -> String:
	var side := str(action.get("side", state.get("pending", {}).get("side", state.get("human", ""))))
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	if str(pending.get("type", "")) != "generals-order" or str(pending.get("side", "")) != side:
		return "General's Order is not available."
	var who: Dictionary = state["players"][side]
	var card := {}
	for entry in who["eventHand"]:
		if str(entry.get("title", "")) == "General's Order":
			card = entry
			break
	if card.is_empty():
		return "No General's Order in hand."
	var mode := str(action.get("mode", ""))
	if mode == "reroll":
		var indexes: Array = []
		for raw in action.get("indexes", []):
			var index := int(raw)
			if index >= 0 and index < 5 and not indexes.has(index):
				indexes.append(index)
			if indexes.size() >= 2:
				break
		if indexes.is_empty():
			return "Choose up to two dice to reroll."
		for index in indexes:
			who["dice"][index] = roll_action_die(state)
	elif mode == "change":
		var index := int(action.get("index", -1))
		var face := str(action.get("to", ""))
		if index < 0 or index >= 5:
			return "Choose a die to change."
		if not ["boot", "whistle", "shovel", "bayonet"].has(face):
			return "Choose a Boot, Whistle, Shovel, or Bayonet."
		var showing := false
		for die_face in who["dice"]:
			if str(die_face) == face:
				showing = true
				break
		if not showing:
			return "Must match a natural face from Roll 1."
		who["dice"][index] = face
	else:
		return "Choose how to use General's Order."
	discard_event(state, side, str(card.get("inst", "")))
	who["generalsOrderUsed"] = true
	log_line(state, "%s plays General's Order." % label_side(side))
	return _finish_generals_order(state)


static func _after_roll1(state: Dictionary) -> String:
	var tie_rolls := 0
	var locked := lock_initiative(state, tie_rolls)
	while locked.is_empty():
		tie_rolls += 1
		if tie_rolls > 40:
			return "Initiative could not be decided."
		log_line(state, "Initiative tied — both sides reroll all five dice. The tied roll is discarded.")
		roll_all_action(state, "uk")
		roll_all_action(state, "de")
		locked = lock_initiative(state, tie_rolls)
	var winner := str(locked.get("winner", ""))
	state["player1"] = winner
	var source := "the deciding roll" if tie_rolls > 0 else "Roll 1"
	var text := "%s wins Initiative from %s — Britain: %s. Germany: %s. %s will act first." % [
		label_side(winner), source, locked["uk"]["label"], locked["de"]["label"], label_side(winner),
	]
	log_line(state, text)
	push_brief(state, text)
	state["phase"] = "reroll"
	state["active"] = other(winner)
	state["players"]["uk"]["rollsUsed"] = 1
	state["players"]["de"]["rollsUsed"] = 1
	state["pending"] = {"type": "reroll", "side": state["active"]}
	return ""


static func _toggle_keep(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if str(state.get("phase", "")) != "reroll" or side != str(action.get("side", "")):
		return ""
	var who: Dictionary = state["players"][side]
	var index := int(action.get("index", -1))
	if index < 0 or index >= who["dice"].size():
		return ""
	who["kept"][index] = not bool(who["kept"][index])
	return ""


static func _do_reroll(state: Dictionary, action: Dictionary) -> String:
	if str(state.get("phase", "")) != "reroll":
		return "Rerolls are not open."
	var side := str(state.get("active", ""))
	if str(action.get("side", "")) != "" and str(action.get("side", "")) != side:
		return "You can only reroll your own dice."
	var who: Dictionary = state["players"][side]
	if bool(who.get("committed", false)):
		return "Those dice are already committed."
	if int(who.get("rollsUsed", 1)) >= 3:
		return "No rerolls remaining."
	var keep: Array = action.get("keep", who.get("kept", []))
	if keep.size() != 5:
		return "Keep five dice."
	var all_kept := true
	for flag in keep:
		if not bool(flag):
			all_kept = false
			break
	if all_kept:
		return "Set aside at least one die to reroll."
	reroll_kept(state, side, keep)
	log_line(state, "%s rerolls (Roll %d)." % [label_side(side), int(who["rollsUsed"])])
	return ""


static func _start_action_phase(state: Dictionary, side: String) -> String:
	state["phase"] = "action"
	state["active"] = side
	state["actionStep"] = "shock"
	state["pending"] = {"type": "action", "step": "shock"}
	log_line(state, "%s begins the Action Phase." % label_side(side))
	if should_skip_step(state, side, "shock"):
		if is_interactive(state, side):
			return ""
		return _advance_step(state)
	return ""


static func _do_commit(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if side == "":
		return "Nobody is rolling."
	commit_dice(state, side, action.get("wildAs", null))
	if side == other(str(state.get("player1", ""))):
		state["active"] = state["player1"]
		state["pending"] = {"type": "reroll", "side": state["player1"]}
		return ""
	return _start_action_phase(state, str(state.get("player1", "")))


static func _advance_step(state: Dictionary) -> String:
	var index := STEPS.find(str(state.get("actionStep", "")))
	while true:
		index += 1
		if index >= STEPS.size():
			return _finish_action_phase(state)
		var nxt := str(STEPS[index])
		var skip := should_skip_step(state, str(state.get("active", "")), nxt)
		if skip and not is_interactive(state, str(state.get("active", ""))):
			continue
		state["actionStep"] = nxt
		state["pending"] = {"type": "action", "step": nxt}
		if nxt == "event":
			var insts: Array = []
			for card in state["players"][state["active"]]["eventHand"]:
				insts.append(card.get("inst"))
			state["players"][state["active"]]["eventsAtStep"] = insts
		return ""


static func _finish_tank_move(state: Dictionary, tank: Dictionary) -> String:
	var moved: Array = state["players"][tank["owner"]]["movedTanks"]
	if not moved.has(tank.get("id")):
		moved.append(tank.get("id"))
	if not tanks_ready(state, str(state.get("active", ""))).is_empty():
		return ""
	return _advance_step(state)


static func _killed_clause(count: int, zone: String) -> String:
	var place := zone_label(zone)
	if count == 1:
		return "1 soldier killed in %s" % place
	if count == 0:
		return "no soldiers killed in %s" % place
	return "%d soldiers killed in %s" % [count, place]


static func _mustard_gas(state: Dictionary, side: String) -> void:
	log_line(state, "%s uses Shock: Mustard Gas." % label_side(side))
	if bool(state["effects"].get("christmasTruce", false)):
		log_line(state, "Christmas Truce prevents Mustard Gas.")
		_clear_roll(state)
		return
	var foe := other(side)
	var zones: Array = []
	var clauses: Array = []
	var eliminated := 0
	for zone in enemy_side_zones(side):
		var result := roll_hits(state, 3)
		var exposed := soldiers_in(state, zone, {"side": foe, "exposed": true})
		var count := mini(int(result["hits"]), exposed.size())
		for index in count:
			eliminate_soldier(state, exposed[index])
		eliminated += count
		log_line(state, "Mustard Gas over %s: %d Hit(s), %d eliminated." % [zone_label(zone), int(result["hits"]), count])
		zones.append({"zone": zone, "faces": result["faces"].duplicate(), "hits": result["hits"]})
		clauses.append(_killed_clause(count, zone))
	push_fx(state, {"kind": "gas", "side": side, "zones": enemy_side_zones(side).duplicate()})
	if eliminated:
		state["roundElim"][side] = int(state["roundElim"].get(side, 0)) + eliminated
	state["lastRoll"] = {"kind": "mustard", "zones": zones}
	refresh_control(state)
	if eliminated:
		check_missions(state, side, {"timing": "immediate"})
	_show_notice(state, side, "%s's mustard gas: %s." % [label_side(side), ", ".join(clauses)])
	_clear_roll(state)


static func _mission_gambit(state: Dictionary, side: String) -> String:
	log_line(state, "%s uses Shock: Mission Gambit. The five dice stay available." % label_side(side))
	var first = draw_mission(state, true)
	var second = draw_mission(state, true) if first != null else null
	if bool(state.get("missionExhausted", false)):
		if first != null:
			state["players"][side]["missionHand"].append(first)
		_end_game(state, "Mission Exhaustion")
		return ""
	var drawn: Array = []
	if first != null:
		drawn.append(first)
	if second != null:
		drawn.append(second)
	if drawn.is_empty():
		return ""
	if is_interactive(state, side) and drawn.size() == 2:
		state["pending"] = {"type": "gambit", "side": side, "stage": "keep", "cards": drawn}
		return ""
	var keep: Dictionary = drawn[0]
	for card in drawn:
		if int(card.get("vp", 0)) > int(keep.get("vp", 0)):
			keep = card
	state["players"][side]["missionHand"].append(keep)
	for card in drawn:
		if str(card.get("inst", "")) != str(keep.get("inst", "")):
			state["missionDeck"].append(card)
	if check_missions(state, side, {"timing": "immediate"}) == "choose":
		state["pending"]["after"] = {"kind": "gambit-auto", "side": side}
		return ""
	trim_missions(state, side)
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")
	return ""


static func _do_shock(state: Dictionary, action: Dictionary) -> String:
	if str(state.get("actionStep", "")) != "shock":
		return "Not the Shock step."
	if not has_shock(state, str(state.get("active", ""))):
		return "Need five matching Action Dice."
	var option := str(action.get("option", ""))
	if option == "gambit":
		var err := _mission_gambit(state, str(state.get("active", "")))
		if err != "":
			return err
	elif option == "gas":
		var who: Dictionary = state["players"][state["active"]]
		who["spent"] = {"boot": 99, "shovel": 99, "bayonet": 99, "whistle": 99}
		_mustard_gas(state, str(state.get("active", "")))
	else:
		return "Choose a Shock option."
	if str(state.get("phase", "")) == "end" or str(state.get("pending", {}).get("type", "")) == "gambit":
		return ""
	if _mission_paused(state, {"kind": "advance-step"}):
		return ""
	return _advance_step(state)


static func _pick_gambit(state: Dictionary, action: Dictionary) -> String:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	if str(pending.get("type", "")) != "gambit" or str(pending.get("stage", "")) != "keep":
		return "No Mission Gambit choice is waiting."
	var cards: Array = pending.get("cards", [])
	var keep: Dictionary = cards[0] if not cards.is_empty() else {}
	for card in cards:
		if str(card.get("inst", "")) == str(action.get("inst", "")):
			keep = card
			break
	if keep.is_empty():
		return "Choose a mission to keep."
	state["players"][pending["side"]]["missionHand"].append(keep)
	for card in cards:
		if str(card.get("inst", "")) != str(keep.get("inst", "")):
			state["missionDeck"].append(card)
	log_line(state, "%s keeps %s." % [label_side(str(pending.get("side", ""))), str(keep.get("title", ""))])
	if check_missions(state, str(pending.get("side", "")), {"timing": "immediate"}) == "choose":
		state["pending"]["after"] = {"kind": "gambit-swap", "side": pending.get("side")}
		return ""
	state["pending"] = {"type": "gambit", "side": pending.get("side"), "stage": "swap"}
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")
	return ""


static func _finish_gambit(state: Dictionary, action: Dictionary) -> String:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	if str(pending.get("type", "")) != "gambit" or str(pending.get("stage", "")) != "swap":
		return "No Mission Gambit swap is waiting."
	var side := str(pending.get("side", ""))
	var hand: Array = state["players"][side]["missionHand"]
	if str(action.get("discard", "")) != "":
		for index in hand.size():
			if str(hand[index].get("inst", "")) == str(action.get("discard", "")):
				var dropped: Dictionary = hand[index]
				hand.remove_at(index)
				state["missionDeck"].append(dropped)
				var replacement = draw_mission(state, true)
				if replacement != null:
					hand.append(replacement)
				log_line(state, "%s swaps %s." % [label_side(side), str(dropped.get("title", ""))])
				break
	trim_missions(state, side)
	state["pending"] = {"type": "action", "step": "shock"}
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")
		return ""
	if check_missions(state, side, {"timing": "immediate"}) == "choose":
		state["pending"]["after"] = {"kind": "advance-step"}
		return ""
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")
		return ""
	return _advance_step(state)


static func _move_tank(state: Dictionary, action: Dictionary) -> String:
	var tank := {}
	for unit in state["equipment"]:
		if str(unit.get("id", "")) == str(action.get("unitId", "")) and str(unit.get("type", "")) == "tank" and str(unit.get("owner", "")) == str(state.get("active", "")):
			tank = unit
			break
	if tank.is_empty() or not is_battlefield(str(tank.get("loc", ""))):
		return "That Tank is not on the battlefield."
	if bool(state["effects"].get("boggedDown", false)) and str(tank.get("owner", "")) != str(state["effects"].get("boggedDownBy", "")):
		return "Bogged Down: enemy Tanks cannot move."
	if not units_in(state, str(tank.get("loc", "")), {"side": other(str(tank.get("owner", ""))), "type": "tank"}).is_empty():
		return "Engaged Tanks cannot leave while an enemy Tank remains."
	if state["players"][tank["owner"]]["movedTanks"].has(tank.get("id")):
		return "That Tank already moved."
	var steps := clampi(int(action.get("steps", 0)), 0, 2)
	if steps == 0:
		return "Choose how far the Tank advances."
	var path: Array = [tank.get("loc")]
	for _n in steps:
		var nxt := step_zone(str(tank.get("owner", "")), str(tank.get("loc", "")), "forward")
		if nxt == "":
			break
		if is_battlefield(nxt) and not units_in(state, nxt, {"side": other(str(tank.get("owner", ""))), "type": "tank"}).is_empty():
			tank["loc"] = nxt
			path.append(nxt)
			log_line(state, "%s Tank stops in %s (enemy Tank)." % [label_side(str(tank.get("owner", ""))), zone_label(nxt)])
			break
		if nxt == enemy_trench(str(tank.get("owner", ""))):
			path.append(nxt)
			state["vp"][tank["owner"]] = int(state["vp"][tank["owner"]]) + 3
			_show_notice(state, str(tank.get("owner", "")), "%s gains 3 victory points for the tank breakthrough." % label_side(str(tank.get("owner", ""))))
			tank["loc"] = "supply"
			tank["damage"] = 0
			push_fx(state, {"kind": "tank", "unitId": tank.get("id"), "owner": tank.get("owner"), "path": path.duplicate(), "breakthrough": true})
			refresh_control(state, {"tankLeft": true})
			check_missions(state, str(tank.get("owner", "")), {"timing": "immediate"})
			if _mission_paused(state, {"kind": "finish-tank", "tankId": tank.get("id")}):
				return ""
			return _finish_tank_move(state, tank)
		var left := str(tank.get("loc", ""))
		tank["loc"] = nxt
		path.append(nxt)
		state["hadTank"][left] = true
		log_line(state, "%s Tank advances to %s." % [label_side(str(tank.get("owner", ""))), zone_label(nxt)])
	if path.size() > 1:
		push_fx(state, {"kind": "tank", "unitId": tank.get("id"), "owner": tank.get("owner"), "path": path.duplicate(), "breakthrough": false})
	refresh_control(state)
	check_missions(state, str(state.get("active", "")), {"timing": "immediate"})
	if _mission_paused(state, {"kind": "finish-tank", "tankId": tank.get("id")}):
		return ""
	return _finish_tank_move(state, tank)


static func _do_play_event(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if str(state.get("actionStep", "")) != "event":
		return "Not the Event step."
	var card := {}
	for entry in state["players"][side]["eventHand"]:
		if str(entry.get("inst", "")) == str(action.get("cardInst", "")):
			card = entry
			break
	if card.is_empty():
		return "Card is not in hand."
	if str(card.get("title", "")) == "General's Order":
		return "General's Order is only played after Roll 1."
	var opened = state["players"][side].get("eventsAtStep", null)
	if opened is Array and not opened.has(card.get("inst")):
		return "That Event was not in hand when the Event Step began."
	if card.get("whistle", true) != false and not bool(action.get("free", false)):
		if remaining(state, side, "whistle") < 1:
			return "Need a Whistle to play an Event."
		spend(state, side, "whistle", 1)
	var params: Dictionary = action.get("params", {}) if action.get("params") is Dictionary else {}
	var err := play_event(state, side, card, params)
	if err != "":
		return err
	discard_event(state, side, str(card.get("inst", "")))
	refresh_control(state)
	check_missions(state, side, {"timing": "immediate"})
	return ""


static func _pay_bayonets(state: Dictionary, side: String, cost: int, indexes) -> String:
	var word := "Bayonet" if cost == 1 else "Bayonets"
	if indexes is Array:
		if indexes.size() != cost:
			return "Select %d %s." % [cost, word]
		return spend_selected(state, side, "bayonet", indexes)
	if is_interactive(state, side):
		return "Select the bayonet dice to spend."
	if remaining(state, side, "bayonet") < cost:
		return "Need %d %s." % [cost, word]
	spend(state, side, "bayonet", cost)
	return ""


static func mortars_in_supply(state: Dictionary, side: String) -> int:
	var count := 0
	for unit in state["equipment"]:
		if str(unit.get("owner", "")) == side and str(unit.get("type", "")) == "mortar" and str(unit.get("loc", "")) == "supply":
			count += 1
	return count


static func _supply_count(state: Dictionary, side: String, kind: String) -> int:
	var count := 0
	for unit in state["equipment"]:
		if str(unit.get("owner", "")) == side and str(unit.get("type", "")) == kind and str(unit.get("loc", "")) == "supply":
			count += 1
	return count


static func _do_deploy(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if str(state.get("actionStep", "")) != "deploy":
		return "Not the Deploy step."
	var kind := str(action.get("kind", ""))
	var zone := str(action.get("zone", ""))
	if kind == "mortar":
		if remaining(state, side, "bayonet") < 2:
			return "Need 2 Bayonets."
		if zone != own_zone1(side):
			return "Mortars deploy into your Zone 1."
		if controller_of(state, zone) != side:
			return "You must control Zone 1."
		var unit := {}
		for piece in state["equipment"]:
			if str(piece.get("owner", "")) == side and str(piece.get("type", "")) == "mortar" and str(piece.get("loc", "")) == "supply":
				unit = piece
				break
		if unit.is_empty():
			return "All Mortars are already deployed."
		var err := _pay_bayonets(state, side, 2, action.get("indexes", null))
		if err != "":
			return err
		unit["loc"] = zone
		unit["damage"] = 0
		log_line(state, "%s deploys a Mortar in %s." % [label_side(side), zone_label(zone)])
	elif kind == "mg":
		if remaining(state, side, "bayonet") < 3:
			return "Need 3 Bayonets."
		if not side_zones(side).has(zone):
			return "Machine Guns deploy on your own side."
		if controller_of(state, zone) != side:
			return "You must control that zone."
		var unit := {}
		for piece in state["equipment"]:
			if str(piece.get("owner", "")) == side and str(piece.get("type", "")) == "mg" and str(piece.get("loc", "")) == "supply":
				unit = piece
				break
		if unit.is_empty():
			return "All Machine Guns are already deployed."
		var err := _pay_bayonets(state, side, 3, action.get("indexes", null))
		if err != "":
			return err
		unit["loc"] = zone
		unit["damage"] = 0
		log_line(state, "%s deploys a Machine Gun in %s." % [label_side(side), zone_label(zone)])
	elif kind == "tank":
		if remaining(state, side, "bayonet") < 4:
			return "Need 4 Bayonets."
		var unit := {}
		for piece in state["equipment"]:
			if str(piece.get("owner", "")) == side and str(piece.get("type", "")) == "tank" and str(piece.get("loc", "")) == "supply":
				unit = piece
				break
		if unit.is_empty():
			return "All Tanks are already deployed."
		var err := _pay_bayonets(state, side, 4, action.get("indexes", null))
		if err != "":
			return err
		unit["loc"] = own_zone1(side)
		unit["damage"] = 0
		log_line(state, "%s deploys a Tank in %s." % [label_side(side), zone_label(str(unit["loc"]))])
	elif kind == "soldier":
		var who: Dictionary = state["players"][side]
		if bool(who.get("soldierDeployed", false)):
			return "You may deploy only one Soldier this round."
		if remaining(state, side, "bayonet") < 1:
			return "Need 1 Bayonet."
		if not is_battlefield(zone) or controller_of(state, zone) != side:
			return "Deploy the Soldier into a battlefield zone you control."
		var soldier := {}
		for piece in state["soldiers"]:
			if str(piece.get("owner", "")) == side and str(piece.get("loc", "")) == "available":
				soldier = piece
				break
		if soldier.is_empty():
			return "No Soldier in supply."
		var err := _pay_bayonets(state, side, 1, action.get("indexes", null))
		if err != "":
			return err
		soldier["loc"] = zone
		soldier["coverId"] = null
		who["soldierDeployed"] = true
		log_line(state, "%s deploys a Soldier into %s." % [label_side(side), zone_label(zone)])
	else:
		return "Unknown deployment."
	refresh_control(state)
	check_missions(state, side, {"timing": "immediate"})
	return ""


static func _do_repair(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if str(state.get("actionStep", "")) != "deploy":
		return "Not the Deploy step."
	if remaining(state, side, "bayonet") < 1:
		return "Need 1 Bayonet."
	var unit := find_by_id(state["equipment"], str(action.get("unitId", "")))
	if unit.is_empty() or str(unit.get("owner", "")) != side or not is_battlefield(str(unit.get("loc", ""))) or int(unit.get("damage", 0)) < 1:
		return "That Unit does not need repair."
	var err := _pay_bayonets(state, side, 1, action.get("indexes", null))
	if err != "":
		return err
	unit["damage"] = int(unit["damage"]) - 1
	log_line(state, "%s repairs the %s (%d Damage left)." % [label_side(side), cap_type(str(unit.get("type", ""))), int(unit["damage"])])
	refresh_control(state)
	return ""


static func _do_move(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if str(state.get("actionStep", "")) != "move":
		return "Not the Move step."
	if str(action.get("kind", "")) == "soldier":
		var soldier := find_by_id(state["soldiers"], str(action.get("unitId", "")))
		if soldier.is_empty() or str(soldier.get("owner", "")) != side:
			return "Soldier not found."
		if _foot_locked(state, side):
			return "Trench Foot prevents Soldier movement."
		if str(soldier.get("coverId", "")) != "":
			return "Soldiers in Cover must Leave Cover first."
		if remaining(state, side, "boot") < 1:
			return "Need a Boot."
		var from_trench := str(soldier.get("loc", "")) == own_trench(side)
		if not from_trench and not is_battlefield(str(soldier.get("loc", ""))):
			return "That Soldier is not on the battlefield."
		var dest := step_zone(side, str(soldier.get("loc", "")), str(action.get("dir", "")))
		if dest == "" or not is_battlefield(dest):
			return "Illegal destination."
		if from_trench and (str(action.get("dir", "")) != "forward" or dest != own_zone1(side)):
			return "A Soldier leaves the Trench only by advancing into Zone 1."
		spend(state, side, "boot", 1)
		soldier["loc"] = dest
		soldier["coverId"] = null
		note_moved(state, side, str(soldier.get("id", "")))
		log_line(state, "%s Soldier moves %s to %s." % [label_side(side), str(action.get("dir", "")), zone_label(dest)])
	else:
		var unit := find_by_id(state["equipment"], str(action.get("unitId", "")))
		if unit.is_empty() or str(unit.get("owner", "")) != side or str(unit.get("type", "")) == "tank":
			return "Illegal Unit."
		if int(unit.get("damage", 0)) >= 1:
			return "Damaged support weapons cannot move."
		if state["players"][side]["firedEquip"].has(unit.get("id")):
			return "That Unit already attacked."
		if remaining(state, side, "boot") < 1:
			return "Need a Boot."
		var dest := step_zone(side, str(unit.get("loc", "")), str(action.get("dir", "")))
		if dest == "" or not is_battlefield(dest):
			return "Illegal destination."
		spend(state, side, "boot", 1)
		unit["loc"] = dest
		state["players"][side]["movedEquip"].append(unit.get("id"))
		log_line(state, "%s %s moves to %s." % [label_side(side), cap_type(str(unit.get("type", ""))), zone_label(dest)])
	refresh_control(state)
	check_missions(state, side, {"timing": "immediate"})
	return ""


static func _leave_then_move(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if remaining(state, side, "shovel") < 1:
		return "Need a Shovel to Leave Cover."
	var soldier := find_by_id(state["soldiers"], str(action.get("unitId", "")))
	if soldier.is_empty() or str(soldier.get("owner", "")) != side or str(soldier.get("coverId", "")) == "":
		return "Soldier is not in Cover."
	spend(state, side, "shovel", 1)
	soldier["coverId"] = null
	log_line(state, "%s Soldier leaves Cover." % label_side(side))
	var follow := action.duplicate(true)
	follow["kind"] = "soldier"
	return _do_move(state, follow)


static func _do_shovel(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if str(state.get("actionStep", "")) != "cover":
		return "Not the Cover step."
	if remaining(state, side, "shovel") < 1:
		return "Need a Shovel."
	var mode := str(action.get("mode", ""))
	if mode == "dig":
		var soldier := find_by_id(state["soldiers"], str(action.get("soldierId", "")))
		if soldier.is_empty() or str(soldier.get("owner", "")) != side or str(soldier.get("coverId", "")) != "" or not is_battlefield(str(soldier.get("loc", ""))):
			return "Illegal Dig In."
		var cover := find_by_id(state["covers"], str(action.get("coverId", "")))
		if cover.is_empty() or str(cover.get("loc", "")) != str(soldier.get("loc", "")) or bool(cover.get("destroyed", false)):
			return "No such Cover."
		var occupants := soldiers_in(state, str(soldier.get("loc", "")), {"matchCover": true, "coverId": cover.get("id")})
		for occupant in occupants:
			if str(occupant.get("owner", "")) != side:
				return "Opposing Soldiers may not share Cover."
		if occupants.size() >= 3:
			return "Cover capacity is 3."
		spend(state, side, "shovel", 1)
		soldier["coverId"] = cover.get("id")
		log_line(state, "%s Soldier Digs In." % label_side(side))
	elif mode == "leave":
		var soldier := find_by_id(state["soldiers"], str(action.get("soldierId", "")))
		if soldier.is_empty() or str(soldier.get("owner", "")) != side or str(soldier.get("coverId", "")) == "":
			return "Not in Cover."
		spend(state, side, "shovel", 1)
		soldier["coverId"] = null
		log_line(state, "%s Soldier leaves Cover." % label_side(side))
	elif mode == "prepare":
		var zone := str(action.get("zone", ""))
		if controller_of(state, zone) != side:
			return "Prepare Position requires Control."
		if state["coverSupply"].is_empty():
			return "No Cover tokens remain."
		spend(state, side, "shovel", 1)
		var token: Dictionary = state["coverSupply"].pop_front()
		token["loc"] = zone
		state["covers"].append(token)
		log_line(state, "%s prepares Cover in %s." % [label_side(side), zone_label(zone)])
	elif mode == "relocate":
		var cover := find_by_id(state["covers"], str(action.get("coverId", "")))
		if cover.is_empty() or bool(cover.get("destroyed", false)):
			return "Cover not found."
		if not soldiers_in(state, str(cover.get("loc", "")), {"matchCover": true, "coverId": cover.get("id")}).is_empty():
			return "Occupied Cover cannot move."
		var dest := str(action.get("zone", ""))
		if zone_distance(str(cover.get("loc", "")), dest) != 1:
			return "Relocate one zone only."
		if controller_of(state, dest) != side:
			return "Destination must be a zone you control."
		spend(state, side, "shovel", 1)
		cover["loc"] = dest
		log_line(state, "%s relocates Cover to %s." % [label_side(side), zone_label(dest)])
	else:
		return "Unknown Cover action."
	refresh_control(state)
	check_missions(state, side, {"timing": "immediate"})
	return ""


static func _map_mortar_zone(owner: String, face: String) -> String:
	var zones := enemy_side_zones(owner)
	if face == "z1":
		return str(zones[0])
	if face == "z2":
		return str(zones[1])
	if face == "z3":
		return str(zones[2])
	return ""


static func _mortar_label(owner: String, face: String) -> String:
	var zone := _map_mortar_zone(owner, face)
	return zone_label(zone) if zone != "" else face


static func _mortar_options(state: Dictionary, side: String, zone: String) -> Array:
	var foe := other(side)
	var options: Array = []
	if not soldiers_in(state, zone, {"side": foe, "exposed": true}).is_empty():
		options.append({"id": "exposed:%s" % zone, "kind": "exposed", "zone": zone, "label": "exposed soldiers"})
	for cover in state["covers"]:
		if str(cover.get("loc", "")) != zone or bool(cover.get("destroyed", false)):
			continue
		var occupants := soldiers_in(state, zone, {"matchCover": true, "coverId": cover.get("id")})
		var enemy_inside := false
		for soldier in occupants:
			if str(soldier.get("owner", "")) == foe:
				enemy_inside = true
				break
		if enemy_inside:
			options.append({"id": "cover:%s" % str(cover.get("id")), "kind": "cover", "coverId": cover.get("id"), "zone": zone, "label": "soldiers in cover"})
		elif occupants.is_empty():
			options.append({"id": "empty:%s" % str(cover.get("id")), "kind": "cover-empty", "coverId": cover.get("id"), "zone": zone, "label": "empty cover"})
	for unit in units_in(state, zone, {"side": foe}):
		var gear := str(unit.get("type", ""))
		if gear == "mg" or gear == "mortar":
			options.append({
				"id": "unit:%s" % str(unit.get("id")),
				"kind": gear,
				"unitId": unit.get("id"),
				"zone": zone,
				"label": "machine gun" if gear == "mg" else "mortar",
			})
	return options


static func _mortar_origin(unit: Dictionary) -> String:
	if is_battlefield(str(unit.get("loc", ""))):
		return str(unit.get("loc", ""))
	return own_trench(str(unit.get("owner", "")))


static func _remember_mortar(state: Dictionary, target: Dictionary) -> Dictionary:
	var casualties: Array = []
	for soldier in state["soldiers"]:
		if str(soldier.get("loc", "")) == "casualties":
			casualties.append(soldier.get("id"))
	var cover := find_by_id(state["covers"], str(target.get("coverId", ""))) if str(target.get("coverId", "")) != "" else {}
	var unit := find_by_id(state["equipment"], str(target.get("unitId", ""))) if str(target.get("unitId", "")) != "" else {}
	return {
		"casualties": casualties,
		"coverRevealed": bool(cover.get("revealed", false)) if not cover.is_empty() else false,
		"coverDestroyed": bool(cover.get("destroyed", false)) if not cover.is_empty() else false,
		"unitDamage": unit.get("damage", null) if not unit.is_empty() else null,
		"unitLoc": unit.get("loc", null) if not unit.is_empty() else null,
	}


static func _mortar_phrases(state: Dictionary, target: Dictionary, before: Dictionary) -> Array:
	var phrases: Array = []
	var eliminated := 0
	var prior: Array = before.get("casualties", [])
	for soldier in state["soldiers"]:
		if str(soldier.get("loc", "")) == "casualties" and not prior.has(soldier.get("id")):
			eliminated += 1
	if eliminated == 1:
		phrases.append("soldier eliminated")
	elif eliminated > 1:
		phrases.append("%d soldiers eliminated" % eliminated)
	if str(target.get("coverId", "")) != "":
		var cover := find_by_id(state["covers"], str(target.get("coverId", "")))
		if not cover.is_empty() and bool(cover.get("destroyed", false)) and not bool(before.get("coverDestroyed", false)):
			phrases.append("cover destroyed")
		elif not cover.is_empty() and bool(cover.get("revealed", false)) and not bool(before.get("coverRevealed", false)):
			phrases.append("cover revealed")
	if str(target.get("unitId", "")) != "":
		var unit := find_by_id(state["equipment"], str(target.get("unitId", "")))
		if not unit.is_empty() and str(before.get("unitLoc", "")) != "supply" and str(unit.get("loc", "")) == "supply":
			phrases.append("weapon destroyed")
		elif not unit.is_empty() and before.get("unitDamage", null) != null and int(unit.get("damage", 0)) > int(before.get("unitDamage", 0)):
			phrases.append("weapon damaged")
	return phrases


static func _mark_mortar_fired(state: Dictionary, unit: Dictionary, hits: int, target: Dictionary) -> void:
	var side := str(unit.get("owner", ""))
	state["players"][side]["attackedIds"].append(unit.get("id"))
	state["players"][side]["firedEquip"].append(unit.get("id"))
	refresh_control(state)
	var choosing := check_missions(state, side, {"timing": "combat", "hits": hits, "target": target}) == "choose"
	state["combat"] = null
	_clear_roll(state)
	if choosing:
		return
	state["pending"] = {"type": "action", "step": "attack"}
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")


static func _apply_mortar_hit(state: Dictionary, unit: Dictionary, target: Dictionary) -> void:
	var side := str(unit.get("owner", ""))
	log_line(state, "Mortar places 1 Hit on %s in %s." % [str(target.get("label", "")), zone_label(str(target.get("zone", "")))])
	var before := _remember_mortar(state, target)
	apply_hits(state, side, target, 1)
	push_fx(state, {"kind": "mortar", "from": _mortar_origin(unit), "zone": target.get("zone"), "side": side})
	var phrases := _mortar_phrases(state, target, before)
	var detail := ", ".join(phrases) if not phrases.is_empty() else "no soldiers killed"
	_show_notice(state, side, "%s's mortar hits %s: %s." % [label_side(side), zone_label(str(target.get("zone", ""))), detail])
	_mark_mortar_fired(state, unit, 1, target)


static func _offer_mortar_hit(state: Dictionary, unit: Dictionary, zone: String) -> void:
	var side := str(unit.get("owner", ""))
	var options := _mortar_options(state, side, zone)
	if options.is_empty():
		log_line(state, "Mortar hit on %s is lost. No eligible target." % zone_label(zone))
		push_fx(state, {"kind": "mortar", "from": _mortar_origin(unit), "zone": zone, "side": side})
		_show_notice(state, side, "%s's mortar hits %s: no soldiers killed." % [label_side(side), zone_label(zone)])
		_mark_mortar_fired(state, unit, 0, {"zone": zone})
		return
	var pick: Dictionary = options[0]
	for option in options:
		if str(option.get("kind", "")) == "exposed":
			pick = option
			break
	_apply_mortar_hit(state, unit, pick)


static func _mortar_attack(state: Dictionary, unit_id: String, target: Dictionary) -> String:
	var side := str(state.get("active", ""))
	var unit := find_by_id(state["equipment"], unit_id)
	if unit.is_empty() or str(unit.get("type", "")) != "mortar" or str(unit.get("owner", "")) != side or int(unit.get("damage", 0)) >= 1:
		return "Mortar cannot fire."
	var mobile: Array = state["effects"].get("mobility", [])
	if state["players"][side]["movedEquip"].has(unit.get("id")) and not mobile.has(unit.get("id")):
		return "Mortar already moved."
	if str(state["effects"].get("suppression", "")) == "mortar" and str(unit.get("owner", "")) != str(state["effects"].get("suppressionBy", "")):
		return "Suppressed Mortars cannot attack."
	var precision: Array = state["effects"].get("precision", [])
	if precision.has(unit.get("id")):
		var zone := str(target.get("zone", ""))
		if not is_battlefield(zone):
			return "Choose a battlefield zone."
		log_line(state, "Precision Barrage aims at %s." % zone_label(zone))
		_offer_mortar_hit(state, unit, zone)
		return ""
	var spotter: Array = state["effects"].get("spotter", [])
	if spotter.has(unit.get("id")):
		var first := roll_mortar_die(state)
		var second := roll_mortar_die(state)
		log_line(state, "Spotter Mortar Die: %s / %s." % [_mortar_label(side, first), _mortar_label(side, second)])
		state["lastRoll"] = {"kind": "mortar", "faces": [first, second]}
		if is_interactive(state, side) and first != second:
			state["pending"] = {"type": "spotter", "side": side, "options": [first, second], "unitId": unit.get("id")}
			return ""
		var score_a := _mortar_options(state, side, _map_mortar_zone(side, first)).size()
		var score_b := _mortar_options(state, side, _map_mortar_zone(side, second)).size()
		_offer_mortar_hit(state, unit, _map_mortar_zone(side, second if score_b > score_a else first))
		return ""
	var face := roll_mortar_die(state)
	log_line(state, "Mortar Die: %s." % _mortar_label(side, face))
	state["lastRoll"] = {"kind": "mortar", "faces": [face]}
	_offer_mortar_hit(state, unit, _map_mortar_zone(side, face))
	return ""


static func _pick_spotter(state: Dictionary, action: Dictionary) -> String:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	if str(pending.get("type", "")) != "spotter":
		return "No spotter choice is waiting."
	var options: Array = pending.get("options", [])
	var face := str(action.get("face", ""))
	if not options.has(face):
		face = str(options[0]) if not options.is_empty() else ""
	var unit := find_by_id(state["equipment"], str(pending.get("unitId", "")))
	if unit.is_empty():
		return "Mortar cannot fire."
	log_line(state, "Spotter chooses %s." % _mortar_label(str(unit.get("owner", "")), face))
	state["pending"] = {"type": "action", "step": "attack"}
	_offer_mortar_hit(state, unit, _map_mortar_zone(str(unit.get("owner", "")), face))
	return ""


static func _allocate_mortar(state: Dictionary, action: Dictionary) -> String:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	if str(pending.get("type", "")) != "mortar-target":
		return "No mortar hit is waiting."
	var options: Array = pending.get("options", [])
	var pick: Dictionary = options[0] if not options.is_empty() else {}
	for option in options:
		if str(option.get("id", "")) == str(action.get("targetId", "")):
			pick = option
			break
	var unit := find_by_id(state["equipment"], str(pending.get("unitId", "")))
	state["pending"] = {"type": "action", "step": "attack"}
	if unit.is_empty() or pick.is_empty():
		return "No mortar hit is waiting."
	_apply_mortar_hit(state, unit, pick)
	return ""


static func _tank_attack(state: Dictionary, unit_id: String, target: Dictionary) -> String:
	var side := str(state.get("active", ""))
	var unit := find_by_id(state["equipment"], unit_id)
	if unit.is_empty() or str(unit.get("type", "")) != "tank" or str(unit.get("owner", "")) != side:
		return "Tank not found."
	if zone_distance(str(unit.get("loc", "")), str(target.get("zone", ""))) > 1:
		return "Tank out of range."
	if str(target.get("kind", "")) == "cover-empty":
		return "Tanks cannot make a normal attack against Cover. Use Overrun."
	if smoked(state, str(unit.get("loc", "")), str(target.get("zone", ""))):
		return "Smoke Screen blocks this fire."
	var result := roll_hits(state, 3)
	log_line(state, "%s Tank fires 3 dice -> %d Hit(s) [%s]." % [label_side(side), int(result["hits"]), ", ".join(result["faces"])])
	_settle_direct_hits(state, side, target, result, [unit])
	return ""


static func _resolve_attack(state: Dictionary, action: Dictionary) -> String:
	var side := str(state.get("active", ""))
	var target: Dictionary = action.get("target", {}) if action.get("target") is Dictionary else {}
	if target.is_empty() and state.get("combat") is Dictionary:
		target = state["combat"].get("target", {})
	if target.is_empty():
		return "No target."
	if bool(state["effects"].get("christmasTruce", false)):
		return "Christmas Truce: no attacks."
	var kind := str(action.get("kind", ""))
	if kind == "" and state.get("combat") is Dictionary:
		kind = str(state["combat"].get("kind", ""))
	if kind == "mortar":
		var unit_id := str(action.get("unitId", ""))
		if unit_id == "" and state.get("combat") is Dictionary:
			unit_id = str(state["combat"].get("unitId", ""))
		return _mortar_attack(state, unit_id, target)
	if kind == "tank":
		var unit_id := str(action.get("unitId", ""))
		if unit_id == "" and state.get("combat") is Dictionary:
			unit_id = str(state["combat"].get("unitId", ""))
		return _tank_attack(state, unit_id, target)
	var attackers: Array = []
	var ids: Array = action.get("attackerIds", [])
	if ids.is_empty() and state.get("combat") is Dictionary:
		ids = state["combat"].get("attackerIds", [])
	for id in ids:
		var soldier := find_by_id(state["soldiers"], str(id))
		var unit := find_by_id(state["equipment"], str(id))
		if not soldier.is_empty():
			attackers.append(soldier)
		elif not unit.is_empty():
			attackers.append(unit)
	if attackers.is_empty():
		return "No attackers."
	var gun_count := 0
	for attacker in attackers:
		if str(attacker.get("type", "")) == "mg":
			gun_count += 1
			if int(attacker.get("damage", 0)) >= 1:
				return "A damaged Machine Gun is disabled."
		if state["players"][side]["attackedIds"].has(attacker.get("id")):
			return "A Unit already attacked."
		if str(attacker.get("type", "")) != "" and state["players"][side]["movedEquip"].has(attacker.get("id")):
			return "That weapon already moved."
		if str(attacker.get("type", "")) == "mg" and str(state["effects"].get("suppression", "")) == "mg" and str(attacker.get("owner", "")) != str(state["effects"].get("suppressionBy", "")):
			return "Suppressed Machine Guns cannot attack."
	if gun_count > 1:
		return "Combined fire uses one machine gun."
	var dice := 0
	var soldier_count := 0
	for attacker in attackers:
		if str(attacker.get("type", "")) == "":
			if str(attacker.get("owner", "")) != side:
				return "Those are not your soldiers."
			if not can_soldier_target(attacker, target):
				return "Illegal Soldier target."
			dice += 1
			soldier_count += 1
		elif str(attacker.get("type", "")) == "mg":
			if str(target.get("kind", "")) == "tank":
				return "Machine Guns cannot target Tanks."
			if zone_distance(str(attacker.get("loc", "")), str(target.get("zone", ""))) > 2:
				return "Machine Gun out of range."
			if smoked(state, str(attacker.get("loc", "")), str(target.get("zone", ""))):
				return "Smoke Screen blocks this fire."
			dice += 4 if str(target.get("zone", "")) == "obj" else 3
		else:
			return "That Unit cannot join this attack."
	if str(state["effects"].get("cavalryCharge", "")) == side and soldier_count > 0:
		dice += 1
	var result := roll_hits(state, dice)
	var lead := "%s attack" % label_side(side)
	if soldier_count > 0 and gun_count > 0:
		var word := "soldier" if soldier_count == 1 else "soldiers"
		lead = "%s combined fire (%d %s and the machine gun)" % [label_side(side), soldier_count, word]
	log_line(state, "%s rolls %d dice -> %d Hit(s) [%s]." % [lead, dice, int(result["hits"]), ", ".join(result["faces"])])
	_settle_direct_hits(state, side, target, result, attackers)
	return ""


static func _start_attack(state: Dictionary, action: Dictionary) -> String:
	if bool(state["effects"].get("christmasTruce", false)):
		return "Christmas Truce: no attacks."
	if str(state.get("actionStep", "")) != "attack":
		return "Not the Attack step."
	state["combat"] = {
		"side": state.get("active"),
		"kind": action.get("kind"),
		"attackerIds": action.get("attackerIds", []),
		"unitId": action.get("unitId", null),
		"target": action.get("target", {}),
	}
	var follow := action.duplicate(true)
	follow["auto"] = true
	return _resolve_attack(state, follow)


static func _do_overrun(state: Dictionary, action: Dictionary) -> String:
	if bool(state["effects"].get("christmasTruce", false)):
		return "Christmas Truce: no Overrun."
	if str(state.get("actionStep", "")) != "attack":
		return "Not the Attack step."
	var side := str(state.get("active", ""))
	var tank := find_by_id(state["equipment"], str(action.get("unitId", "")))
	var cover := find_by_id(state["covers"], str(action.get("coverId", "")))
	if tank.is_empty() or str(tank.get("type", "")) != "tank" or str(tank.get("owner", "")) != side or cover.is_empty() or bool(cover.get("destroyed", false)) or str(cover.get("loc", "")) != str(tank.get("loc", "")):
		return "Overrun must target Cover in the Tank's zone."
	if not units_in(state, str(tank.get("loc", "")), {"side": other(side), "type": "tank"}).is_empty():
		return "An engaged Tank cannot Overrun."
	for soldier in soldiers_in(state, str(cover.get("loc", "")), {"matchCover": true, "coverId": cover.get("id")}):
		soldier["coverId"] = null
	take_cover_trophy(state, side, cover)
	state["players"][side]["attackedIds"].append(tank.get("id"))
	log_line(state, "%s Tank Overruns Cover. Occupants become exposed." % label_side(side))
	refresh_control(state)
	check_missions(state, side, {"timing": "combat", "overrun": true})
	_clear_roll(state)
	return ""


static func _allocate_hits(state: Dictionary, action: Dictionary) -> String:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	if str(pending.get("type", "")) != "allocate-hits":
		return "No hits are waiting."
	var side := str(pending.get("side", ""))
	var target: Dictionary = pending.get("target", {})
	if bool(action.get("auto", false)):
		if is_interactive(state, side):
			return "Assign the hits."
		apply_hits(state, side, target, int(pending.get("hits", 0)))
		_close_direct_fire(state, side, target, int(pending.get("hits", 0)))
		return ""
	var picks: Array = action.get("picks", [])
	if not allocation_ready(pending, picks):
		return "Assign every hit."
	apply_allocated_hits(state, side, target, picks, int(pending.get("hits", 0)))
	_close_direct_fire(state, side, target, int(pending.get("hits", 0)))
	return ""


static func _finish_action_phase(state: Dictionary) -> String:
	_clear_roll(state)
	var nxt := other(str(state.get("active", "")))
	if str(state.get("active", "")) == str(state.get("player1", "")):
		return _start_action_phase(state, nxt)
	return _start_regroup(state)


static func _start_regroup(state: Dictionary) -> String:
	state["phase"] = "regroup"
	state["actionStep"] = null
	state["regroupDone"] = {"uk": false, "de": false}
	var both := str(state.get("mode", "")) == "hotseat" or str(state.get("mode", "")) == "sim"
	var first := str(state.get("player1", "")) if both else str(state.get("human", ""))
	state["active"] = first
	state["pending"] = {"type": "regroup", "side": first}
	log_line(state, "Regroup. Exchange up to 2 unused dice for Soldiers, then draw 1 Event.")
	return ""


static func _regroup_exchange(state: Dictionary) -> String:
	var side := str(state.get("active", ""))
	if str(state.get("phase", "")) != "regroup":
		return "Not Regroup."
	var who: Dictionary = state["players"][side]
	if int(who.get("regroupExchanged", 0)) >= 2:
		return "Only 2 Soldiers may be taken this way."
	var trench := own_trench(side)
	if soldiers_in_loc(state, side, trench) >= 5:
		return "The Trench already holds 5 Soldiers."
	var soldier := {}
	for piece in state["soldiers"]:
		if str(piece.get("owner", "")) == side and str(piece.get("loc", "")) == "available":
			soldier = piece
			break
	if soldier.is_empty():
		return "No Soldier in supply."
	var face := ""
	for name in ["shovel", "whistle", "boot", "bayonet"]:
		if remaining(state, side, name) > 0:
			face = name
			break
	if face == "":
		return "No unused Action Dice."
	spend(state, side, face, 1)
	soldier["loc"] = trench
	soldier["coverId"] = null
	who["regroupExchanged"] = int(who.get("regroupExchanged", 0)) + 1
	log_line(state, "%s exchanges 1 %s for a Soldier in the Trench (%d/2)." % [label_side(side), face, int(who["regroupExchanged"])])
	return ""


static func draw_event(state: Dictionary, side: String, source: String) -> void:
	var card = null
	if source != "" and source != "deck":
		for index in state["eventDisplay"].size():
			if str(state["eventDisplay"][index].get("inst", "")) == source:
				card = state["eventDisplay"][index]
				if not state["eventDeck"].is_empty():
					state["eventDisplay"][index] = state["eventDeck"].pop_back()
				else:
					state["eventDisplay"][index] = null
				var cleaned: Array = []
				for entry in state["eventDisplay"]:
					if entry != null:
						cleaned.append(entry)
				state["eventDisplay"] = cleaned
				while state["eventDisplay"].size() < 3 and not state["eventDeck"].is_empty():
					state["eventDisplay"].append(state["eventDeck"].pop_back())
				break
	else:
		if not state["eventDeck"].is_empty():
			card = state["eventDeck"].pop_back()
	if card == null:
		log_line(state, "Event deck is empty.")
		return
	state["players"][side]["eventHand"].append(card)
	log_line(state, "%s draws %s." % [label_side(side), str(card.get("title", ""))])


static func _regroup_draw(state: Dictionary, action: Dictionary) -> String:
	var side := str(action.get("side", state.get("active", "")))
	if str(state.get("phase", "")) != "regroup":
		return "Not Regroup."
	if side != str(state.get("active", "")):
		return "It is not your Regroup."
	var who: Dictionary = state["players"][side]
	if bool(who.get("regroupDrew", false)):
		return "You already drew an Event this Regroup."
	if who["eventHand"].size() >= 7:
		return "Event hand is full."
	draw_event(state, side, str(action.get("source", "deck")))
	who["regroupDrew"] = true
	return ""


static func _run_scheduled(state: Dictionary, sides: Array) -> bool:
	if str(state.get("phase", "")) == "end":
		return true
	if sides.is_empty():
		return false
	var side := str(sides[0])
	var rest: Array = sides.slice(1)
	var card = draw_mission(state, true)
	if card == null:
		_end_game(state, "Mission Exhaustion")
		return true
	state["players"][side]["missionHand"].append(card)
	log_line(state, "%s draws a scheduled Mission (%s)." % [label_side(side), str(card.get("title", ""))])
	if check_missions(state, side, {"timing": "immediate"}) == "choose":
		state["pending"]["after"] = {"kind": "scheduled", "side": side, "rest": rest}
		return true
	trim_missions(state, side)
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")
		return true
	return _run_scheduled(state, rest)


static func _scheduled_missions(state: Dictionary) -> bool:
	if not [3, 6, 9].has(int(state.get("round", 0))):
		return false
	return _run_scheduled(state, [state.get("player1"), other(str(state.get("player1", "")))])


static func _award_kills(state: Dictionary, side: String, britain_kills: int, germany_kills: int) -> void:
	state["vp"][side] = int(state["vp"][side]) + 1
	_show_notice(state, side, "%s gains 1 victory point for the most kills this round (Britain %d, Germany %d)." % [label_side(side), britain_kills, germany_kills])


static func _casualty_superiority(state: Dictionary) -> void:
	var count := func(side: String) -> int:
		var total := 0
		for soldier in state["soldiers"]:
			if str(soldier.get("owner", "")) == side and str(soldier.get("loc", "")) == "casualties" and not bool(soldier.get("overflow", false)):
				total += 1
		return total
	var britain := count.call("uk")
	var germany := count.call("de")
	if britain > germany:
		_award_kills(state, "de", germany, britain)
	elif germany > britain:
		_award_kills(state, "uk", germany, britain)
	else:
		log_line(state, "Casualty totals are tied (%d–%d). Neither side scores." % [britain, germany])


static func _finish_round(state: Dictionary, brief_start: int) -> void:
	if str(state.get("phase", "")) == "end":
		return
	var closing: Array = []
	var brief: Array = state.get("roundBrief", [])
	for index in range(brief_start, brief.size()):
		closing.append(brief[index].get("text", ""))
	for soldier in state["soldiers"]:
		if str(soldier.get("loc", "")) == "casualties":
			soldier["loc"] = "available"
			soldier["overflow"] = false
	state["roundElim"] = {"uk": 0, "de": 0}
	state["roundBurst"] = {"uk": false, "de": false}
	state["roundSupportKill"] = {"uk": false, "de": false}
	state["roundTankKill"] = {"uk": false, "de": false}
	for side in ["uk", "de"]:
		state["players"][side]["regroupDraws"] = 0
	if bool(state.get("missionExhausted", false)):
		_end_game(state, "Mission Exhaustion")
		return
	if int(state.get("round", 1)) >= int(state.get("maxRounds", 10)):
		_end_game(state, "Final round")
		return
	state["round"] = int(state["round"]) + 1
	state["roundBrief"] = []
	for text in closing:
		push_brief(state, str(text))
	log_line(state, "Round %d begins." % int(state["round"]))
	begin_initiative(state)


static func _end_round(state: Dictionary) -> String:
	var brief_start := state.get("roundBrief", []).size() if state.get("roundBrief") is Array else 0
	_casualty_superiority(state)
	if check_missions(state, "uk", {"timing": "end"}) == "choose":
		state["pending"]["after"] = {"kind": "end-de", "briefStart": brief_start}
		return ""
	if check_missions(state, "de", {"timing": "end"}) == "choose":
		state["pending"]["after"] = {"kind": "finish-round", "briefStart": brief_start}
		return ""
	_finish_round(state, brief_start)
	return ""


static func _skip_regroup(state: Dictionary) -> String:
	if str(state.get("phase", "")) != "regroup":
		return "Not Regroup."
	state["regroupDone"][state["active"]] = true
	var nxt := other(str(state.get("active", "")))
	var both := str(state.get("mode", "")) == "hotseat" or str(state.get("mode", "")) == "sim"
	if (both and not bool(state["regroupDone"].get(nxt, false))) or (not both and str(state.get("active", "")) == str(state.get("human", ""))):
		var next_side := nxt if both else str(state.get("ai", ""))
		if not bool(state["regroupDone"].get(next_side, false)):
			state["active"] = next_side
			state["pending"] = {"type": "regroup", "side": next_side}
			return ""
	if _scheduled_missions(state):
		return ""
	if str(state.get("phase", "")) == "end":
		return ""
	return _end_round(state)


static func _after_mission_choice(state: Dictionary, after) -> String:
	if str(state.get("phase", "")) == "end":
		return ""
	if after == null:
		_settle_pending(state)
		return ""
	if not (after is Dictionary):
		_settle_pending(state)
		return ""
	var kind := str(after.get("kind", ""))
	if kind == "advance-step":
		return _advance_step(state)
	if kind == "finish-tank":
		var tank := find_by_id(state["equipment"], str(after.get("tankId", "")))
		if not tank.is_empty():
			var err := _finish_tank_move(state, tank)
			if err != "":
				return err
		var pending_type := str(state.get("pending", {}).get("type", ""))
		if str(state.get("phase", "")) != "end" and pending_type != "action" and pending_type != "pick-mission":
			_settle_pending(state)
		return ""
	if kind == "gambit-auto":
		trim_missions(state, str(after.get("side", "")))
		if bool(state.get("missionExhausted", false)):
			_end_game(state, "Mission Exhaustion")
			return ""
		return _advance_step(state)
	if kind == "gambit-swap":
		state["pending"] = {"type": "gambit", "side": after.get("side"), "stage": "swap"}
		return ""
	if kind == "scheduled":
		trim_missions(state, str(after.get("side", "")))
		if bool(state.get("missionExhausted", false)):
			_end_game(state, "Mission Exhaustion")
			return ""
		if _run_scheduled(state, after.get("rest", [])):
			return ""
		return _end_round(state)
	if kind == "end-de":
		if check_missions(state, "de", {"timing": "end"}) == "choose":
			state["pending"]["after"] = {"kind": "finish-round", "briefStart": after.get("briefStart", 0)}
			return ""
		_finish_round(state, int(after.get("briefStart", 0)))
		return ""
	if kind == "finish-round":
		_finish_round(state, int(after.get("briefStart", 0)))
	return ""


static func _do_pick_mission(state: Dictionary, action: Dictionary) -> String:
	var result = choose_mission(state, str(action.get("inst", "")))
	if result is String:
		return result
	return _after_mission_choice(state, result)


static func _handle(state: Dictionary, action: Dictionary) -> String:
	state["error"] = null
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	var pending_type := str(pending.get("type", ""))
	var kind := str(action.get("type", ""))
	if pending_type == "spotter" and kind != "PICK_SPOTTER":
		return "Choose a mortar result first."
	if pending_type == "mortar-target" and kind != "ALLOCATE_MORTAR":
		return "Choose where the mortar hit lands."
	if pending_type == "gambit" and kind != "PICK_GAMBIT" and kind != "FINISH_GAMBIT":
		return "Finish the Mission Gambit first."
	if pending_type == "allocate-hits" and kind != "ALLOCATE_HITS":
		return "Assign the hits first."
	if pending_type == "pick-mission" and kind != "PICK_MISSION":
		return "Choose one mission to complete."
	var err := ""
	if kind == "ROLL_1":
		err = _do_roll1(state)
	elif kind == "GENERALS_ORDER":
		err = _do_generals_order(state, action)
	elif kind == "SKIP_GENERALS_ORDER":
		err = _finish_generals_order(state)
	elif kind == "TOGGLE_KEEP":
		err = _toggle_keep(state, action)
	elif kind == "REROLL":
		err = _do_reroll(state, action)
	elif kind == "COMMIT":
		err = _do_commit(state, action)
	elif kind == "SHOCK":
		err = _do_shock(state, action)
	elif kind == "SKIP_SHOCK" or kind == "SKIP_TANK" or kind == "SKIP_EVENT" or kind == "SKIP_DEPLOY" or kind == "SKIP_MOVE" or kind == "SKIP_COVER":
		err = _advance_step(state)
	elif kind == "MOVE_TANK":
		err = _move_tank(state, action)
	elif kind == "PLAY_EVENT":
		err = _do_play_event(state, action)
	elif kind == "DEPLOY":
		err = _do_deploy(state, action)
	elif kind == "REPAIR":
		err = _do_repair(state, action)
	elif kind == "MOVE_UNIT":
		err = _do_move(state, action)
	elif kind == "LEAVE_COVER_THEN_MOVE":
		err = _leave_then_move(state, action)
	elif kind == "SHOVEL":
		err = _do_shovel(state, action)
	elif kind == "START_ATTACK":
		err = _start_attack(state, action)
	elif kind == "RESOLVE_ATTACK":
		err = _resolve_attack(state, action)
	elif kind == "PICK_SPOTTER":
		err = _pick_spotter(state, action)
	elif kind == "ALLOCATE_MORTAR":
		err = _allocate_mortar(state, action)
	elif kind == "ALLOCATE_HITS":
		err = _allocate_hits(state, action)
	elif kind == "PICK_GAMBIT":
		err = _pick_gambit(state, action)
	elif kind == "FINISH_GAMBIT":
		err = _finish_gambit(state, action)
	elif kind == "PICK_MISSION":
		err = _do_pick_mission(state, action)
	elif kind == "OVERRUN":
		err = _do_overrun(state, action)
	elif kind == "SKIP_ATTACK":
		err = _finish_action_phase(state)
	elif kind == "REGROUP_DRAW":
		err = _regroup_draw(state, action)
	elif kind == "REGROUP_EXCHANGE":
		err = _regroup_exchange(state)
	elif kind == "SKIP_REGROUP":
		err = _skip_regroup(state)
	else:
		err = "Unknown action %s" % kind
	return err


static func apply(state: Dictionary, action: Dictionary) -> Dictionary:
	var nxt: Dictionary = clone_value(state)
	var err := _handle(nxt, action if action != null else {})
	if err == "":
		nxt["error"] = null
		if bool(nxt.get("missionExhausted", false)) and str(nxt.get("phase", "")) != "end":
			_end_game(nxt, "Mission Exhaustion")
		return nxt
	var failed: Dictionary = clone_value(state)
	log_line(failed, "Action failed: %s" % err)
	failed["error"] = err
	return failed


static func automatic_action(state: Dictionary) -> Dictionary:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	var kind := str(pending.get("type", ""))
	if kind == "mortar-target":
		var options: Array = pending.get("options", [])
		var pick: Dictionary = {}
		for option in options:
			if str(option.get("kind", "")) == "exposed":
				pick = option
				break
		if pick.is_empty() and not options.is_empty():
			pick = options[0]
		if pick.is_empty():
			return {}
		return {"type": "ALLOCATE_MORTAR", "targetId": pick.get("id")}
	if str(state.get("phase", "")) == "initiative" and kind == "roll1":
		return {"type": "ROLL_1"}
	if str(state.get("phase", "")) == "regroup" and str(state.get("active", "")) != "" and not can_regroup(state, str(state.get("active", ""))):
		return {"type": "SKIP_REGROUP"}
	if str(state.get("phase", "")) == "reroll" and str(state.get("active", "")) != "":
		var who: Dictionary = state["players"][state["active"]]
		if not bool(who.get("committed", false)) and not has_wild_face(who.get("dice", [])) and int(who.get("rollsUsed", 0)) >= 3:
			return {"type": "COMMIT"}
	if str(state.get("phase", "")) == "action" and should_skip_step(state, str(state.get("active", "")), str(state.get("actionStep", ""))):
		var skip := str(SKIP.get(str(state.get("actionStep", "")), ""))
		if skip != "":
			return {"type": skip}
	return {}


static func fallback_skip(state: Dictionary) -> Dictionary:
	var pending: Dictionary = state.get("pending", {}) if state.get("pending") is Dictionary else {}
	var kind := str(pending.get("type", ""))
	if kind == "gambit" and str(pending.get("stage", "")) == "keep":
		var cards: Array = pending.get("cards", [])
		if cards.is_empty():
			return {"type": "FINISH_GAMBIT"}
		var best: Dictionary = cards[0]
		for card in cards:
			if int(card.get("vp", 0)) > int(best.get("vp", 0)):
				best = card
		return {"type": "PICK_GAMBIT", "inst": best.get("inst")}
	if kind == "gambit":
		return {"type": "FINISH_GAMBIT"}
	if kind == "generals-order":
		return {"type": "SKIP_GENERALS_ORDER"}
	if kind == "spotter":
		var options: Array = pending.get("options", [])
		return {"type": "PICK_SPOTTER", "face": options[0] if not options.is_empty() else ""}
	if kind == "allocate-hits":
		return {"type": "ALLOCATE_HITS", "auto": true}
	if kind == "pick-mission":
		return preferred_mission_action(state)
	if str(state.get("phase", "")) == "reroll":
		return {"type": "COMMIT"}
	if str(state.get("phase", "")) == "regroup":
		return {"type": "SKIP_REGROUP"}
	if str(state.get("phase", "")) == "action":
		var skip := str(SKIP.get(str(state.get("actionStep", "")), ""))
		if skip != "":
			return {"type": skip}
	return {}


static func needs_human(state: Dictionary) -> bool:
	if str(state.get("phase", "")) == "end":
		return false
	var side := actor_side(state)
	if side == "" or not is_interactive(state, side):
		return false
	if str(state.get("phase", "")) == "regroup" and not can_regroup(state, side):
		return false
	return true

