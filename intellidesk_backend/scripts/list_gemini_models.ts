import 'dotenv/config';

async function listModels() {
  const apiKey = process.env.GEMINI_API_KEY;
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`);
  const data = await res.json() as any;
  console.log('Available Models:');
  if (data.models) {
    for (const m of data.models) {
      console.log(`- ${m.name} | Methods: ${m.supportedGenerationMethods?.join(', ')}`);
    }
  } else {
    console.log(data);
  }
}

listModels().catch(console.error);
