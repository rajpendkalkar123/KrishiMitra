"""
Irrigation Prediction System - Streamlit Web Application
Predicts whether irrigation should be ON or OFF based on environmental conditions.
"""

import streamlit as st
import joblib
import json
import numpy as np

st.set_page_config(
    page_title="💧 Irrigation Predictor",
    page_icon="💧",
    layout="wide"
)

# Load model and feature names
@st.cache_resource
def load_model():
    """Load the trained irrigation model."""
    model = joblib.load('irrigation_model.joblib')
    with open('feature_names.json', 'r') as f:
        feature_names = json.load(f)
    with open('model_info.json', 'r') as f:
        model_info = json.load(f)
    return model, feature_names, model_info

try:
    model, feature_names, model_info = load_model()
    model_loaded = True
except Exception as e:
    model_loaded = False
    error_msg = str(e)

# Header
st.title("💧 Smart Irrigation Predictor")
st.markdown("### Predict whether your irrigation system should be **ON** or **OFF**")
st.markdown("---")

if not model_loaded:
    st.error(f"❌ Failed to load model: {error_msg}")
    st.stop()

# Display model info
with st.expander("📊 Model Information"):
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Model Type", "Random Forest")
    with col2:
        st.metric("Accuracy", f"{model_info['accuracy']*100:.2f}%")
    with col3:
        st.metric("Features", len(feature_names))

st.markdown("### 📝 Enter Environmental Conditions")

# Create input columns
col1, col2 = st.columns(2)

with col1:
    st.markdown("#### 🌱 Soil Conditions")
    soil_moisture = st.slider("Soil Moisture (%)", 0, 100, 50, help="Current soil moisture level")
    soil_humidity = st.slider("Soil Humidity (%)", 0, 100, 50, help="Current soil humidity level")
    ph = st.slider("Soil pH", 0.0, 14.0, 6.5, 0.1, help="Soil pH level")
    
    st.markdown("#### 🧪 Nutrients (NPK)")
    nitrogen = st.number_input("Nitrogen (N)", 0, 200, 80, help="Nitrogen content in soil")
    phosphorus = st.number_input("Phosphorus (P)", 0, 200, 45, help="Phosphorus content in soil")
    potassium = st.number_input("Potassium (K)", 0, 200, 40, help="Potassium content in soil")

with col2:
    st.markdown("#### 🌡️ Weather Conditions")
    temperature = st.slider("Soil Temperature (°C)", -10, 60, 30, help="Current soil temperature")
    air_temp = st.slider("Air Temperature (°C)", -10.0, 50.0, 25.0, 0.1, help="Current air temperature")
    air_humidity = st.slider("Air Humidity (%)", 0.0, 100.0, 50.0, 0.1, help="Current air humidity")
    
    st.markdown("#### 💨 Wind & Pressure")
    wind_speed = st.slider("Wind Speed (Km/h)", 0.0, 50.0, 5.0, 0.1, help="Current wind speed")
    wind_gust = st.slider("Wind Gust (Km/h)", 0.0, 100.0, 10.0, 0.1, help="Wind gust speed")
    pressure = st.slider("Atmospheric Pressure (KPa)", 95.0, 110.0, 101.3, 0.1, help="Atmospheric pressure")
    
    st.markdown("#### 🌧️ Other")
    rainfall = st.number_input("Rainfall (mm)", 0.0, 500.0, 200.0, 0.1, help="Expected/recent rainfall")
    time_hour = st.slider("Time (Hour)", 0, 23, 12, help="Current hour of the day")

st.markdown("---")

# Predict button
if st.button("🔮 Predict Irrigation Status", type="primary", use_container_width=True):
    # Prepare input in the correct order matching training data
    # Order: Soil Moisture, Temperature, Soil Humidity, Time, Air temperature (C), 
    #        Wind speed (Km/h), Air humidity (%), Wind gust (Km/h), Pressure (KPa), 
    #        ph, rainfall, N, P, K
    input_data = np.array([[
        soil_moisture,
        temperature,
        soil_humidity,
        time_hour,
        air_temp,
        wind_speed,
        air_humidity,
        wind_gust,
        pressure,
        ph,
        rainfall,
        nitrogen,
        phosphorus,
        potassium
    ]])
    
    # Make prediction
    prediction = model.predict(input_data)[0]
    prediction_proba = model.predict_proba(input_data)[0]
    
    status = "ON" if prediction == 1 else "OFF"
    confidence = prediction_proba[prediction] * 100
    
    # Display result
    st.markdown("### 🎯 Prediction Result")
    
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col2:
        if status == "ON":
            st.success(f"## 💧 Irrigation: **{status}**")
            st.markdown("Your crops need water! Turn on the irrigation system.")
        else:
            st.info(f"## ⏸️ Irrigation: **{status}**")
            st.markdown("No irrigation needed at this time.")
        
        st.metric("Confidence", f"{confidence:.1f}%")
    
    # Show probability breakdown
    with st.expander("📈 Probability Breakdown"):
        st.write(f"- OFF: {prediction_proba[0]*100:.1f}%")
        st.write(f"- ON: {prediction_proba[1]*100:.1f}%")

# Footer
st.markdown("---")
st.markdown(
    """
    <div style='text-align: center; color: gray;'>
        <p>🌾 KrishiMitra - Smart Irrigation System | Powered by Machine Learning</p>
    </div>
    """,
    unsafe_allow_html=True
)
