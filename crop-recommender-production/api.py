from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import tensorflow as tf
from sklearn.preprocessing import StandardScaler
import pandas as pd
import os

# Initialize FastAPI app
app = FastAPI(
    title="KrishiMitra Crop Recommendation API",
    description="API for predicting the best crop based on soil and environmental conditions",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model and data
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
model = tf.keras.models.load_model(os.path.join(BASE_DIR, 'notebooks', 'crop_recommendation_model.h5'), compile=False)
dataset = pd.read_csv(os.path.join(BASE_DIR, "data/crop_and_fertilizer.csv"))

# Initialize and fit scaler with training data (9 features including Unnamed: 0)
scaler = StandardScaler()
x = dataset[['Unnamed: 0', 'District_Name', 'Soil_color', 'Nitrogen', 'Phosphorus', 'Potassium', 'pH', 'Rainfall', 'Temperature']]
scaler.fit(x)

# Encoding mappings
district_to_encoded = {
    'Khartoum': 2,
    'ALfashir': 0,
    'Algazira': 1,
    'Shendi': 4,
    'Niyala': 3
}

soil_color_to_encoded = {
    'Black': 0,
    'Red': 5,
    'Medium Brown': 3,
    'Dark Brown': 1,
    'Light Brown': 2,
    'Reddish Brown': 6
}

encoded_to_label = {
    0: 'Cotton',
    1: 'Ginger',
    2: 'Gram',
    3: 'Grapes',
    4: 'Groundnut',
    5: 'Jowar',
    6: 'Maize',
    7: 'Masoor',
    8: 'Moong',
    9: 'Rice',
    10: 'Soybean',
    11: 'Sugarcane',
    12: 'Tur',
    13: 'Turmeric',
    14: 'Urad',
    15: 'Wheat'
}

# Request model
class CropPredictionRequest(BaseModel):
    district: str
    soil_color: str
    nitrogen: float
    phosphorus: float
    potassium: float
    ph: float
    rainfall: float
    temperature: float

# Response model
class CropPredictionResponse(BaseModel):
    recommended_crop: str
    confidence: float

# Fertilizer response model
class FertilizerRecommendationResponse(BaseModel):
    crop: str
    crop_confidence: float
    recommended_fertilizer: str
    fertilizer_confidence: float
    tutorial_link: str
    alternative_fertilizers: list

# Fertilizer request model (crop as input)
class FertilizerRequest(BaseModel):
    crop: str
    district: str
    soil_color: str
    nitrogen: float
    phosphorus: float
    potassium: float
    ph: float
    rainfall: float
    temperature: float

@app.get("/")
def root():
    return {
        "message": "KrishiMitra Crop Recommendation API",
        "docs": "/docs",
        "endpoints": {
            "predict": "POST /predict - Get crop recommendation",
            "recommend-fertilizer": "POST /recommend-fertilizer - Get crop and fertilizer recommendation"
        }
    }

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.post("/predict", response_model=CropPredictionResponse)
def predict(request: CropPredictionRequest):
    try:
        # Encode district
        encoded_district = district_to_encoded.get(request.district, -1)
        if encoded_district == -1:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid district. Valid options: {list(district_to_encoded.keys())}"
            )
        
        # Encode soil color
        encoded_soil_color = soil_color_to_encoded.get(request.soil_color, -1)
        if encoded_soil_color == -1:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid soil color. Valid options: {list(soil_color_to_encoded.keys())}"
            )
        
        # Prepare features (9 features: Unnamed: 0 placeholder + 8 input features)
        features = [[
            0,  # Unnamed: 0 placeholder (row index from training)
            encoded_district,
            encoded_soil_color,
            request.nitrogen,
            request.phosphorus,
            request.potassium,
            request.ph,
            request.rainfall,
            request.temperature
        ]]
        
        # Scale and predict
        scaled_features = scaler.transform(features)
        prediction = model.predict(scaled_features, verbose=0)
        predicted_class_index = int(np.argmax(prediction))
        confidence = float(np.max(prediction))
        predicted_crop = encoded_to_label.get(predicted_class_index, "Unknown")
        
        return CropPredictionResponse(
            recommended_crop=predicted_crop,
            confidence=round(confidence, 4)
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/options")
def get_options():
    """Get valid input options for the prediction"""
    return {
        "districts": list(district_to_encoded.keys()),
        "soil_colors": list(soil_color_to_encoded.keys()),
        "crops": list(encoded_to_label.values()),
        "fertilizers": dataset['Fertilizer'].unique().tolist(),
        "ranges": {
            "nitrogen": {"min": 20, "max": 150},
            "phosphorus": {"min": 10, "max": 90},
            "potassium": {"min": 5, "max": 150},
            "ph": {"min": 0.5, "max": 8.5},
            "rainfall": {"min": 300, "max": 1700},
            "temperature": {"min": 10, "max": 40}
        }
    }

@app.post("/recommend-fertilizer", response_model=FertilizerRecommendationResponse)
def recommend_fertilizer(request: FertilizerRequest):
    """
    Recommend fertilizer based on selected crop and soil conditions.
    
    User provides the crop they want to grow, and the system recommends
    the best fertilizer based on soil NPK levels.
    """
    try:
        # Validate crop
        valid_crops = list(encoded_to_label.values())
        if request.crop not in valid_crops:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid crop. Valid options: {valid_crops}"
            )
        
        # Filter dataset for the selected crop
        crop_matches = dataset[dataset['Crop_string'] == request.crop].copy()
        
        if len(crop_matches) == 0:
            raise HTTPException(
                status_code=404,
                detail=f"No fertilizer data available for {request.crop}"
            )
        
        # Find closest match based on NPK values and environmental conditions
        crop_matches['npk_distance'] = (
            abs(crop_matches['Nitrogen'] - request.nitrogen) +
            abs(crop_matches['Phosphorus'] - request.phosphorus) +
            abs(crop_matches['Potassium'] - request.potassium)
        )
        
        # Get the fertilizer with minimum distance
        best_match = crop_matches.loc[crop_matches['npk_distance'].idxmin()]
        recommended_fertilizer = best_match['Fertilizer']
        tutorial_link = best_match['Link']
        
        # Calculate fertilizer confidence based on frequency
        fertilizer_counts = crop_matches['Fertilizer'].value_counts()
        total_matches = len(crop_matches)
        fertilizer_confidence = float(fertilizer_counts[recommended_fertilizer] / total_matches)
        
        # Get alternative fertilizers (top 3 most common, excluding the recommended one)
        top_fertilizers = fertilizer_counts.head(4).index.tolist()
        alternatives = [f for f in top_fertilizers if f != recommended_fertilizer][:2]
        
        return FertilizerRecommendationResponse(
            crop=request.crop,
            crop_confidence=1.0,  # User selected crop, so confidence is 100%
            recommended_fertilizer=recommended_fertilizer,
            fertilizer_confidence=round(fertilizer_confidence, 4),
            tutorial_link=tutorial_link,
            alternative_fertilizers=alternatives
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

