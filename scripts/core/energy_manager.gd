class_name EnergyManager
extends RefCounted

# 玩家能量字典（key: player_id, value: energy）
var player_energy: Dictionary = {}

# 能量上限
const MAX_ENERGY: int = 5

# 初始能量
const INITIAL_ENERGY: int = 1

signal energy_changed(player_id: int, old_energy: int, new_energy: int)
signal energy_maxed(player_id: int)

func _init():
	pass

# 初始化玩家能量
func initialize_player(player_id: int):
	player_energy[player_id] = INITIAL_ENERGY

# 获取玩家能量
func get_energy(player_id: int) -> int:
	return player_energy.get(player_id, INITIAL_ENERGY)

# 设置玩家能量
func set_energy(player_id: int, amount: int):
	var old_energy = get_energy(player_id)
	var new_energy = clamp(amount, 0, MAX_ENERGY)
	player_energy[player_id] = new_energy
	energy_changed.emit(player_id, old_energy, new_energy)
	
	if new_energy >= MAX_ENERGY:
		energy_maxed.emit(player_id)

# 增加能量
func add_energy(player_id: int, amount: int):
	var current = get_energy(player_id)
	set_energy(player_id, current + amount)

# 消耗能量
func consume_energy(player_id: int, amount: int) -> bool:
	var current = get_energy(player_id)
	if current < amount:
		return false
	
	set_energy(player_id, current - amount)
	return true

# 检查是否有足够能量
func has_enough_energy(player_id: int, amount: int) -> bool:
	return get_energy(player_id) >= amount

# 他人使用己方卡牌：卡牌原持有者获得1点能量
func on_card_used_by_other(card_owner_id: int, user_id: int):
	if card_owner_id != user_id and card_owner_id >= 0:
		add_energy(card_owner_id, 1)

# 占领公共争夺点：获得1点能量
func on_contest_point_captured(player_id: int):
	add_energy(player_id, 1)
	# 信号已在其他地方使用，保留此函数

# 持有赏金：每回合结束时获得1点能量
func on_bounty_held(player_id: int):
	add_energy(player_id, 1)

# 租用精灵：消耗1点能量
func rent_sprite(player_id: int) -> bool:
	return consume_energy(player_id, 1)

# 使用卡牌：消耗卡牌对应的能量
func use_card(player_id: int, energy_cost: int) -> bool:
	return consume_energy(player_id, energy_cost)

