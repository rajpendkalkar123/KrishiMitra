"""
Irrigation Prediction System - FastAPI Backend
Provides REST API endpoints for irrigation prediction.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import joblib
import json
import numpy as np

# Initialize FastAPI app
app = FastAPI(
    title="🌾 KrishiMitra Irrigation API",
    description="Smart Irrigation Prediction System - Predicts whether irrigation should be ON or OFF",
    version="1.0.0"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model at startup
try:
    model = joblib.load('irrigation_model.joblib')
    with open('feature_names.json', 'r') as f:
        feature_names = json.load(f)
    with open('model_info.json', 'r') as f:
        model_info = json.load(f)
    model_loaded = True
except Exception as e:
    model_loaded = False
    model_error = str(e)

# Request model
class IrrigationInput(BaseModel):
    """Input parameters for irrigation prediction."""
    soil_moisture: float = Field(..., ge=0, le=100, description="Soil moisture percentage (0-100)")
    temperature: float = Field(..., ge=-10, le=60, description="Soil temperature in Celsius")
    soil_humidity: float = Field(..., ge=0, le=100, description="Soil humidity percentage (0-100)")
    time: int = Field(..., ge=0, le=23, description="Hour of the day (0-23)")
    air_temperature: float = Field(..., ge=-10, le=50, description="Air temperature in Celsius")
    wind_speed: float = Field(..., ge=0, le=50, description="Wind speed in Km/h")
    air_humidity: float = Field(..., ge=0, le=100, description="Air humidity percentage (0-100)")
    wind_gust: float = Field(..., ge=0, le=100, description="Wind gust speed in Km/h")
    pressure: float = Field(..., ge=95, le=110, description="Atmospheric pressure in KPa")
    ph: float = Field(..., ge=0, le=14, description="Soil pH level (0-14)")
    rainfall: float = Field(..., ge=0, le=500, description="Rainfall in mm")
    nitrogen: float = Field(..., ge=0, le=200, description="Nitrogen content (N)")
    phosphorus: float = Field(..., ge=0, le=200, description="Phosphorus content (P)")
    potassium: float = Field(..., ge=0, le=200, description="Potassium content (K)")
    
    class Config:
        json_schema_extra = {
            "example": {
                "soil_moisture": 50,
                "temperature": 30,
                "soil_humidity": 40,
                "time": 12,
                "air_temperature": 25.5,
                "wind_speed": 5.2,
                "air_humidity": 50.0,
                "wind_gust": 10.5,
                "pressure": 101.3,
                "ph": 6.5,
                "rainfall": 200.5,
                "nitrogen": 80,
                "phosphorus": 45,
                "potassium": 40
            }
        }

# Response model
class IrrigationResponse(BaseModel):
    """Response containing irrigation prediction."""
    status: str = Field(..., description="Irrigation status: ON or OFF")
    confidence: float = Field(..., description="Prediction confidence (0-1)")
    probabilities: dict = Field(..., description="Probability for each class")
    recommendation: str = Field(..., description="Human-readable recommendation")

@app.get("/")
async def root():
    """Welcome endpoint."""
    return {
        "message": "Welcome to KrishiMitra Irrigation API",
        "version": "1.0.0",
        "endpoints": {
            "/": "This welcome message",
            "/health": "Health check",
            "/predict": "POST - Predict irrigation status",
            "/model-info": "Get model information",
            "/docs": "Interactive API documentation"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy" if model_loaded else "unhealthy",
        "model_loaded": model_loaded,
        "error": model_error if not model_loaded else None
    }

@app.get("/model-info")
async def get_model_info():
    """Get information about the trained model."""
    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    return {
        "model_type": model_info.get("model_type", "RandomForestClassifier"),
        "accuracy": model_info.get("accuracy", 0),
        "features": feature_names,
        "classes": ["OFF", "ON"],
        "feature_count": len(feature_names)
    }

@app.post("/predict", response_model=IrrigationResponse)
async def predict_irrigation(input_data: IrrigationInput):
    """
    Predict whether irrigation should be ON or OFF.
    
    Takes environmental parameters and returns irrigation recommendation.
    """
    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Prepare features in the correct order matching training data
        # Order: Soil Moisture, Temperature, Soil Humidity, Time, Air temperature (C),
        #        Wind speed (Km/h), Air humidity (%), Wind gust (Km/h), Pressure (KPa),
        #        ph, rainfall, N, P, K
        features = np.array([[
            input_data.soil_moisture,
            input_data.temperature,
            input_data.soil_humidity,
            input_data.time,
            input_data.air_temperature,
            input_data.wind_speed,
            input_data.air_humidity,
            input_data.wind_gust,
            input_data.pressure,
            input_data.ph,
            input_data.rainfall,
            input_data.nitrogen,
            input_data.phosphorus,
            input_data.potassium
        ]])
        
        # Make prediction
        prediction = model.predict(features)[0]
        probabilities = model.predict_proba(features)[0]
        
        status = "ON" if prediction == 1 else "OFF"
        confidence = float(probabilities[prediction])
        
        # Generate recommendation
        if status == "ON":
            recommendation = "Your crops need water. It is recommended to turn ON the irrigation system."
        else:
            recommendation = "Irrigation is not needed at this time. Keep the irrigation system OFF."
        
        return IrrigationResponse(
            status=status,
            confidence=confidence,
            probabilities={
                "OFF": float(probabilities[0]),
                "ON": float(probabilities[1])
            },
            recommendation=recommendation
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")

# Run with: uvicorn api:app --reload --port 8001
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
