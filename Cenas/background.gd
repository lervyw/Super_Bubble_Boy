extends ParallaxBackground

@export var can_process: bool #cria um boleano para mexer o cenario quando estar ativo
@export var layer_speed: Array[int] #crie atraves do export varias variaves do tipo int, no caso do codigo daqui cada um vetor vai ser uma layer
func _ready():
	if can_process == false: # para acabar com a fisica no começo da execução do aplicativo
		set_physics_process(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	for index in get_child_count(): # index pega o contador de quantos filhos o nó background tem começando no 0 e indo ate o 3, 
		#get_child_count é a quantidade de filhos no caso 4
		if get_child(index) is ParallaxLayer: # os filhos de background sao ParallaxLayer, mas de qualquer maneira deve ter um um diferencial caso nao sejam apenas ParallaxLayer
			
			get_child(index).motion_offset.x -= delta * layer_speed[index]
#metodo faz mexer o filho na posiçao index fazendo na posiçao index ser diminuido (no caso indo para esquerda) 
#onde a layer mais mais proxima no caso a layer1 poderia estar parada e a layer2 se mexe pouco, por ser a mais distante da camera
# onde o numero do inteiro da layer seria multiplicado por delta: layer2[1] valendo 5
# a layer3[2] valendo 10 e layer4[3] valendo 15
#fazendo a layer3 ser mais rapido que a layer2 e mais rapido que a layer1,
