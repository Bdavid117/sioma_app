# Assets - Modelos TensorFlow Lite

## Estructura de Directorios

```
assets/
└── models/
    ├── README.md (este archivo)
    └── face_recognition.tflite (modelo real - no incluido)
```

## Modelo de Reconocimiento Facial

Para usar un modelo TensorFlow Lite real de reconocimiento facial:

### Opciones de Modelos Recomendados:

1. **FaceNet** (Google)
   - Archivo: `facenet_mobilenet_v1_1.0_224.tflite`
   - Tamaño de entrada: 224x224
   - Embedding: 128 dimensiones
   - Descarga: TensorFlow Hub

2. **MobileFaceNet**
   - Archivo: `mobile_facenet.tflite`
   - Tamaño de entrada: 112x112
   - Embedding: 128 dimensiones
   - Optimizado para dispositivos móviles

3. **ArcFace** (InsightFace)
   - Archivo: `arcface_mobilefacenet.tflite`
   - Tamaño de entrada: 112x112
   - Embedding: 512 dimensiones
   - Alta precisión

### Instrucciones de Instalación:

1. **Descargar modelo:** Obtén un archivo `.tflite` de reconocimiento facial
2. **Colocar archivo:** Guarda el modelo en `assets/models/`
3. **Actualizar código:** En `face_embedding_service.dart`, descomenta las líneas del modelo real:
   ```dart
   _interpreter = await Interpreter.fromAsset('assets/models/tu_modelo.tflite');
   ```
4. **Ajustar parámetros:** Actualiza `inputSize` y `embeddingSize` según tu modelo

### Configuración Actual:

- **Modo:** Simulado (no requiere modelo real)
- **Input Size:** 112x112 (configurable)
- **Embedding Size:** 128 dimensiones
- **Algoritmo:** Embedding determinista basado en características de imagen

### Nota de Desarrollo:

El servicio actual usa embeddings simulados que son:
- **Reproducibles:** La misma imagen genera el mismo embedding
- **Únicos:** Diferentes imágenes generan embeddings diferentes
- **Normalizados:** Vectores con magnitud 1
- **Comparables:** Permiten cálculo de similitud coseno

Esto permite desarrollar y probar toda la funcionalidad sin necesidad de un modelo real.
