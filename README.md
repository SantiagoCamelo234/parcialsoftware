# EcoEat – Chef Virtual Anti-Desperdicio

App móvil (Flutter) que genera recetas de aprovechamiento con IA (Google Gemini) a partir de los ingredientes que el usuario tiene en casa. El backend en Flask hace de intermediario con la IA y guarda el historial en memoria.

## 1. Arquitectura

```
 App Flutter                    Backend Flask (:5000)                Google Gemini API
 ─────────────                  ─────────────────────                ─────────────────
 Pantalla Ingreso  ── GET  /api/ingredientes/sugeridos ──►
                   ── POST /api/receta/generar ────────►  arma prompt ── generateContent ──►
                                                          valida JSON ◄── JSON receta ─────
 Pantalla Receta   ◄── 201 {receta} ───────────────────   guarda en HISTORIAL (memoria)

 Postman ── GET / POST / PUT /api/historial/favorito / DELETE /api/historial/<id> ──► Flask
```

**Flujo principal**
1. Al abrir la app, Flutter llama `GET /api/ingredientes/sugeridos` y muestra chips + autocompletado.
2. El usuario arma su lista y pulsa **Generar Receta** → `POST /api/receta/generar`.
3. Flask construye el prompt (rol de chef anti-desperdicio, reglas, esquema JSON obligatorio) y llama a Gemini con `responseMimeType: application/json`.
4. Flask limpia/valida el JSON, le añade `id`, `favorito`, `creado`, lo guarda en `HISTORIAL` y responde `201`.
5. Flutter convierte el JSON a un objeto `Receta` (`Receta.fromJson`) y navega a la pantalla de resultado.

**Estructura del proyecto**
```
EcoEat/
├── backend/
│   ├── app.py               # Servidor Flask + integración Gemini
│   ├── requirements.txt
│   └── .env.example         # GEMINI_API_KEY
├── ecoeat_app/              # Proyecto Flutter
│   └── lib/
│       ├── main.dart
│       ├── models/receta.dart          # Data class + fromJson/toJson
│       ├── services/api_service.dart   # Cliente HTTP (GET + POST) y manejo de errores
│       └── screens/
│           ├── ingredientes_screen.dart  # Ingreso + diálogo de configuración
│           └── receta_screen.dart        # Resultado con scroll
└── postman/EcoEat.postman_collection.json
```

## 2. Especificación de endpoints

Base URL: `http://localhost:5000`

| # | Método | Ruta | Payload (body) | Respuesta exitosa | Errores | Consumido por |
|---|--------|------|----------------|-------------------|---------|---------------|
| 1 | **POST** | `/api/receta/generar` | `{"ingredientes": ["Arroz","Huevo","Tomate"]}` | `201` `{"ok":true,"receta":{id, titulo, tiempo, porciones, dificultad, ingredientes[], pasos[], consejo_antidesperdicio, ingredientes_usuario[], favorito, creado}}` | `400` lista vacía/ inválida · `502` fallo de la IA | Flutter + Postman |
| 2 | **GET** | `/api/ingredientes/sugeridos` | — | `200` `{"ok":true,"ingredientes":["Arroz","Huevo",...]}` | — | Flutter + Postman |
| 3 | **PUT** | `/api/historial/favorito` | `{"id":"a1b2c3d4","favorito":true}` | `200` `{"ok":true,"mensaje":"Favorito actualizado","receta":{...}}` | `400` payload inválido · `404` id inexistente | Postman |
| 4 | **DELETE** | `/api/historial/<id>` | — | `200` `{"ok":true,"mensaje":"Receta eliminada","id":"a1b2c3d4"}` | `404` id inexistente | Postman |
| + | GET | `/api/historial` | — | `200` `{"ok":true,"total":n,"recetas":[...]}` | — | Postman (apoyo) |
| + | POST | `/api/historial/demo` | — | `201` receta de ejemplo sin IA | — | Postman (respaldo sin API key) |

Todos los errores tienen el formato `{"ok": false, "error": "mensaje"}`.

### Prompt engineering (POST /generar)
- **Rol:** "EcoChef", chef experto en cocina de aprovechamiento.
- **Restricciones:** usar la mayor cantidad de ingredientes dados; solo añadir básicos de despensa; máximo 8 pasos.
- **Resiliencia:** modelo principal `gemini-3.8-flash`; si responde 429/500/503 o no contesta en 30 s, el backend reintenta y pasa a `gemini-3.5-flash` y luego a `gemini-3.1-flash-lite`.
- **Formato:** se exige JSON con esquema exacto + `responseMimeType: application/json`; además el backend elimina bloques ```` ```json ```` y extrae el objeto `{...}` por si el modelo agrega texto.

## 3. Guía rápida de ejecución

### Requisitos
- Python 3.10+ · Flutter 3.x · Postman · API key gratuita de Google AI Studio (https://aistudio.google.com/apikey)

### Backend (Flask)
```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows  (Linux/Mac: source venv/bin/activate)
pip install -r requirements.txt
copy .env.example .env         # Linux/Mac: cp .env.example .env
# editar .env y pegar GEMINI_API_KEY
python app.py                  # Servidor en http://0.0.0.0:5000
```
Verificar: abrir `http://localhost:5000/` → `{"ok": true, "servicio": "EcoEat API", ...}`

### Frontend (Flutter)
```bash
cd ecoeat_app
flutter pub get
flutter run                    # elegir emulador Android, Chrome o Windows
```
URL del backend según dispositivo (se cambia desde el ícono ⚙️ de la app, sin recompilar):

| Dispositivo | URL |
|-------------|-----|
| Emulador Android (por defecto) | `http://10.0.2.2:5000` |
| Chrome / Windows | `http://localhost:5000` |
| Celular físico (misma Wi-Fi) | `http://<IP-del-PC>:5000` (ver con `ipconfig`) |

### Postman
1. Postman → **Import** → `postman/EcoEat.postman_collection.json`.
2. Con el backend corriendo, abrir la colección → **Run collection** (ejecutar en orden).
3. El request *2. POST Generar receta* guarda el `id` en la variable `recetaId`, que usan PUT y DELETE.
   Si no hay API key, el request *2b. POST Receta demo* genera una receta de respaldo para que PUT/DELETE funcionen igual.

## 4. Parsing y manejo de estados (Flutter)
- **Modelo:** `Receta.fromJson` convierte el JSON a objeto Dart con valores por defecto si falta algún campo (la app no se cae ante respuestas incompletas).
- **Carga:** `CircularProgressIndicator` en el botón mientras se genera la receta ("Cocinando con IA...") y `LinearProgressIndicator` al cargar sugerencias; los controles se deshabilitan durante la carga.
- **Errores:** `ApiService` traduce timeouts, falta de conexión, códigos ≠ 2xx y JSON inválido a `ApiException`; la UI los muestra en un `SnackBar` rojo.
- **Tests:** `flutter test` valida el parseo del modelo.

## 5. Roles del equipo
| Integrante | Rol | Entregable |
|-----------|-----|-----------|
| 1 | Backend Lead (Flask & IA) | `backend/app.py`, prompt, 4 métodos HTTP |
| 2 | Flutter Lead (UI) | `screens/` (ingreso, resultado, diálogo de configuración) |
| 3 | Integration & State Lead | `models/receta.dart`, `services/api_service.dart`, estados de carga/error |
| 4 | QA & Documentation Lead | `postman/` colección con tests, este README |
