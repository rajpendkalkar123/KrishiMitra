from flask import Flask, request, jsonify
from flask_cors import CORS
import tensorflow as tf
import numpy as np
from PIL import Image
import io
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Load model
MODEL_PATH = 'trained_model.h5'
model = None

# Class names (38 classes)
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

def load_model():
    global model
    if model is None:
        try:
            model = tf.keras.models.load_model(MODEL_PATH)
            print(f"✅ Model loaded successfully from {MODEL_PATH}")
        except Exception as e:
            print(f"❌ Error loading model: {e}")
            # Try .keras extension
            try:
                model = tf.keras.models.load_model('trained_model.keras')
                print(f"✅ Model loaded from trained_model.keras")
            except:
                raise Exception("Could not load model file")
    return model

def preprocess_image(image):
    """Preprocess image for model prediction"""
    # Resize to 128x128
    image = image.resize((128, 128))
    # Convert to numpy array
    img_array = np.array(image)
    # Expand dimensions to create batch
    img_array = np.expand_dims(img_array, axis=0)
    # Normalize if needed (depends on how model was trained)
    # img_array = img_array / 255.0
    return img_array

@app.route('/')
def home():
    return jsonify({
        "message": "Plant Disease Detection API",
        "status": "running",
        "endpoints": {
            "/predict": "POST - Upload image for disease detection"
        }
    })

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Check if image is in request
        if 'image' not in request.files and 'file' not in request.files:
            return jsonify({
                "error": "No image file provided. Use 'image' or 'file' field name."
            }), 400
        
        # Get image from request
        image_file = request.files.get('image') or request.files.get('file')
        
        if image_file.filename == '':
            return jsonify({"error": "No file selected"}), 400
        
        # Read and process image
        image_bytes = image_file.read()
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Preprocess
        processed_image = preprocess_image(image)
        
        # Load model and predict
        model = load_model()
        predictions = model.predict(processed_image)
        
        # Get predicted class and confidence
        predicted_index = np.argmax(predictions[0])
        confidence = float(predictions[0][predicted_index])
        predicted_class = CLASS_NAMES[predicted_index]
        
        print(f"🔬 Prediction: {predicted_class} ({confidence:.2%})")
        
        # Return response
        return jsonify({
            "class": predicted_class,
            "confidence": confidence,
            "all_predictions": {
                CLASS_NAMES[i]: float(predictions[0][i]) 
                for i in range(len(CLASS_NAMES))
            }
        })
        
    except Exception as e:
        print(f"❌ Error during prediction: {e}")
        return jsonify({
            "error": str(e)
        }), 500

if __name__ == '__main__':
    # Load model on startup
    load_model()
    # Run server
    print("🚀 Starting Flask server on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
