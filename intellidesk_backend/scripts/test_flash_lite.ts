import 'dotenv/config';
import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

async function testLite() {
  const models = ['gemini-flash-lite-latest', 'gemini-2.5-flash-lite', 'gemini-flash-latest'];
  for (const m of models) {
    try {
      const model = genAI.getGenerativeModel({
        model: m,
        generationConfig: { maxOutputTokens: 60, temperature: 0.6 },
      });
      const start = Date.now();
      const res = await model.generateContent('1 short sentence of empathetic reassurance to a patient with sudden chest pain.');
      console.log(`✅ [${m}] (${Date.now() - start}ms): ${res.response.text().trim()}`);
    } catch (err: any) {
      console.log(`❌ [${m}] failed:`, err.message);
    }
  }
}

testLite().catch(console.error);
