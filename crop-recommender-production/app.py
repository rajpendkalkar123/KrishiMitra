import streamlit as st 
import pandas as pd 
import numpy as np
import os
import tensorflow as tf
from sklearn.preprocessing import StandardScaler

# Page config - MUST be first Streamlit command
st.set_page_config(page_title="KrishiMitra Crop Recommender", page_icon="🌾")

# Use relative paths for deployment
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Load model (trained with Keras 3)
@st.cache_resource
def load_model():
    model_path = os.path.join(BASE_DIR, 'notebooks', 'crop_recommendation_model.h5')
    return tf.keras.models.load_model(model_path, compile=False)

@st.cache_data
def load_data():
    return pd.read_csv(os.path.join(BASE_DIR, "data/crop_and_fertilizer.csv"))

@st.cache_resource
def load_scaler():
    # Fit scaler on dataset (same as during training)
    # Training used columns after dropping: ['Unnamed: 0', 'District_Name', 'Soil_color', 'Nitrogen', 'Phosphorus', 'Potassium', 'pH', 'Rainfall', 'Temperature']
    dataset = pd.read_csv(os.path.join(BASE_DIR, "data/crop_and_fertilizer.csv"))
    scaler = StandardScaler()
    x = dataset[['Unnamed: 0', 'District_Name', 'Soil_color', 'Nitrogen', 'Phosphorus', 'Potassium', 'pH', 'Rainfall', 'Temperature']]
    scaler.fit(x)
    return scaler

model = load_model()
dataset = load_data()
scaler = load_scaler()

# Encoding mappings (must match training)
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

st.title('🌾 KrishiMitra Crop Recommender')
st.markdown("Get AI-powered crop recommendations based on your soil and environmental conditions.")

st.divider()

# Input form
col1, col2 = st.columns(2)

with col1:
    district = st.selectbox('📍 Select District', list(district_to_encoded.keys()))
    soil_color = st.selectbox('🟤 Soil Color', list(soil_color_to_encoded.keys()))
    nitrogen = st.number_input('🧪 Nitrogen (N)', min_value=20, max_value=150, value=50)
    phosphorus = st.number_input('🧪 Phosphorus (P)', min_value=10, max_value=90, value=40)

with col2:
    potassium = st.number_input('🧪 Potassium (K)', min_value=5, max_value=150, value=50)
    ph = st.slider('⚗️ pH Level', min_value=0.5, max_value=8.5, value=6.5)
    rainfall = st.number_input('🌧️ Rainfall (mm)', min_value=300, max_value=1700, value=800)
    temperature = st.number_input('🌡️ Temperature (°C)', min_value=10, max_value=40, value=25)

st.divider()

def predict_crop(district, soil_color, nitrogen, phosphorus, potassium, ph, rainfall, temperature):
    """Predict crop based on input features"""
    # Encode categorical features
    encoded_district = district_to_encoded[district]
    encoded_soil_color = soil_color_to_encoded[soil_color]
    
    # Prepare features in the same order as training
    # Training used: ['Unnamed: 0', 'District_Name', 'Soil_color', 'Nitrogen', 'Phosphorus', 'Potassium', 'pH', 'Rainfall', 'Temperature']
    # We use 0 for 'Unnamed: 0' (row index from training data)
    features = [[
        0,  # Unnamed: 0 (row index placeholder)
        encoded_district,
        encoded_soil_color,
        nitrogen,
        phosphorus,
        potassium,
        ph,
        rainfall,
        temperature
    ]]
    
    # Scale and predict
    scaled_features = scaler.transform(features)
    prediction = model.predict(scaled_features, verbose=0)
    
    predicted_class_index = int(np.argmax(prediction))
    confidence = float(np.max(prediction))
    predicted_crop = encoded_to_label.get(predicted_class_index, "Unknown")
    
    return predicted_crop, confidence

# Predict button
if st.button('🌱 Recommend Crop', type='primary', use_container_width=True):
    with st.spinner('Analyzing soil and climate conditions...'):
        predicted_crop, confidence = predict_crop(
            district, soil_color, nitrogen, phosphorus, 
            potassium, ph, rainfall, temperature
        )
        
        st.success(f"### 🌾 Recommended Crop: **{predicted_crop}**")
        st.info(f"📊 Confidence: **{confidence*100:.1f}%**")
        
        # Show input summary
        with st.expander("📋 Input Summary"):
            st.write(f"- **District:** {district}")
            st.write(f"- **Soil Color:** {soil_color}")
            st.write(f"- **NPK:** N={nitrogen}, P={phosphorus}, K={potassium}")
            st.write(f"- **pH:** {ph}")
            st.write(f"- **Rainfall:** {rainfall} mm")
            st.write(f"- **Temperature:** {temperature}°C")

st.divider()

# Footer
st.markdown("""
<div style='text-align: center; color: gray;'>
    <p>🌿 KrishiMitra - Your Smart Farming Assistant</p>
</div>
""", unsafe_allow_html=True)
