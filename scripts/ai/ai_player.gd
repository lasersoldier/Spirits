class_name AIPlayer
extends RefCounted

# AI难度等级
enum Difficulty {
	EASY,    # 简易
	NORMAL,  # 标准
	HARD     # 困难
}

# 玩家ID
var player_id: int = -1

# 难度等级
var difficulty: Difficulty = Difficulty.NORMAL

# AI决策器
var decision_maker: AIDecisionMaker

# 系统引用
var game_map: GameMap
var sprites: Array[Sprite] = []
var hand_manager: HandCardManager
var energy_manager: EnergyManager
var contest_point_manager: ContestPointManager

func _init(p_id: int, diff: Difficulty, map: GameMap, sprites_array: Array[Sprite], hand_mgr: HandCardManager, energy_mgr: EnergyManager, contest_mgr: ContestPointManager):
	player_id = p_id
	difficulty = diff
	game_map = map
	sprites = sprites_array
	hand_manager = hand_mgr
	energy_manager = energy_mgr
	contest_point_manager = contest_mgr
	
	decision_maker = AIDecisionMaker.new(self, map, sprites_array, hand_mgr, energy_mgr, contest_mgr, diff)

# 生成本回合的行动指令
func generate_actions() -> Array[ActionResolver.Action]:
	return decision_maker.make_decisions()

# 更新AI状态（每回合开始时调用）
func update_state():
	decision_maker.update_state()

