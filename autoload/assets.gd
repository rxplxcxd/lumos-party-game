extends Node
## Zentraler Asset-Katalog & Instanzierungs-Helfer.
##
## Alle Modelle werden über kurze Schlüssel ("pirate/chest") referenziert. Der
## Katalog ist gleichzeitig Quelle für tools/dev/export_list.gd, das daraus die
## Export-Liste des Web-Builds erzeugt (nur verwendete Assets landen in der PWA).

const KP := "res://assets/3d/tracks-enviroment/kenney_pirate-kit/Models/GLB format/"
const KPL := "res://assets/3d/minigames-and-others/kenney_platformer-kit/Models/GLB format/"
const KC := "res://assets/3d/minigames-and-others/kenney_castle-kit/Models/GLB format/"
const KG := "res://assets/3d/minigames-and-others/kenney_graveyard-kit_5.0/Models/GLB format/"
const KR := "res://assets/3d/tracks-enviroment/kenney_racing-kit/Models/GLTF format/"
const KCAR := "res://assets/3d/vehicles/kenney_car-kit/Models/GLB format/"
const KTOY := "res://assets/3d/vehicles/kenney_toy-car-kit/Models/GLB format/"
const KSV := "res://assets/3d/minigames-and-others/kenney_survival-kit/Models/GLB format/"
const KSP := "res://assets/3d/tracks-enviroment/kenney_space-kit/Models/GLTF format/"
const KN := "res://assets/3d/tracks-enviroment/kenney_nature-kit/Models/GLTF format/"
const KAR := "res://assets/3d/tracks-enviroment/kenney_mini-arena/Models/GLB format/"
const KARC := "res://assets/3d/tracks-enviroment/kenney_mini-arcade/Models/GLB format/"
const KTD := "res://assets/3d/minigames-and-others/kenney_tower-defense-kit/Models/GLB format/"
const KCV := "res://assets/3d/minigames-and-others/kenney_modular-cave-kit_1.0/Models/GLB format/"
const KW := "res://assets/3d/vehicles/kenney_watercraft-pack/Models/GLB format/"
const KMC := "res://assets/3d/characters/kenney_mini-characters/Models/GLB format/"
const KPET := "res://assets/3d/characters/kenney_cube-pets_1.0/Models/GLB format/"
const KFT := "res://assets/3d/tracks-enviroment/kenney_fantasy-town-kit_2.0/Models/GLB format/"
const KHK := "res://assets/3d/tracks-enviroment/kenney_holiday-kit/Models/GLB format/"
const KADV := "res://assets/3d/characters/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/"
const KANIM := "res://assets/3d/characters/KayKit_Character_Animations_1.1/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/"
const KBG := "res://assets/3d/boardgame/KayKit_BoardGameBits_1.0_FREE/KayKit_BoardGameBits_1.0_FREE/Assets/gltf/"
const KDUN := "res://assets/3d/minigames-and-others/KayKit_Dungeon_Pack_1.1_FREE/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/"
const KMG := "res://assets/3d/minigames-and-others/KayKit Mini-Game Variety Pack 1.2/Models/gltf/"
const KMGC := "res://assets/3d/minigames-and-others/KayKit Mini-Game Variety Pack 1.2/Models/Characters/"
const KHOL := "res://assets/3d/minigames-and-others/KayKit_Holiday_Bits_1.0_FREE/KayKit_Holiday_Bits_1.0_FREE/Assets/gltf/"
const KFOR := "res://assets/3d/minigames-and-others/KayKit_Forest_Nature_Pack_1.0_FREE/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/"
const KRPG := "res://assets/3d/minigames-and-others/KayKit_RPGToolsBits_1.0_FREE/KayKit_RPGToolsBits_1.0_FREE/Assets/gltf/"
const KIP := "res://assets/3d/minigames-and-others/kenney_input-prompts_1.5/"
const KGOLF := "res://assets/3d/minigames-and-others/kenney_minigolf-kit/Models/GLB format/"
const KSS := "res://assets/3d/tracks-enviroment/kenney_space-station-kit/Models/GLB format/"
const KSB := "res://assets/3d/minigames-and-others/KayKit_Space_Base_Bits_1.0_FREE/KayKit_Space_Base_Bits_1.0_FREE/Assets/gltf/"
const KCITY := "res://assets/3d/tracks-enviroment/kenney_city-kit-commercial_2.1/Models/GLB format/"
const KSUB := "res://assets/3d/tracks-enviroment/kenney_city-kit-suburban_20/Models/GLB format/"

const MODELS := {
	# --- Helden (KayKit Adventurers, Rig_Medium) ---
	"hero/knight": KADV + "Knight.glb",
	"hero/barbarian": KADV + "Barbarian.glb",
	"hero/mage": KADV + "Mage.glb",
	"hero/ranger": KADV + "Ranger.glb",
	"hero/rogue": KADV + "Rogue.glb",
	"hero/rogue_hooded": KADV + "Rogue_Hooded.glb",
	# --- Mini-Charaktere & Tiere ---
	"mini/male_a": KMC + "character-male-a.glb",
	"mini/male_c": KMC + "character-male-c.glb",
	"mini/female_b": KMC + "character-female-b.glb",
	"mini/female_d": KMC + "character-female-d.glb",
	"mini/robot": KMC + "character-robot.glb",
	"mini/alien": KMC + "character-alien.glb",
	"mini/zombie": KMC + "character-zombie.glb",
	"mini/worker": KMC + "character-worker.glb",
	"pet/cat": KPET + "animal-cat.glb",
	"pet/bunny": KPET + "animal-bunny.glb",
	"pet/chick": KPET + "animal-chick.glb",
	"pet/crab": KPET + "animal-crab.glb",
	"pet/bee": KPET + "animal-bee.glb",
	"pet/cow": KPET + "animal-cow.glb",
	"pet/deer": KPET + "animal-deer.glb",
	"pet/penguin": KPET + "animal-penguin.glb",
	"pet/fox": KPET + "animal-fox.glb",
	"pet/pig": KPET + "animal-pig.glb",
	"pet/parrot": KPET + "animal-parrot.glb",
	"pet/polar": KPET + "animal-polar.glb",
	"pet/beaver": KPET + "animal-beaver.glb",
	"pet/caterpillar": KPET + "animal-caterpillar.glb",
	"pet/panda": KPET + "animal-panda.glb",
	"pet/koala": KPET + "animal-koala.glb",
	"pet/monkey": KPET + "animal-monkey.glb",
	"pet/dog": KPET + "animal-dog.glb",
	"pet/hog": KPET + "animal-hog.glb",
	"npc/bear": KMGC + "Bear/gltf/character_bear.gltf",
	"npc/dog": KMGC + "Dog/gltf/character_dog.gltf",
	"npc/duck": KMGC + "Duck/gltf/character_duck.gltf",
	"npc/ghost": KG + "character-ghost.glb",
	"npc/skeleton": KG + "character-skeleton.glb",
	"npc/keeper": KG + "character-keeper.glb",
	"npc/vampire": KG + "character-vampire.glb",
	# --- Brettspiel-Bits ---
	"bg/d6": KBG + "D6_A.gltf",
	"bg/d6_red": KBG + "D6_B_red.gltf",
	"bg/coin_gold": KBG + "coin_gold.gltf",
	"bg/coin_stack": KBG + "coin_10_gold.gltf",
	"bg/flag_red": KBG + "flag_A_red.gltf",
	"bg/flag_blue": KBG + "flag_A_blue.gltf",
	"bg/flag_green": KBG + "flag_A_green.gltf",
	"bg/flag_yellow": KBG + "flag_A_yellow.gltf",
	"bg/hourglass": KBG + "hourglass.gltf",
	"bg/tile_blue": KBG + "tile_blue.gltf",
	"bg/tile_red": KBG + "tile_red.gltf",
	"bg/tile_green": KBG + "tile_green.gltf",
	"bg/tile_yellow": KBG + "tile_yellow.gltf",
	"bg/tile_purple": KBG + "tile_purple.gltf",
	"bg/playerstand": KBG + "playerstand.gltf",
	"bg/building_blue": KBG + "building_blue.gltf",
	# --- Piraten ---
	"pirate/chest": KP + "chest.glb",
	"pirate/barrel": KP + "barrel.glb",
	"pirate/cannon": KP + "cannon.glb",
	"pirate/cannon_mobile": KP + "cannon-mobile.glb",
	"pirate/cannon_ball": KP + "cannon-ball.glb",
	"pirate/crate": KP + "crate.glb",
	"pirate/crate_bottles": KP + "crate-bottles.glb",
	"pirate/palm": KP + "palm-straight.glb",
	"pirate/palm_bend": KP + "palm-bend.glb",
	"pirate/palm_detailed": KP + "palm-detailed-bend.glb",
	"pirate/ship_large": KP + "ship-pirate-large.glb",
	"pirate/ship_medium": KP + "ship-pirate-medium.glb",
	"pirate/ship_small": KP + "ship-pirate-small.glb",
	"pirate/ship_ghost": KP + "ship-ghost.glb",
	"pirate/ship_wreck": KP + "ship-wreck.glb",
	"pirate/platform_planks": KP + "platform-planks.glb",
	"pirate/platform": KP + "platform.glb",
	"pirate/dock": KP + "structure-platform-dock.glb",
	"pirate/dock_small": KP + "structure-platform-dock-small.glb",
	"pirate/structure": KP + "structure.glb",
	"pirate/tower": KP + "tower-complete-large.glb",
	"pirate/tower_small": KP + "tower-complete-small.glb",
	"pirate/tower_watch": KP + "tower-watch.glb",
	"pirate/flag": KP + "flag-pirate-high.glb",
	"pirate/rocks_a": KP + "rocks-sand-a.glb",
	"pirate/rocks_b": KP + "rocks-sand-b.glb",
	"pirate/rocks_c": KP + "rocks-c.glb",
	"pirate/patch_sand": KP + "patch-sand-foliage.glb",
	"pirate/grass": KP + "grass-plant.glb",
	"pirate/mast": KP + "mast-ropes.glb",
	"pirate/bottle": KP + "bottle-large.glb",
	"pirate/boat_row": KP + "boat-row-large.glb",
	"pirate/castle_gate": KP + "castle-gate.glb",
	"pirate/hole": KP + "hole.glb",
	"water/buoy": KW + "buoy-flag.glb",
	"water/boat_sail": KW + "boat-sail-a.glb",
	"water/boat_fishing": KW + "boat-fishing-small.glb",
	# --- Dungeon ---
	"dun/floor_large": KDUN + "floor_tile_large.gltf",
	"dun/floor_small": KDUN + "floor_tile_small.gltf",
	"dun/floor_rocks": KDUN + "floor_tile_large_rocks.gltf",
	"dun/floor_grate": KDUN + "floor_tile_big_grate.gltf",
	"dun/floor_dirt": KDUN + "floor_dirt_large.gltf",
	"dun/floor_wood": KDUN + "floor_wood_large.gltf",
	"dun/wall": KDUN + "wall.gltf",
	"dun/wall_arched": KDUN + "wall_arched.gltf",
	"dun/wall_broken": KDUN + "wall_broken.gltf",
	"dun/wall_corner": KDUN + "wall_corner.gltf",
	"dun/wall_doorway": KDUN + "wall_doorway.gltf",
	"dun/wall_gated": KDUN + "wall_gated.gltf",
	"dun/pillar": KDUN + "pillar.gltf",
	"dun/pillar_deco": KDUN + "pillar_decorated.gltf",
	"dun/column": KDUN + "column.gltf",
	"dun/torch": KDUN + "torch_lit.gltf",
	"dun/torch_mounted": KDUN + "torch_mounted.gltf",
	"dun/chest": KDUN + "chest.gltf",
	"dun/chest_gold": KDUN + "chest_gold.gltf",
	"dun/barrel": KDUN + "barrel_large.gltf",
	"dun/barrel_small": KDUN + "barrel_small.gltf",
	"dun/box": KDUN + "box_large.gltf",
	"dun/box_stacked": KDUN + "box_stacked.gltf",
	"dun/crates": KDUN + "crates_stacked.gltf",
	"dun/keg": KDUN + "keg_decorated.gltf",
	"dun/banner": KDUN + "banner_patternA_red.gltf",
	"dun/banner_blue": KDUN + "banner_shield_blue.gltf",
	"dun/candle": KDUN + "candle_triple.gltf",
	"dun/coin_stack": KDUN + "coin_stack_large.gltf",
	"dun/rubble": KDUN + "rubble_large.gltf",
	"dun/stairs": KDUN + "stairs.gltf",
	"dun/table": KDUN + "table_long_decorated_A.gltf",
	"dun/sword_shield": KDUN + "sword_shield_gold.gltf",
	"dun/key": KDUN + "key.gltf",
	"dun/barrier": KDUN + "barrier.gltf",
	"dun/shelf": KDUN + "shelf_large.gltf",
	"cave/rock_gate": KCV + "gate-rock.glb",
	"cave/room": KCV + "room-large.glb",
	"cave/detail": KCV + "template-detail.glb",
	# --- Friedhof / Geister ---
	"grave/crypt": KG + "crypt-large.glb",
	"grave/crypt_small": KG + "crypt-small.glb",
	"grave/gravestone": KG + "gravestone-cross.glb",
	"grave/gravestone_round": KG + "gravestone-round.glb",
	"grave/fence": KG + "iron-fence.glb",
	"grave/pine": KG + "pine-crooked.glb",
	"grave/pumpkin": KG + "pumpkin-carved.glb",
	"grave/lantern": KG + "lantern-candle.glb",
	"grave/lightpost": KG + "lightpost-double.glb",
	"grave/fire_basket": KG + "fire-basket.glb",
	"grave/coffin": KG + "coffin.glb",
	"grave/candles": KG + "candle-multiple.glb",
	"grave/obelisk": KG + "pillar-obelisk.glb",
	"grave/altar": KG + "altar-stone.glb",
	"grave/debris": KG + "debris.glb",
	# --- Plattformer / Himmel ---
	"plat/block_grass": KPL + "block-grass.glb",
	"plat/block_grass_large": KPL + "block-grass-large.glb",
	"plat/block_grass_low": KPL + "block-grass-low.glb",
	"plat/block_grass_hex": KPL + "block-grass-low-hexagon.glb",
	"plat/block_grass_overhang": KPL + "block-grass-overhang-large.glb",
	"plat/block_snow": KPL + "block-snow-large.glb",
	"plat/block_moving": KPL + "block-moving-large.glb",
	"plat/platform": KPL + "platform.glb",
	"plat/star": KPL + "star.glb",
	"plat/coin": KPL + "coin-gold.glb",
	"plat/chest": KPL + "chest.glb",
	"plat/flag": KPL + "flag.glb",
	"plat/spring": KPL + "spring.glb",
	"plat/tree": KPL + "tree.glb",
	"plat/tree_pine": KPL + "tree-pine.glb",
	"plat/flowers": KPL + "flowers.glb",
	"plat/mushrooms": KPL + "mushrooms.glb",
	"plat/heart": KPL + "heart.glb",
	"plat/jewel": KPL + "jewel.glb",
	"plat/saw": KPL + "saw.glb",
	"plat/spike_block": KPL + "spike-block.glb",
	"plat/trap_spikes": KPL + "trap-spikes-large.glb",
	"plat/bomb": KPL + "bomb.glb",
	"plat/crate": KPL + "crate.glb",
	"plat/crate_item": KPL + "crate-item.glb",
	"plat/barrel": KPL + "barrel.glb",
	"plat/sign": KPL + "sign.glb",
	"plat/arrow": KPL + "arrow.glb",
	"plat/fence": KPL + "fence-straight.glb",
	"plat/lever": KPL + "lever.glb",
	"plat/button": KPL + "button-round.glb",
	"plat/pipe": KPL + "pipe.glb",
	"plat/poles": KPL + "poles.glb",
	"plat/conveyor": KPL + "conveyor-belt.glb",
	"plat/ladder": KPL + "ladder-long.glb",
	"plat/char_oobi": KPL + "character-oobi.glb",
	"castle/tower": KC + "tower-square.glb",
	"castle/tower_hex_base": KC + "tower-hexagon-base.glb",
	"castle/tower_hex_mid": KC + "tower-hexagon-mid.glb",
	"castle/tower_hex_roof": KC + "tower-hexagon-roof.glb",
	"castle/tower_base": KC + "tower-square-base.glb",
	"castle/tower_mid": KC + "tower-square-mid-windows.glb",
	"castle/tower_roof": KC + "tower-square-top-roof-high.glb",
	"castle/wall": KC + "wall.glb",
	"castle/gate": KC + "gate.glb",
	"castle/bridge": KC + "bridge-straight.glb",
	"castle/bridge_draw": KC + "bridge-draw.glb",
	"castle/flag": KC + "flag-banner-long.glb",
	"castle/flag_pennant": KC + "flag-pennant.glb",
	"castle/catapult": KC + "siege-catapult.glb",
	"castle/trebuchet": KC + "siege-trebuchet.glb",
	"castle/tree": KC + "tree-large.glb",
	"castle/rocks": KC + "rocks-large.glb",
	"castle/ground_hills": KC + "ground-hills.glb",
	"town/house": KFT + "watermill.glb",
	"town/fountain": KFT + "fountain-round.glb",
	"town/lantern": KFT + "lantern.glb",
	"town/cart": KFT + "cart.glb",
	"town/windmill": KFT + "windmill.glb",
	"town/stall": KFT + "stall-green.glb",
	"town/tree": KFT + "tree-high.glb",
	# --- Minispiel-Variety-Pack ---
	"mg/bomb_red": KMG + "bomb_teamRed.gltf.glb",
	"mg/bomb_blue": KMG + "bomb_teamBlue.gltf.glb",
	"mg/powerup_bomb": KMG + "powerupBomb.gltf.glb",
	"mg/powerup_block": KMG + "powerupBlock_teamYellow.gltf.glb",
	"mg/spike_roller": KMG + "spikeRoller.gltf.glb",
	"mg/swiper": KMG + "swiperLong_teamRed.gltf.glb",
	"mg/swiper_double": KMG + "swiperDouble_teamBlue.gltf.glb",
	"mg/star": KMG + "star.gltf.glb",
	"mg/lightning": KMG + "lightning.gltf.glb",
	"mg/target": KMG + "targetStand.gltf.glb",
	"mg/tile_large_forest": KMG + "tileLarge_forest.gltf.glb",
	"mg/tile_large_desert": KMG + "tileLarge_desert.gltf.glb",
	"mg/tile_high_forest": KMG + "tileHigh_forest.gltf.glb",
	"mg/tile_small_red": KMG + "tileSmall_teamRed.gltf.glb",
	"mg/tile_small_blue": KMG + "tileSmall_teamBlue.gltf.glb",
	"mg/tile_small_yellow": KMG + "tileSmall_teamYellow.gltf.glb",
	"mg/tile_large_red": KMG + "tileLarge_teamRed.gltf.glb",
	"mg/tile_large_blue": KMG + "tileLarge_teamBlue.gltf.glb",
	"mg/tile_large_yellow": KMG + "tileLarge_teamYellow.gltf.glb",
	"mg/tree_forest": KMG + "tree_forest.gltf.glb",
	"mg/tree_desert": KMG + "tree_desert.gltf.glb",
	"mg/flag_red": KMG + "flag_teamRed.gltf.glb",
	"mg/barrier_large": KMG + "barrierLarge.gltf.glb",
	"mg/barrier_strut": KMG + "barrierStrut.gltf.glb",
	"mg/ring": KMG + "ring_teamYellow.gltf.glb",
	"mg/diamond": KMG + "diamond_teamYellow.gltf.glb",
	"mg/heart": KMG + "heart_teamRed.gltf.glb",
	"mg/button_red": KMG + "button_teamRed.gltf.glb",
	# --- Survival / RPG / Tower-Defense ---
	"surv/fish": KSV + "fish-large.glb",
	"surv/fish_small": KSV + "fish.glb",
	"surv/anvil": KSV + "workbench-anvil.glb",
	"surv/barrel": KSV + "barrel.glb",
	"surv/campfire": KSV + "campfire-pit.glb",
	"surv/tree": KSV + "tree-tall.glb",
	"surv/tent": KSV + "tent-canvas.glb",
	"surv/planks": KSV + "resource-planks.glb",
	"rpg/anvil": KRPG + "anvil.gltf",
	"rpg/hammer": KRPG + "hammer.gltf",
	"rpg/pickaxe": KRPG + "pickaxe.gltf",
	"td/boulder": KTD + "weapon-ammo-boulder.glb",
	"td/cannonball": KTD + "weapon-ammo-cannonball.glb",
	"td/cannon": KTD + "weapon-cannon.glb",
	"td/crystal": KTD + "detail-crystal-large.glb",
	"td/rocks": KTD + "detail-rocks-large.glb",
	"td/ufo": KTD + "enemy-ufo-a-weapon.glb",
	# --- Arena / Arcade ---
	"arena/trophy": KAR + "trophy.glb",
	"arena/statue": KAR + "statue.glb",
	"arena/banner": KAR + "banner.glb",
	"arena/column": KAR + "column.glb",
	"arena/block": KAR + "block.glb",
	"arena/floor": KAR + "floor.glb",
	"arena/stairs": KAR + "stairs.glb",
	"arcade/prize_wheel": KARC + "prize-wheel.glb",
	"arcade/claw": KARC + "claw-machine.glb",
	"arcade/machine": KARC + "arcade-machine.glb",
	"arcade/prizes": KARC + "prizes.glb",
	# --- Holiday ---
	"hol/present_red": KHOL + "present_A_red.gltf",
	"hol/present_blue": KHOL + "present_B_blue.gltf",
	"hol/present_yellow": KHOL + "present_C_yellow.gltf",
	"hol/present_green": KHOL + "present_D_green.gltf",
	"hol/lantern": KHOL + "lantern_decorated.gltf",
	"hol/cookie": KHOL + "cookie.gltf",
	"hol/snowball_cannon": KHOL + "snowball_cannon.gltf",
	"hol/bell": KHOL + "bell_decorated.gltf",
	"hol/plate": KHOL + "plate_decorated_A.gltf",
	"hk/lights": KHK + "lights-colored.glb",
	"hk/lantern": KHK + "lantern.glb",
	# --- Natur ---
	"nat/tree_oak": KN + "tree_oak.glb",
	"nat/tree_default": KN + "tree_default.glb",
	"nat/tree_fat": KN + "tree_fat.glb",
	"nat/tree_pine": KN + "tree_pineRoundA.glb",
	"nat/tree_palm": KN + "tree_palmTall.glb",
	"nat/tree_palm_bend": KN + "tree_palmBend.glb",
	"nat/rock_large": KN + "rock_largeA.glb",
	"nat/rock_tall": KN + "rock_tallA.glb",
	"nat/rock_small": KN + "rock_smallA.glb",
	"nat/cliff": KN + "cliff_block_rock.glb",
	"nat/cliff_large": KN + "cliff_large_rock.glb",
	"nat/cliff_stone": KN + "cliff_block_stone.glb",
	"nat/flower_red": KN + "flower_redA.glb",
	"nat/flower_yellow": KN + "flower_yellowA.glb",
	"nat/flower_purple": KN + "flower_purpleA.glb",
	"nat/mushroom": KN + "mushroom_redGroup.glb",
	"nat/grass": KN + "grass_large.glb",
	"nat/log": KN + "log_large.glb",
	"nat/stump": KN + "stump_round.glb",
	"nat/bush": KN + "plant_bushLarge.glb",
	"nat/lily": KN + "lily_large.glb",
	"nat/cactus": KN + "cactus_tall.glb",
	"nat/tent": KN + "tent_detailedOpen.glb",
	"nat/campfire": KN + "campfire_stones.glb",
	"nat/bridge_wood": KN + "bridge_wood.glb",
	"nat/fence": KN + "fence_simple.glb",
	"for/tree_a": KFOR + "Tree_1_A_Color1.gltf",
	"for/tree_b": KFOR + "Tree_2_B_Color1.gltf",
	"for/tree_c": KFOR + "Tree_3_A_Color1.gltf",
	"for/tree_bare": KFOR + "Tree_Bare_1_A_Color1.gltf",
	"for/bush": KFOR + "Bush_1_A_Color1.gltf",
	"for/rock_a": KFOR + "Rock_1_A_Color1.gltf",
	"for/rock_b": KFOR + "Rock_3_C_Color1.gltf",
	"for/grass": KFOR + "Grass_1_A_Color1.gltf",
	# --- Racing ---
	"race/grandstand": KR + "grandStandCovered.glb",
	"race/grandstand_round": KR + "grandStandCoveredRound.glb",
	"race/banner_tower_red": KR + "bannerTowerRed.glb",
	"race/banner_tower_green": KR + "bannerTowerGreen.glb",
	"race/barrier_red": KR + "barrierRed.glb",
	"race/barrier_white": KR + "barrierWhite.glb",
	"race/billboard": KR + "billboard.glb",
	"race/billboard_low": KR + "billboardLow.glb",
	"race/flag_checkers": KR + "flagCheckers.glb",
	"race/flag_red": KR + "flagRed.glb",
	"race/flag_green": KR + "flagGreen.glb",
	"race/light_post": KR + "lightPostModern.glb",
	"race/light_colored": KR + "lightColored.glb",
	"race/light_red": KR + "lightRedDouble.glb",
	"race/overhead": KR + "overheadLights.glb",
	"race/overhead_round": KR + "overheadRoundColored.glb",
	"race/tent": KR + "tentLong.glb",
	"race/tent_closed": KR + "tentClosed.glb",
	"race/pits": KR + "pitsGarage.glb",
	"race/pylon": KR + "pylon.glb",
	"race/radar": KR + "radarEquipment.glb",
	"race/tree_large": KR + "treeLarge.glb",
	"race/tree_small": KR + "treeSmall.glb",
	"race/camera": KR + "camera_exclusive.glb",
	"race/car_red": KR + "raceCarRed.glb",
	"race/car_green": KR + "raceCarGreen.glb",
	"kart/oobi": KCAR + "kart-oobi.glb",
	"kart/oodi": KCAR + "kart-oodi.glb",
	"kart/ooli": KCAR + "kart-ooli.glb",
	"kart/oopi": KCAR + "kart-oopi.glb",
	"kart/oozi": KCAR + "kart-oozi.glb",
	"car/cone": KCAR + "cone.glb",
	"car/debris_tire": KCAR + "debris-tire.glb",
	"car/debris_bolt": KCAR + "debris-bolt.glb",
	"car/race_future": KCAR + "race-future.glb",
	"toy/item_box": KTOY + "item-box.glb",
	"toy/gate_finish": KTOY + "gate-finish.glb",
	"toy/coin": KTOY + "item-coin-gold.glb",
	"toy/smoke": KTOY + "smoke.glb",
	"toy/cone": KTOY + "item-cone.glb",
	# --- Weltraum / Neon ---
	"space/crater": KSP + "craterLarge.glb",
	"space/rock_crystals": KSP + "rock_crystalsLargeA.glb",
	"space/rock_crystals_b": KSP + "rock_crystalsLargeB.glb",
	"space/rocket": KSP + "rocket_baseA.glb",
	"space/rocket_top": KSP + "rocket_topA.glb",
	"space/satellite": KSP + "satelliteDish_large.glb",
	"space/hangar": KSP + "hangar_roundGlass.glb",
	"space/meteor": KSP + "meteor_detailed.glb",
	"space/pipe_ring": KSP + "pipe_ringHigh.glb",
	"space/machine": KSP + "machine_generatorLarge.glb",
	"space/turret": KSP + "turret_double.glb",
	"space/craft_racer": KSP + "craft_racer.glb",
	"space/craft_speeder": KSP + "craft_speederA.glb",
	"space/alien": KSP + "alien.glb",
	"space/astronaut": KSP + "astronautA.glb",
	"space/rover": KSP + "rover.glb",
	# --- v2: Minigolf ---
	"golf/ball_red": KGOLF + "ball-red.glb",
	"golf/ball_blue": KGOLF + "ball-blue.glb",
	"golf/ball_green": KGOLF + "ball-green.glb",
	"golf/hole": KGOLF + "hole-round.glb",
	"golf/flag": KGOLF + "flag-large-red.glb",
	"golf/block": KGOLF + "block.glb",
	"golf/obstacle": KGOLF + "obstacle-block.glb",
	"golf/obstacle_diamond": KGOLF + "obstacle-diamond.glb",
	"golf/castle": KGOLF + "castle.glb",
	"golf/club": KGOLF + "club-red.glb",
	# --- v2: Holiday-Kit (Frost) ---
	"hk/snowman": KHK + "snowman-hat.glb",
	"hk/snow_pile": KHK + "snow-pile.glb",
	"hk/snow_bunker": KHK + "snow-bunker.glb",
	"hk/tree_snow": KHK + "tree-snow-a.glb",
	"hk/tree_snow_b": KHK + "tree-snow-b.glb",
	"hk/tree_decorated": KHK + "tree-decorated-snow.glb",
	"hk/reindeer": KHK + "reindeer.glb",
	"hk/sled": KHK + "sled.glb",
	"hk/candy_cane": KHK + "candy-cane-red.glb",
	"hk/present": KHK + "present-a-cube.glb",
	"hk/present_round": KHK + "present-b-round.glb",
	"hk/cabin_wall": KHK + "cabin-wall.glb",
	"hk/cabin_roof": KHK + "cabin-roof-snow.glb",
	"hk/cabin_door": KHK + "cabin-doorway.glb",
	"hk/nutcracker": KHK + "nutcracker.glb",
	"hk/train": KHK + "train-locomotive.glb",
	"hk/rocks": KHK + "rocks-large.glb",
	"hk/snowflake": KHK + "snowflake-a.glb",
	"hol/snowball": KHOL + "snowball.gltf",
	"hol/snowball_pile": KHOL + "snowball_pile.gltf",
	"hol/snowman": KHOL + "snowman_A.gltf",
	"hol/christmas_tree": KHOL + "christmas_tree_decorated.gltf",
	"hol/gingerbread_house": KHOL + "gingerbread_house_decorated.gltf",
	"nat/pine_snow": KN + "tree_pineTallA_detailed.glb",
	"nat/pine": KN + "tree_pineRoundC.glb",
	"nat/cactus_short": KN + "cactus_short.glb",
	# --- v2: Raumstation ---
	"ss/floor": KSS + "floor-panel.glb",
	"ss/rail": KSS + "rail.glb",
	"ss/computer": KSS + "computer-wide.glb",
	"ss/container": KSS + "container-tall.glb",
	"ss/display": KSS + "display-wall-wide.glb",
	"ss/table_planet": KSS + "table-display-planet.glb",
	"sb/module_a": KSB + "basemodule_A.gltf",
	"sb/module_c": KSB + "basemodule_C.gltf",
	"sb/garage": KSB + "basemodule_garage.gltf",
	"sb/landingpad": KSB + "landingpad_large.gltf",
	"sb/lander": KSB + "lander_A.gltf",
	"sb/windturbine": KSB + "windturbine_tall.gltf",
	"sb/solarpanel": KSB + "solarpanel.gltf",
	"sb/drill": KSB + "drill_structure.gltf",
	"sb/cargo": KSB + "cargo_A_stacked.gltf",
	"sb/truck": KSB + "spacetruck.gltf",
	"sb/rocks": KSB + "rocks_A.gltf",
	# --- v2: Stadt ---
	"city/sky_a": KCITY + "building-skyscraper-a.glb",
	"city/sky_b": KCITY + "building-skyscraper-b.glb",
	"city/sky_c": KCITY + "building-skyscraper-c.glb",
	"city/building_a": KCITY + "building-a.glb",
	"city/building_e": KCITY + "building-e.glb",
	"city/building_h": KCITY + "building-h.glb",
	"city/parasol": KCITY + "detail-parasol-a.glb",
	"sub/house_a": KSUB + "building-type-a.glb",
	"sub/house_f": KSUB + "building-type-f.glb",
	"sub/house_k": KSUB + "building-type-k.glb",
	"sub/tree": KSUB + "tree-large.glb",
	"sub/fence": KSUB + "fence-3x3.glb",
	"sub/planter": KSUB + "planter.glb",
	"arcade/dance": KARC + "dance-machine.glb",
	"arcade/gamer": KARC + "character-gamer.glb",
}

## Rig_Medium-Animationsquellen (alle teilen das Skelett der Helden).
const RIG_ANIMS := [
	KANIM + "Rig_Medium_General.glb",
	KANIM + "Rig_Medium_MovementBasic.glb",
	KANIM + "Rig_Medium_MovementAdvanced.glb",
	KANIM + "Rig_Medium_Simulation.glb",
	KANIM + "Rig_Medium_Special.glb",
	KANIM + "Rig_Medium_CombatMelee.glb",
	KANIM + "Rig_Medium_Tools.glb",
]

## 2D-Icons (Button-Glyphen, Medaillen, Zielmarker, Brettspiel-Infos).
const ICONS := {
	"btn_a": KIP + "Nintendo Switch/Default/switch_button_a.png",
	"btn_b": KIP + "Nintendo Switch/Default/switch_button_b.png",
	"btn_x": KIP + "Nintendo Switch/Default/switch_button_x.png",
	"btn_y": KIP + "Nintendo Switch/Default/switch_button_y.png",
	"btn_r": KIP + "Nintendo Switch/Default/switch_button_r.png",
	"btn_l": KIP + "Nintendo Switch/Default/switch_button_l.png",
	"btn_plus": KIP + "Nintendo Switch/Default/switch_button_plus.png",
	"stick_l": KIP + "Nintendo Switch/Default/switch_stick_l.png",
	"touch_tap": KIP + "Touch/Default/touch_tap.png",
	"touch_move": KIP + "Touch/Default/touch_swipe_move.png",
	"key_space": KIP + "Keyboard & Mouse/Default/keyboard_space.png",
	"medal_1": "res://assets/3d/minigames-and-others/kenney_medals/PNG/flatshadow_medal1.png",
	"medal_2": "res://assets/3d/minigames-and-others/kenney_medals/PNG/flatshadow_medal2.png",
	"medal_3": "res://assets/3d/minigames-and-others/kenney_medals/PNG/flatshadow_medal3.png",
	"crosshair": "res://assets/3d/minigames-and-others/kenney_crosshair-pack/PNG/Glow/crosshair-030.png",
	"luck": "res://assets/3d/boardgame/kenney_board-game-info/PNG/Default (128px)/luck.png",
	"hourglass": "res://assets/3d/boardgame/kenney_board-game-info/PNG/Default (128px)/hourglass.png",
}

## Button-Glyphen je Controller-Layout (Kenney Input Prompts). Aktionen sind positionsbasiert:
## "a" = unterer Face-Button, "b" = rechter, "x" = linker, "y" = oberer.
const GLYPHS := {
	"xbox": {"a": KIP + "Xbox Series/Default/xbox_button_a.png", "b": KIP + "Xbox Series/Default/xbox_button_b.png",
		"x": KIP + "Xbox Series/Default/xbox_button_x.png", "y": KIP + "Xbox Series/Default/xbox_button_y.png",
		"r": KIP + "Xbox Series/Default/xbox_rb.png", "l": KIP + "Xbox Series/Default/xbox_lb.png", "start": KIP + "Xbox Series/Default/xbox_button_menu.png"},
	"playstation": {"a": KIP + "PlayStation Series/Default/playstation_button_cross.png", "b": KIP + "PlayStation Series/Default/playstation_button_circle.png",
		"x": KIP + "PlayStation Series/Default/playstation_button_square.png", "y": KIP + "PlayStation Series/Default/playstation_button_triangle.png",
		"r": KIP + "PlayStation Series/Default/playstation_trigger_r1.png", "l": KIP + "PlayStation Series/Default/playstation_trigger_l1.png",
		"start": KIP + "PlayStation Series/Default/playstation5_button_options.png"},
	"switch": {"a": KIP + "Nintendo Switch/Default/switch_button_b.png", "b": KIP + "Nintendo Switch/Default/switch_button_a.png",
		"x": KIP + "Nintendo Switch/Default/switch_button_y.png", "y": KIP + "Nintendo Switch/Default/switch_button_x.png",
		"r": KIP + "Nintendo Switch/Default/switch_button_r.png", "l": KIP + "Nintendo Switch/Default/switch_button_l.png", "start": KIP + "Nintendo Switch/Default/switch_button_plus.png"},
	"keyboard": {"a": KIP + "Keyboard & Mouse/Default/keyboard_space.png", "b": KIP + "Keyboard & Mouse/Default/keyboard_k.png",
		"x": KIP + "Keyboard & Mouse/Default/keyboard_e.png", "y": KIP + "Keyboard & Mouse/Default/keyboard_q.png",
		"r": KIP + "Keyboard & Mouse/Default/keyboard_shift.png", "l": KIP + "Keyboard & Mouse/Default/keyboard_tab.png", "start": KIP + "Keyboard & Mouse/Default/keyboard_escape.png"},
	"touch": {"a": KIP + "Touch/Default/touch_tap.png"},
}

const FONT_TITLE := "res://assets/fonts/LilitaOne-Regular.ttf"
const FONT_BODY := "res://assets/fonts/Fredoka.ttf"

var _cache: Dictionary = {}
var _rig_library: AnimationLibrary
var _aabb_cache: Dictionary = {}


func path(key: String) -> String:
	if key.begins_with("res://"):
		return key
	if not MODELS.has(key):
		push_error("Assets: unbekannter Modell-Schlüssel '%s'" % key)
		return ""
	return MODELS[key]


func scene(key: String) -> PackedScene:
	var p := path(key)
	if p == "":
		return null
	if not _cache.has(p):
		var res: Resource = load(p)
		_cache[p] = res
	return _cache[p] as PackedScene


func icon(key: String) -> Texture2D:
	var p: String = ICONS.get(key, key)
	if not _cache.has(p):
		_cache[p] = load(p)
	return _cache[p]


## Instanziert ein Modell. Gibt immer einen Node3D zurück (Fallback: Platzhalter-Würfel).
func spawn(key: String, parent: Node = null, pos := Vector3.ZERO, rot_y_deg := 0.0, scl := 1.0) -> Node3D:
	var ps := scene(key)
	var n: Node3D
	if ps:
		n = ps.instantiate() as Node3D
	if n == null:
		n = MeshInstance3D.new()
		(n as MeshInstance3D).mesh = BoxMesh.new()
	if parent:
		parent.add_child(n)
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	if scl != 1.0:
		n.scale = Vector3.ONE * scl
	return n


## Kombinierte lokale AABB eines Modells (gecacht pro Schlüssel).
func model_aabb(key: String) -> AABB:
	if _aabb_cache.has(key):
		return _aabb_cache[key]
	var ps := scene(key)
	if ps == null:
		return AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	var n := ps.instantiate() as Node3D
	var box := compute_aabb(n)
	n.free()
	_aabb_cache[key] = box
	return box


static func compute_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D and node != root:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var b: AABB = xf * (node as MeshInstance3D).mesh.get_aabb()
			if first:
				result = b
				first = false
			else:
				result = result.merge(b)
		for c in node.get_children():
			stack.append([c, xf])
	return result


## Erzeugt statische Kollision (vereinfachte Box) für ein instanziertes Modell.
func add_box_collision(model: Node3D, key: String = "", layer := 1) -> StaticBody3D:
	var box := model_aabb(key) if key != "" else compute_aabb(model)
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.05)
	cs.shape = shape
	cs.position = box.get_center()
	body.add_child(cs)
	model.add_child(body)
	return body


## Färbt alle Meshes eines Modells ein (z. B. Fisch -> grauer Hai, Geister-Transparenz).
static func tint(root: Node, color: Color, unshaded := false, emission := 0.0) -> void:
	for mi in find_meshes(root):
		var count := mi.get_surface_override_material_count()
		for s in count:
			var base: Material = mi.get_active_material(s)
			var m: StandardMaterial3D
			if base is StandardMaterial3D:
				m = (base as StandardMaterial3D).duplicate()
			else:
				m = StandardMaterial3D.new()
			m.albedo_color = m.albedo_color * color
			if color.a < 1.0:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if unshaded:
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if emission > 0.0:
				m.emission_enabled = true
				m.emission = color
				m.emission_energy_multiplier = emission
			mi.set_surface_override_material(s, m)


static func find_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		stack.append_array(n.get_children())
	return out


static func set_shadows(root: Node, on: bool) -> void:
	for mi in find_meshes(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Geteilte Animationsbibliothek für alle Rig_Medium-Charaktere.
func rig_library() -> AnimationLibrary:
	if _rig_library:
		return _rig_library
	_rig_library = AnimationLibrary.new()
	for p in RIG_ANIMS:
		var ps: PackedScene = load(p)
		if ps == null:
			continue
		var inst := ps.instantiate()
		var ap := inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			for lib_name in ap.get_animation_library_list():
				var lib := ap.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					if anim_name == "T-Pose" or _rig_library.has_animation(anim_name):
						continue
					var a: Animation = lib.get_animation(anim_name)
					_rig_library.add_animation(anim_name, a)
		inst.free()
	_apply_loop_modes(_rig_library)
	return _rig_library


static func _apply_loop_modes(lib: AnimationLibrary) -> void:
	var looping := ["Idle_A", "Idle_B", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_C",
		"Jump_Idle", "Cheering", "Waving", "Sit_Floor_Idle", "Sit_Chair_Idle", "Lie_Idle", "Skeletons_Idle",
		"Skeletons_Walking", "Sneaking", "Crawling", "Melee_Blocking", "Hammering", "Holding_A", "Holding_B",
		"Fishing_Idle", "Sit_Ups", "Push_Ups", "Working_A", "Crouching", "Melee_Unarmed_Idle", "Running_HoldingBow",
		"Digging", "Chopping", "Sawing", "Lockpicking", "Skeletons_Taunt_Longer", "Melee_2H_Attack_Spinning"]
	for n in looping:
		if lib.has_animation(n):
			lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR


## Liste aller referenzierten Asset-Pfade (für den Export-Filter).
func all_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for v in MODELS.values():
		out.append(v)
	for v in RIG_ANIMS:
		out.append(v)
	for v in ICONS.values():
		out.append(v)
	for layout in GLYPHS.values():
		for v in layout.values():
			out.append(v)
	out.append(FONT_TITLE)
	out.append(FONT_BODY)
	return out
