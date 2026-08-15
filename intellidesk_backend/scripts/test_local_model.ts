import { pipeline } from '@xenova/transformers';

async function testLocalModel() {
  console.log('🧪 Testing local ONNX text-generation pipeline...');
  const start = Date.now();
  try {
    const generator = await pipeline('text-generation', 'Xenova/distilgpt2');
    console.log(`✅ Loaded local model in ${Date.now() - start}ms`);
    
    const output = await generator('Patient says: I have severe knee pain and need help. Counselor:', {
      max_new_tokens: 30,
      temperature: 0.7,
    });
    console.log('Output:', output);
  } catch (err: any) {
    console.error('Error:', err.message);
  }
}

testLocalModel().catch(console.error);
