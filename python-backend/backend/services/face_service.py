import base64
from io import BytesIO
from typing import List

import numpy as np
from PIL import Image


def encode_face_from_base64(image_b64: str) -> List[float]:
    """
    Decodes a base64 image string and returns the first face encoding as a list of floats.
    Raises ValueError if no face is found.
    """
    try:
        import face_recognition  # lazy import to avoid hard dependency at boot
    except Exception:
        raise ValueError(
            "El reconocimiento facial no está disponible. Instala 'dlib' y 'face-recognition' para usar esta función."
        )

    try:
        raw = base64.b64decode(image_b64)
    except Exception as e:
        raise ValueError(f"Imagen base64 inválida: {e}")

    try:
        image = Image.open(BytesIO(raw)).convert("RGB")
    except Exception as e:
        raise ValueError(f"No se pudo abrir la imagen: {e}")

    np_img = np.array(image)
    encodings = face_recognition.face_encodings(np_img)
    if not encodings:
        raise ValueError("No se detectaron rostros en la imagen")

    # Tomar el primer rostro detectado para el MVP
    return encodings[0].tolist()
