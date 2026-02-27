"""
Plant Disease Detection - FastAPI Backend
Provides REST API endpoints for plant disease prediction from images.
"""

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import os
from PIL import Image
import io

# Use tf_keras for Keras 2 compatibility
os.environ['TF_USE_LEGACY_KERAS'] = '1'

import tf_keras as keras

# Initialize FastAPI app
app = FastAPI(
    title="🌿 KrishiMitra Plant Disease API",
    description="Plant Disease Detection System - Upload an image to detect diseases",
    version="1.0.0"
)

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Get the directory where the script is located
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Disease classes
CLASS_NAMES = [
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
    'Blueberry___healthy',
    'Cherry_(including_sour)___Powdery_mildew',
    'Cherry_(including_sour)___healthy',
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
    'Corn_(maize)___Common_rust_',
    'Corn_(maize)___Northern_Leaf_Blight',
    'Corn_(maize)___healthy',
    'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
    'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)',
    'Peach___Bacterial_spot',
    'Peach___healthy',
    'Pepper,_bell___Bacterial_spot',
    'Pepper,_bell___healthy',
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Raspberry___healthy',
    'Soybean___healthy',
    'Squash___Powdery_mildew',
    'Strawberry___Leaf_scorch',
    'Strawberry___healthy',
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy'
]

# Load model at startup
model = None
model_loaded = False
model_error = None

def load_model():
    global model, model_loaded, model_error
    try:
        model_path = os.path.join(BASE_DIR, 'trained_model.h5')
        if not os.path.exists(model_path):
            model_path = os.path.join(BASE_DIR, 'trained_model.keras')
        model = keras.models.load_model(model_path, compile=False)
        model_loaded = True
        print("✅ Model loaded successfully")
    except Exception as e:
        model_error = str(e)
        model_loaded = False
        print(f"❌ Failed to load model: {e}")

# Load model on startup
load_model()

# Response model
class PredictionResponse(BaseModel):
    """Response containing disease prediction."""
    plant: str
    disease: str
    is_healthy: bool
    confidence: float
    raw_class: str
    recommendation: str

@app.get("/")
async def root():
    """Welcome endpoint."""
    return {
        "message": "Welcome to KrishiMitra Plant Disease Detection API",
        "version": "1.0.0",
        "endpoints": {
            "/": "This welcome message",
            "/health": "Health check",
            "/predict": "POST - Upload image to detect disease",
            "/classes": "GET - List all detectable diseases",
            "/docs": "Interactive API documentation"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy" if model_loaded else "unhealthy",
        "model_loaded": model_loaded,
        "error": model_error if not model_loaded else None,
        "num_classes": len(CLASS_NAMES)
    }

@app.get("/classes")
async def get_classes():
    """Get list of all detectable plant diseases."""
    classes_info = []
    for cls in CLASS_NAMES:
        plant, condition = cls.split('___')
        classes_info.append({
            "raw": cls,
            "plant": plant.replace('_', ' '),
            "condition": condition.replace('_', ' '),
            "is_healthy": "healthy" in cls.lower()
        })
    return {
        "total_classes": len(CLASS_NAMES),
        "classes": classes_info
    }

@app.post("/predict", response_model=PredictionResponse)
async def predict_disease(file: UploadFile = File(..., description="Plant leaf image (JPG, PNG)")):
    """
    Predict plant disease from an uploaded image.
    
    Upload a clear image of a plant leaf to detect diseases.
    Supported formats: JPG, JPEG, PNG
    """
    if not model_loaded:
        raise HTTPException(status_code=503, detail=f"Model not loaded: {model_error}")
    
    # Validate file type
    if not file.content_type or not file.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image (JPG, PNG)")
    
    try:
        # Read and process image
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        # Convert to RGB if necessary
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Resize to model input size
        image = image.resize((128, 128))
        
        # Convert to array and add batch dimension
        input_arr = np.array(image)
        input_arr = np.expand_dims(input_arr, axis=0)
        
        # Make prediction
        prediction = model.predict(input_arr, verbose=0)
        result_index = int(np.argmax(prediction))
        confidence = float(np.max(prediction))
        
        # Get class info
        raw_class = CLASS_NAMES[result_index]
        plant, condition = raw_class.split('___')
        plant = plant.replace('_', ' ')
        condition = condition.replace('_', ' ')
        is_healthy = "healthy" in raw_class.lower()
        
        # Generate recommendation
        if is_healthy:
            recommendation = f"Your {plant} plant appears healthy! Continue with regular care and monitoring."
        else:
            recommendation = f"Disease detected: {condition}. Consider consulting an agricultural expert for treatment options."
        
        return PredictionResponse(
            plant=plant,
            disease=condition if not is_healthy else "None",
            is_healthy=is_healthy,
            confidence=confidence,
            raw_class=raw_class,
            recommendation=recommendation
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")

# Run with: uvicorn api:app --reload --port 8002
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
