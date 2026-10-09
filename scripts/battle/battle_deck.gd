extends RefCounted
const Types = preload("res://scripts/data/combat_types.gd")

# One battle owns these piles. No UI, profile or global random state.
var draw_pile: Array[Types.CardType] = []
var discard_pile: Array[Types.CardType] = []

func reset(cards: Array, random_roll: Callable) -> void:
	draw_pile.assign(cards)
	discard_pile.clear()
	shuffle(random_roll)


func shuffle(random_roll: Callable) -> void:
	for index in range(draw_pile.size() - 1, 0, -1):
		var other: int = random_roll.call(0, index)
		var card := draw_pile[index]
		draw_pile[index] = draw_pile[other]
		draw_pile[other] = card


func take_top(random_roll: Callable) -> int:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return -1
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		shuffle(random_roll)
	return draw_pile.pop_back()
