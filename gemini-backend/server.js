const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

// Initialize Gemini
let genAI;
let model;

if (GEMINI_API_KEY) {
  genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });
}

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'KrishiMitra Gemini Backend is running',
    endpoints: ['/api/gemini/recommend'],
    apiKeyLoaded: !!GEMINI_API_KEY
  });
});

// Advanced fallback recommendation engine
function generateAdvancedRecommendation(data) {
  const {
    cropType,
    soilMoisture = 50,
    nitrogen = 40,
    phosphorus = 25,
    potassium = 30,
    pH = 6.5,
    temperature = 28,
    rainfall = 10,
    farmArea = 2,
    growthStage = 'Vegetative',
    soilType = 'Loamy'
  } = data;

  // Irrigation recommendation logic
  let irrigationAction, waterAmount, irrigationReason;
  
  if (soilMoisture < 25) {
    irrigationAction = 'START IMMEDIATELY';
    waterAmount = 3500;
    irrigationReason = `CRITICAL: Soil moisture at ${soilMoisture}% is dangerously low for ${cropType}. Immediate deep irrigation required to prevent permanent crop damage and yield loss. The crop is under severe water stress.`;
  } else if (soilMoisture < 40) {
    irrigationAction = 'START';
    waterAmount = 2500;
    irrigationReason = `Soil moisture at ${soilMoisture}% is below the optimal range (50-65%) for ${cropType} in ${growthStage} stage. Begin irrigation soon to support healthy growth and prevent stress.`;
  } else if (soilMoisture > 85) {
    irrigationAction = 'STOP';
    waterAmount = 0;
    irrigationReason = `WARNING: Soil moisture at ${soilMoisture}% is critically high. Stop all irrigation immediately to prevent waterlogging, root rot, and oxygen deprivation. Ensure proper drainage.`;
  } else if (soilMoisture > 70) {
    irrigationAction = 'REDUCE';
    waterAmount = 800;
    irrigationReason = `Soil moisture at ${soilMoisture}% is adequate to high. Reduce irrigation frequency to prevent waterlogging and optimize water usage efficiency.`;
  } else if (soilMoisture >= 50 && soilMoisture <= 65) {
    irrigationAction = 'MAINTAIN';
    waterAmount = 1200;
    irrigationReason = `Excellent! Soil moisture at ${soilMoisture}% is in the optimal range (50-65%) for ${cropType}. Maintain current irrigation schedule for best results.`;
  } else {
    irrigationAction = 'INCREASE';
    waterAmount = 1800;
    irrigationReason = `Soil moisture at ${soilMoisture}% is slightly below optimal. Consider increasing irrigation frequency slightly to reach the 50-65% target range.`;
  }

  // Fertilizer recommendation logic
  let fertilizerType, fertilizerQuantity, fertilizerReason, applicationMethod;
  
  const nDeficient = nitrogen < 35;
  const pDeficient = phosphorus < 20;
  const kDeficient = potassium < 25;
  
  if (nDeficient && pDeficient && kDeficient) {
    fertilizerType = 'NPK Complex 19:19:19 + Micronutrients';
    fertilizerQuantity = 40;
    fertilizerReason = `All major nutrients are deficient - N: ${nitrogen} kg/ha (low), P: ${phosphorus} kg/ha (low), K: ${potassium} kg/ha (low). Apply balanced NPK with micronutrients for comprehensive nutrition.`;
    applicationMethod = 'Broadcast evenly before irrigation and incorporate into top soil';
  } else if (nDeficient && pDeficient) {
    fertilizerType = 'DAP 18-46-0 + Urea';
    fertilizerQuantity = 35;
    fertilizerReason = `Nitrogen (${nitrogen} kg/ha) and Phosphorus (${phosphorus} kg/ha) are both deficient. DAP provides both N and P, supplement with Urea for additional nitrogen.`;
    applicationMethod = 'Apply DAP at sowing, top-dress with Urea at 25-30 days';
  } else if (nDeficient) {
    fertilizerType = 'Urea (46-0-0)';
    fertilizerQuantity = 30;
    fertilizerReason = `Nitrogen at ${nitrogen} kg/ha is deficient for ${cropType} in ${growthStage} stage. Urea provides quick-release nitrogen for vegetative growth and chlorophyll production.`;
    applicationMethod = 'Split application - 50% now, 50% at next growth stage';
  } else if (pDeficient) {
    fertilizerType = 'Single Super Phosphate (SSP)';
    fertilizerQuantity = 28;
    fertilizerReason = `Phosphorus at ${phosphorus} kg/ha is low. SSP will boost root development, flowering, and energy transfer in plants.`;
    applicationMethod = 'Band placement near root zone for better uptake';
  } else if (kDeficient) {
    fertilizerType = 'Muriate of Potash (MOP 0-0-60)';
    fertilizerQuantity = 22;
    fertilizerReason = `Potassium at ${potassium} kg/ha needs improvement. MOP will enhance disease resistance, water regulation, and grain/fruit quality.`;
    applicationMethod = 'Broadcast and incorporate before irrigation';
  } else {
    fertilizerType = 'Micronutrient Mixture (Zn, Fe, Mn, B, Cu)';
    fertilizerQuantity = 8;
    fertilizerReason = `NPK levels are adequate (N:${nitrogen}, P:${phosphorus}, K:${potassium}). Apply micronutrients to prevent hidden deficiencies and optimize crop performance.`;
    applicationMethod = 'Foliar spray in early morning or late evening';
  }

  // Risk assessment
  const risks = [];
  
  if (temperature > 40) {
    risks.push(`🔴 EXTREME HEAT ALERT: Temperature at ${temperature}°C is causing severe heat stress. Irrigate during cooler hours (5-7 AM), apply reflective mulch, and consider shade nets. Avoid all field operations during peak heat.`);
  } else if (temperature > 35) {
    risks.push(`🟠 HIGH TEMPERATURE WARNING: ${temperature}°C may stress ${cropType}. Increase irrigation frequency, ensure adequate mulching, and avoid fertilizer application during hot hours.`);
  } else if (temperature > 32) {
    risks.push(`🟡 Warm conditions at ${temperature}°C - monitor crop for wilting signs. Consider light irrigation during evening.`);
  }
  
  if (temperature < 8) {
    risks.push(`🔵 FROST WARNING: Temperature at ${temperature}°C risks frost damage to ${cropType}. Cover young plants, avoid night irrigation, and delay sowing if possible.`);
  } else if (temperature < 12) {
    risks.push(`🔵 Low temperature at ${temperature}°C may slow growth. Protect seedlings and avoid early morning irrigation.`);
  }
  
  if (soilMoisture > 80 && temperature > 25) {
    risks.push(`🟡 DISEASE ALERT: High moisture (${soilMoisture}%) combined with warm temperature (${temperature}°C) creates ideal conditions for fungal diseases. Apply preventive fungicide and ensure good air circulation.`);
  }
  
  if (pH < 5.5) {
    risks.push(`⚠️ ACIDIC SOIL (pH ${pH}): Apply agricultural lime (200-400 kg/acre) to correct pH. Nutrient availability is reduced in acidic conditions.`);
  } else if (pH > 8.0) {
    risks.push(`⚠️ ALKALINE SOIL (pH ${pH}): Apply gypsum or elemental sulfur. Iron and zinc may be locked up at high pH.`);
  }
  
  if (rainfall > 100) {
    risks.push(`🌧️ HEAVY RAINFALL (${rainfall}mm): Risk of waterlogging and nutrient leaching. Ensure drainage, delay fertilizer application, and watch for pest outbreaks.`);
  } else if (rainfall > 50 && growthStage === 'Flowering') {
    risks.push(`🌧️ Rain during flowering (${rainfall}mm) may affect pollination. Monitor for flower drop and consider growth regulators if needed.`);
  }
  
  if (risks.length === 0) {
    risks.push(`✅ No major risks detected. Current conditions are favorable for ${cropType} growth. Continue regular monitoring and maintenance.`);
  }

  // Yield and profit calculations
  const cropData = {
    'Wheat': { baseYield: 18, price: 2400 },
    'Rice': { baseYield: 22, price: 2800 },
    'Sugarcane': { baseYield: 350, price: 350 },
    'Cotton': { baseYield: 8, price: 6500 },
    'Maize': { baseYield: 25, price: 2100 },
    'Soybean': { baseYield: 12, price: 4500 },
    'Groundnut': { baseYield: 10, price: 5800 },
    'Gram': { baseYield: 8, price: 5200 },
    'Mustard': { baseYield: 8, price: 5500 },
    'Potato': { baseYield: 120, price: 1200 },
    'Tomato': { baseYield: 200, price: 1500 },
    'Onion': { baseYield: 150, price: 1800 }
  };

  const crop = cropData[cropType] || { baseYield: 15, price: 3000 };
  
  // Calculate improvement percentage based on conditions
  let improvementPercent = 0;
  if (soilMoisture < 40 || soilMoisture > 75) improvementPercent += 12;
  if (nDeficient || pDeficient || kDeficient) improvementPercent += 15;
  if (temperature > 35 || temperature < 12) improvementPercent += 8;
  if (pH < 6.0 || pH > 7.5) improvementPercent += 5;
  improvementPercent = Math.min(improvementPercent, 35); // Cap at 35%

  const yieldWithoutAI = crop.baseYield;
  const yieldWithAI = crop.baseYield * (1 + improvementPercent / 100);
  
  const revenueWithoutAI = yieldWithoutAI * crop.price * farmArea;
  const revenueWithAI = yieldWithAI * crop.price * farmArea;
  
  const waterSavings = soilMoisture > 50 ? 5000 : 2500;
  const fertilizerSavings = (!nDeficient && !pDeficient && !kDeficient) ? 4500 : 2000;

  // Growth stage specific tips
  const stageSpecificTips = {
    'Seedling': `Maintain consistent moisture for ${cropType} seedlings. Protect from direct harsh sunlight and extreme temperatures. Thin out weak seedlings for better spacing.`,
    'Vegetative': `${cropType} is in active growth phase. Ensure adequate nitrogen supply for leaf development. Monitor for early pest infestations and weed competition.`,
    'Flowering': `Critical stage for ${cropType}! Avoid water stress and excessive nitrogen. Ensure adequate phosphorus and potassium. Protect from heavy rain and extreme temperatures.`,
    'Fruiting': `Focus on potassium for ${cropType} fruit/grain quality. Maintain consistent moisture. Reduce nitrogen to prevent excessive vegetative growth at expense of yield.`,
    'Maturity': `${cropType} is nearing harvest. Gradually reduce irrigation. Monitor grain/fruit moisture content. Plan harvest timing based on market conditions.`
  };

  const harvestTiming = {
    'Seedling': '10-14 weeks to harvest, depending on variety',
    'Vegetative': '8-12 weeks to harvest',
    'Flowering': '6-8 weeks to harvest',
    'Fruiting': '3-5 weeks to harvest',
    'Maturity': '1-2 weeks to harvest - prepare for harvesting'
  };

  return {
    irrigationRecommendation: {
      action: irrigationAction,
      waterAmount: waterAmount,
      timing: temperature > 32 
        ? 'Early morning (5-7 AM) or evening (5-7 PM) to minimize evaporation losses'
        : 'Morning (6-9 AM) is optimal for water uptake',
      frequency: soilMoisture < 40 
        ? 'Every 2-3 days until moisture reaches 50%+'
        : (soilMoisture > 65 ? 'Every 5-7 days' : 'Every 3-4 days'),
      reason: irrigationReason
    },
    fertilizerRecommendation: {
      type: fertilizerType,
      quantity: fertilizerQuantity,
      applicationMethod: applicationMethod,
      timing: growthStage === 'Flowering' || growthStage === 'Fruiting'
        ? 'Apply within 2-3 days - critical period for nutrient demand'
        : 'Apply within next 5-7 days, preferably before irrigation',
      reason: fertilizerReason
    },
    cropHealthTips: [
      `🌱 ${stageSpecificTips[growthStage] || 'Monitor crop health regularly and maintain optimal growing conditions.'}`,
      `🌡️ Current temperature (${temperature}°C) management: ${temperature > 35 ? 'Apply mulch, irrigate during cooler hours' : temperature < 15 ? 'Protect from cold, ensure good drainage' : 'Conditions favorable, maintain regular care'}`,
      `🧪 Soil pH at ${pH} - ${pH >= 6.0 && pH <= 7.5 ? 'Optimal range for nutrient availability' : 'Consider pH correction for improved nutrient uptake'}`
    ],
    expectedYield: {
      withAI: Math.round(yieldWithAI * 10) / 10,
      withoutAI: yieldWithoutAI,
      improvementPercent: Math.round(improvementPercent * 10) / 10
    },
    profitAnalysis: {
      estimatedRevenueWithAI: Math.round(revenueWithAI),
      estimatedRevenueWithoutAI: Math.round(revenueWithoutAI),
      additionalProfitWithAI: Math.round(revenueWithAI - revenueWithoutAI),
      costSavings: {
        water: waterSavings,
        fertilizer: fertilizerSavings,
        total: waterSavings + fertilizerSavings
      }
    },
    riskAlerts: risks,
    weeklyActionPlan: [
      {
        day: 'Day 1-2',
        action: `${irrigationAction} irrigation with ${waterAmount}L/acre. ${fertilizerQuantity > 15 ? `Apply ${fertilizerType} (${fertilizerQuantity} kg/acre)` : 'Monitor crop health and soil moisture'}`
      },
      {
        day: 'Day 3-4',
        action: `Scout for pests and diseases in ${cropType} field. Check soil moisture levels - target 50-65%. ${temperature > 33 ? 'Ensure adequate irrigation during peak heat hours.' : 'Regular monitoring is sufficient.'}`
      },
      {
        day: 'Day 5-7',
        action: `Evaluate ${cropType} response to inputs. Plan next irrigation cycle. ${rainfall > 30 ? 'Account for rainfall in your irrigation planning.' : 'Prepare for next scheduled irrigation if needed.'}`
      }
    ],
    marketTiming: {
      optimalHarvestTime: harvestTiming[growthStage] || 'Monitor crop maturity indicators',
      expectedMarketPrice: crop.price,
      recommendation: new Date().getMonth() >= 9 && new Date().getMonth() <= 11
        ? `Pre-season demand typically increases. Good time to plan for premium prices. Current ${cropType} rate: ₹${crop.price}/quintal`
        : `Monitor daily mandi prices. Current reference rate for ${cropType}: ₹${crop.price}/quintal. Consider storage if prices are low.`
    },
    isFromGeminiAI: false, // This is rule-based fallback
    generatedAt: new Date().toISOString(),
    source: 'advanced-rule-engine',
    inputData: data
  };
}

// Main recommendation endpoint
app.post('/api/gemini/recommend', async (req, res) => {
  try {
    const {
      cropType,
      soilMoisture,
      nitrogen,
      phosphorus,
      potassium,
      pH,
      temperature,
      rainfall,
      farmArea,
      growthStage,
      soilType
    } = req.body;

    // Validate required fields
    if (!cropType) {
      return res.status(400).json({ error: 'cropType is required' });
    }

    if (!GEMINI_API_KEY || !model) {
      console.log('⚠️ No API key - using advanced rule-based recommendations');
      return res.json(generateAdvancedRecommendation(req.body));
    }

    const prompt = `You are an expert agricultural advisor for Indian farmers. Analyze the following farm data and provide detailed, personalized recommendations.

**Farm Data:**
- Crop: ${cropType}
- Farm Area: ${farmArea || 2} acres
- Growth Stage: ${growthStage || 'Vegetative'}
- Soil Type: ${soilType || 'Loamy'}

**Current Conditions:**
- Soil Moisture: ${soilMoisture || 50}%
- Nitrogen (N): ${nitrogen || 40} kg/ha
- Phosphorus (P): ${phosphorus || 25} kg/ha
- Potassium (K): ${potassium || 30} kg/ha
- Soil pH: ${pH || 6.5}
- Temperature: ${temperature || 28}°C
- Rainfall (weekly): ${rainfall || 10} mm

Based on these SPECIFIC values, provide CUSTOMIZED recommendations. You MUST respond ONLY with valid JSON (no markdown, no explanation, no code blocks). Start directly with { and end with }:
{
  "irrigationRecommendation": {
    "action": "START or STOP or REDUCE or INCREASE or MAINTAIN",
    "waterAmount": <number in liters per acre>,
    "timing": "<specific time recommendation>",
    "frequency": "<how often based on current moisture>",
    "reason": "<explain why based on the ${soilMoisture || 50}% moisture level>"
  },
  "fertilizerRecommendation": {
    "type": "<specific fertilizer name for ${cropType}>",
    "quantity": <number in kg per acre>,
    "applicationMethod": "<how to apply>",
    "timing": "<when to apply based on ${growthStage || 'Vegetative'} stage>",
    "reason": "<explain based on N=${nitrogen || 40}, P=${phosphorus || 25}, K=${potassium || 30} levels>"
  },
  "cropHealthTips": [
    "<tip specific to ${cropType} at ${growthStage || 'Vegetative'} stage>",
    "<tip based on current temperature ${temperature || 28}°C>",
    "<tip based on soil conditions>"
  ],
  "expectedYield": {
    "withAI": <realistic quintals per acre for ${cropType}>,
    "withoutAI": <lower quintals without optimization>,
    "improvementPercent": <percentage improvement>
  },
  "profitAnalysis": {
    "estimatedRevenueWithAI": <rupees per acre with AI optimization>,
    "estimatedRevenueWithoutAI": <rupees per acre traditional>,
    "additionalProfitWithAI": <difference in rupees>,
    "costSavings": {
      "water": <rupees saved on water>,
      "fertilizer": <rupees saved on fertilizer>,
      "total": <total savings>
    }
  },
  "riskAlerts": [
    "<risk based on ${temperature || 28}°C temperature if any>",
    "<risk based on ${rainfall || 10}mm rainfall if any>"
  ],
  "weeklyActionPlan": [
    {"day": "Day 1-2", "action": "<specific action for ${cropType}>"},
    {"day": "Day 3-4", "action": "<specific action>"},
    {"day": "Day 5-7", "action": "<specific action>"}
  ],
  "marketTiming": {
    "optimalHarvestTime": "<when to harvest ${cropType} at ${growthStage || 'Vegetative'} stage>",
    "expectedMarketPrice": <current market price in rupees per quintal>,
    "recommendation": "<sell now or wait advice with reason>"
  }
}`;

    console.log('📤 Sending request to Gemini API via SDK...');
    console.log('   Crop:', cropType, '| Moisture:', soilMoisture, '| NPK:', nitrogen, phosphorus, potassium);

    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      let text = response.text();

      console.log('📥 Raw Gemini Response:', text.substring(0, 200) + '...');

      // Clean up the response
      text = text.trim();
      if (text.startsWith('```json')) {
        text = text.slice(7);
      } else if (text.startsWith('```')) {
        text = text.slice(3);
      }
      if (text.endsWith('```')) {
        text = text.slice(0, -3);
      }
      text = text.trim();

      // Parse JSON
      let jsonResponse;
      try {
        jsonResponse = JSON.parse(text);
      } catch (parseError) {
        console.error('❌ JSON Parse Error - falling back to rule engine');
        return res.json(generateAdvancedRecommendation(req.body));
      }

      // Add metadata
      jsonResponse.isFromGeminiAI = true;
      jsonResponse.generatedAt = new Date().toISOString();
      jsonResponse.source = 'gemini-ai';
      jsonResponse.inputData = req.body;

      console.log('✅ Successfully processed Gemini AI response');
      res.json(jsonResponse);
    } catch (apiError) {
      console.error('❌ Gemini API Error:', apiError.message);
      console.log('↩️ Falling back to advanced rule-based recommendations');
      res.json(generateAdvancedRecommendation(req.body));
    }

  } catch (error) {
    console.error('❌ Server Error:', error.message);
    res.status(500).json({ 
      error: 'Failed to get recommendation',
      details: error.message
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`
  🌾 KrishiMitra Gemini Backend Server
  ====================================
  🚀 Server running on http://localhost:${PORT}
  📡 API Endpoint: POST /api/gemini/recommend
  🔑 API Key: ${GEMINI_API_KEY ? '✅ Loaded' : '⚠️ Missing (using rule engine)'}
  📦 Using: @google/generative-ai SDK with rule-based fallback
  `);
});

