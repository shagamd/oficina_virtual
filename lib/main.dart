import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(GameWidget(game: OficinaGame()));
}

class OficinaGame extends FlameGame with KeyboardEvents, HasCollisionDetection {
  // Declaramos el mundo y la cámara
  late final CameraComponent camara;
  late final World mundo;

  // Referencias a nuestros personajes
  late final Jugador miPersonaje;
  late final Jugador companeroBot;

  @override
  Future<void> onLoad() async {
    // 1. Cargamos las imágenes en caché para que el juego vaya rápido
    await images.loadAll(['mapa.jpg', 'personaje.webp']);

    // 2. Inicializamos el mundo
    mundo = World();

    // 3. Creamos el mapa (Fondo)
    final spriteMapa = SpriteComponent(
      sprite: Sprite(images.fromCache('mapa.jpg')),
      anchor: Anchor.center, // El centro de la imagen es el punto (0,0)
    );
    mundo.add(spriteMapa);

    mundo.add(Obstaculo(position: Vector2(100, 100), size: Vector2(50, 50)));

    // 4. Creamos el jugador
    miPersonaje = Jugador(
      position: Vector2(0, 0),
      nombre: "Primer Jugador",
      esMio: true,
    ); // Empieza en el centro
    mundo.add(miPersonaje);

    // 4. EL COMPAÑERO (BOT) - Lo ponemos un poco lejos
    companeroBot = Jugador(
      position: Vector2(200, 0),
      nombre: "Bot Pepe",
      esMio: false,
    );
    mundo.add(companeroBot);

    // 5. Configuramos la cámara para que siga al jugador
    camara = CameraComponent(world: mundo);
    camara.viewfinder.anchor = Anchor.center;
    camara.follow(miPersonaje); // <--- MAGIA: La cámara sigue al jugador

    // Opcional: Zoom para ver todo más "pixel art"
    camara.viewfinder.zoom = 1.5;

    // Añadimos el mundo y la cámara al juego
    addAll([mundo, camara]);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Calculamos la distancia entre tú y el bot
    // distanceTo es una función nativa de vectores en Flame
    double distancia = miPersonaje.position.distanceTo(companeroBot.position);

    // Definimos el rango de "escucha" (suma de radios o un valor fijo)
    double rangoDeEscucha = 150.0;

    if (distancia < rangoDeEscucha) {
      // ESTAMOS CERCA: Cambiar color a VERDE (Conectado)
      miPersonaje.rangoVisual?.paint.color = Colors.green.withOpacity(0.2);

      // Aquí, en el futuro, llamaríamos a Rust: connect_audio(target_id)
    } else {
      // ESTAMOS LEJOS: Cambiar color a AZUL (Desconectado)
      miPersonaje.rangoVisual?.paint.color = Colors.blue.withOpacity(0.15);
    }
  }

  // 2. AQUI MOVEMOS LA LÓGICA DE TECLADO
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Calculamos la dirección basada en qué teclas están hundidas AHORA MISMO
    final isLeft =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final isRight =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    final isUp =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    final isDown =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);

    // Modificamos directamente la velocidad de MI personaje
    miPersonaje.velocity.x = 0;
    miPersonaje.velocity.y = 0;

    if (isLeft) miPersonaje.velocity.x = -1;
    if (isRight) miPersonaje.velocity.x = 1;
    if (isUp) miPersonaje.velocity.y = -1;
    if (isDown) miPersonaje.velocity.y = 1;

    if (miPersonaje.velocity != Vector2.zero()) {
      miPersonaje.velocity.normalize();
    }

    return KeyEventResult.handled;
  }
}

class Obstaculo extends PositionComponent {
  Obstaculo({required Vector2 position, required Vector2 size})
    : super(position: position, size: size, anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    // 1. Dibujamos un cuadro rojo (o transparente si quieres que sea invisible sobre el mapa)
    add(
      RectangleComponent(
        size: size,
        paint: Paint()
          ..color = Colors.red.withOpacity(
            0.5,
          ), // Semitransparente para ver el hitbox
      ),
    );

    // 2. Le agregamos una Hitbox (Caja de colisión)
    add(RectangleHitbox());
  }
}

// 1. Quitamos KeyboardHandler de aquí
class Jugador extends SpriteComponent with CollisionCallbacks {
  final double speed = 200.0;
  Vector2 velocity = Vector2.zero();
  Vector2 ultimaPosicion = Vector2.zero();
  final String nombre;
  CircleComponent? rangoVisual;
  final bool esMio;

  Jugador({required Vector2 position, required this.nombre, required this.esMio})
    : super(position: position, size: Vector2(32, 32), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('personaje.webp');

    // Hitbox física
    add(RectangleHitbox(size: Vector2(20, 20), position: Vector2(6, 6)));

    // --- RECREAMOS EL AURA VISUAL ---
    rangoVisual = CircleComponent(
      radius: 80,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
      paint: Paint()..color = Colors.blue.withOpacity(0.15),
    );
    add(rangoVisual!); // <--- ¡Importante añadirlo!

    // Nombre flotante
    final estiloTexto = TextPaint(
      style: const TextStyle(
        fontSize: 14.0,
        color: Colors.white,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1)),
        ],
      ),
    );

    add(TextComponent(
      text: nombre,
      textRenderer: estiloTexto,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, -15),
    ));
  }

  @override
  void update(double dt) {
    if (velocity == Vector2.zero()) return;
    ultimaPosicion.setFrom(position);
    super.update(dt);
    position.add(velocity * dt * speed);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Obstaculo) {
      position.setFrom(ultimaPosicion);
    }
  }
}
