extends "res://objects/characters/entity/Entity.gd"

var gun_1 = null
var gun_2 = null
var cur_gun = null


func equipGun(gun_name : String):
	if !gun_1:
		gun_1 = createGun(gun_name)
		switchToGun(gun_1)
	elif !gun_2:
		gun_2 = createGun(gun_name)
		switchToGun(gun_2)
	else:
		# NOTE : should drop gun instead of freeing
		if cur_gun == gun_1:
			gun_1.queue_free()
			gun_1 = createGun(gun_name)
			cur_gun = gun_1
			switchToGun(gun_1)
		else:
			gun_2.queue_free()
			gun_2 = createGun(gun_name)
			cur_gun = gun_2
			switchToGun(gun_2)


func createGun(gun_name):
	var resource = get_tree().root.get_node("Resources")
	var gun = resource.guns.get(gun_name).instance()
	gun.init(name)
	return gun


func switchToGun(gun):
	cur_gun = gun
	get_node("CharacterModel").holdWeapon(cur_gun)


func switchGun():
	if gun_1 && gun_2:
		if cur_gun == gun_1:
			switchToGun(gun_2)
		else:
			switchToGun(gun_1)


func setSkin(skin : Texture):
	get_node("CharacterModel").get_node("skin").texture = skin

