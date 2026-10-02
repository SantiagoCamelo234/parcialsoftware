"""EcoEat - Chef Virtual Anti-Desperdicio (Backend Flask + Gemini)."""
import json
import os
import re
import time
import uuid
from datetime import datetime

import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.8-flash")
# Modelos de respaldo si el principal está saturado (503) o con límite de cuota (429)
GEMINI_FALLBACKS = ["gemini-3.5-flash", "gemini-3.1-flash-lite"]
GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
ERRORES_TEMPORALES = {429, 500, 503}

app = Flask(__name__)
CORS(app)

# Almacenamiento en memoria: { id: receta }
HISTORIAL = {}

INGREDIENTES_SUGERIDOS = [
    "Arroz", "Huevo", "Tomate", "Cebolla", "Ajo", "Papa", "Zanahoria",
    "Pollo", "Pasta", "Queso", "Leche", "Pan", "Plátano", "Espinaca",
    "Pimiento", "Lentejas", "Atún", "Limón", "Avena", "Manzana",
]

PROMPT_TEMPLATE = """Eres "EcoChef", un chef experto en cocina de aprovechamiento y anti-desperdicio.
Crea UNA receta casera usando principalmente estos ingredientes que el usuario ya tiene:
{ingredientes}

Reglas:
- Prioriza usar la mayor cantidad posible de los ingredientes listados.
- Solo puedes añadir ingredientes básicos de despensa (sal, pimienta, aceite, agua, especias).
- Pasos claros, numerados implícitamente por orden, máximo 8 pasos.
- Responde ÚNICAMENTE con un JSON válido, sin texto adicional ni bloques markdown,
  con exactamente esta estructura:
{{
  "titulo": "string",
  "tiempo": "string (ej: '25 minutos')",
  "porciones": number,
  "dificultad": "Fácil | Media | Difícil",
  "ingredientes": ["cantidad + ingrediente", "..."],
  "pasos": ["paso 1", "paso 2", "..."],
  "consejo_antidesperdicio": "string"
}}"""


def error(msg, code):
    return jsonify({"ok": False, "error": msg}), code


def extraer_json(texto):
    """Limpia posibles bloques ```json``` y parsea la respuesta del modelo."""
    texto = texto.strip()
    texto = re.sub(r"^```(?:json)?\s*|\s*```$", "", texto)
    inicio, fin = texto.find("{"), texto.rfind("}")
    if inicio == -1 or fin == -1:
        raise ValueError("La IA no devolvió un JSON válido")
    return json.loads(texto[inicio : fin + 1])


def consultar_gemini(ingredientes):
    if not GEMINI_API_KEY:
        raise RuntimeError("Falta GEMINI_API_KEY en el archivo .env")
    prompt = PROMPT_TEMPLATE.format(ingredientes=", ".join(ingredientes))
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.7,
            "responseMimeType": "application/json",
        },
    }
    modelos = [GEMINI_MODEL] + [m for m in GEMINI_FALLBACKS if m != GEMINI_MODEL]
    ultimo_error = ""
    for modelo in modelos:
        for intento in range(2):
            try:
                resp = requests.post(
                    f"{GEMINI_BASE_URL}/{modelo}:generateContent",
                    params={"key": GEMINI_API_KEY},
                    json=body,
                    timeout=30,
                )
            except (requests.Timeout, requests.ConnectionError):
                ultimo_error = f"Gemini no respondió a tiempo ({modelo})"
                break  # pasar directo al siguiente modelo
            if resp.status_code == 200:
                texto = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
                return extraer_json(texto)
            ultimo_error = f"Error de Gemini ({resp.status_code}) en {modelo}: {resp.text[:300]}"
            if resp.status_code not in ERRORES_TEMPORALES:
                raise RuntimeError(ultimo_error)
            time.sleep(1.5 * (intento + 1))  # espera breve antes de reintentar
    raise RuntimeError(ultimo_error)


# ---------------------------------------------------------------- Endpoints

@app.get("/")
def salud():
    return jsonify({"ok": True, "servicio": "EcoEat API", "recetas_en_memoria": len(HISTORIAL)})


@app.post("/api/receta/generar")
def generar_receta():
    data = request.get_json(silent=True) or {}
    ingredientes = data.get("ingredientes")
    if not isinstance(ingredientes, list) or not ingredientes:
        return error("Envía 'ingredientes' como una lista no vacía", 400)
    ingredientes = [str(i).strip() for i in ingredientes if str(i).strip()]
    if not ingredientes:
        return error("Los ingredientes no pueden estar vacíos", 400)

    try:
        receta_ia = consultar_gemini(ingredientes)
    except (RuntimeError, ValueError, KeyError, requests.RequestException) as e:
        return error(str(e), 502)

    receta = {
        "id": str(uuid.uuid4())[:8],
        "titulo": receta_ia.get("titulo", "Receta EcoEat"),
        "tiempo": receta_ia.get("tiempo", "N/D"),
        "porciones": receta_ia.get("porciones", 2),
        "dificultad": receta_ia.get("dificultad", "Fácil"),
        "ingredientes": receta_ia.get("ingredientes", ingredientes),
        "pasos": receta_ia.get("pasos", []),
        "consejo_antidesperdicio": receta_ia.get("consejo_antidesperdicio", ""),
        "ingredientes_usuario": ingredientes,
        "favorito": False,
        "creado": datetime.now().isoformat(timespec="seconds"),
    }
    HISTORIAL[receta["id"]] = receta
    return jsonify({"ok": True, "receta": receta}), 201


@app.get("/api/ingredientes/sugeridos")
def ingredientes_sugeridos():
    return jsonify({"ok": True, "ingredientes": INGREDIENTES_SUGERIDOS}), 200


@app.get("/api/historial")
def listar_historial():
    return jsonify({"ok": True, "total": len(HISTORIAL), "recetas": list(HISTORIAL.values())}), 200


@app.put("/api/historial/favorito")
def marcar_favorito():
    data = request.get_json(silent=True) or {}
    receta_id = data.get("id")
    favorito = data.get("favorito")
    if not receta_id or not isinstance(favorito, bool):
        return error("Envía 'id' (string) y 'favorito' (boolean)", 400)
    receta = HISTORIAL.get(receta_id)
    if receta is None:
        return error(f"No existe la receta con id '{receta_id}'", 404)
    receta["favorito"] = favorito
    return jsonify({"ok": True, "mensaje": "Favorito actualizado", "receta": receta}), 200


@app.delete("/api/historial/<receta_id>")
def eliminar_receta(receta_id):
    receta = HISTORIAL.pop(receta_id, None)
    if receta is None:
        return error(f"No existe la receta con id '{receta_id}'", 404)
    return jsonify({"ok": True, "mensaje": "Receta eliminada", "id": receta_id}), 200


@app.post("/api/historial/demo")
def crear_demo():
    """Crea una receta de ejemplo sin IA (útil para probar PUT/DELETE en Postman)."""
    receta = {
        "id": str(uuid.uuid4())[:8],
        "titulo": "Tortilla de papa y cebolla",
        "tiempo": "20 minutos",
        "porciones": 2,
        "dificultad": "Fácil",
        "ingredientes": ["3 huevos", "2 papas", "1/2 cebolla", "Sal", "Aceite"],
        "pasos": ["Pelar y cortar las papas.", "Freír papa y cebolla.",
                  "Batir huevos y mezclar.", "Cuajar en sartén por ambos lados."],
        "consejo_antidesperdicio": "Usa papas un poco blandas: quedan perfectas en tortilla.",
        "ingredientes_usuario": ["Huevo", "Papa", "Cebolla"],
        "favorito": False,
        "creado": datetime.now().isoformat(timespec="seconds"),
    }
    HISTORIAL[receta["id"]] = receta
    return jsonify({"ok": True, "receta": receta}), 201


@app.errorhandler(404)
def no_encontrado(_):
    return error("Ruta no encontrada", 404)


@app.errorhandler(405)
def metodo_no_permitido(_):
    return error("Método HTTP no permitido", 405)


if __name__ == "__main__":
    # host 0.0.0.0 para que el emulador / celular pueda conectarse
    app.run(host="0.0.0.0", port=5000, debug=True)
