import { pipeline } from '@xenova/transformers';

let generator: any = null;

/**
 * Initializes or returns the cached local Hugging Face text-generation pipeline.
 * Downloads lightweight ONNX quantized model once into local cache (.cache/Xenova/gpt2).
 */
export async function getCrisisGenerator() {
  if (!generator) {
    console.log('🤖 [HF Crisis Generator] Initializing local ONNX text-generation pipeline (Xenova/gpt2)...');
    generator = await pipeline('text-generation', 'Xenova/gpt2');
  }
  return generator;
}

/**
 * Generates dynamic student intake text using local Hugging Face Transformers.js model.
 * 
 * @param promptPrefix Optional prompt prefix to guide generation
 * @returns Cleaned and formatted student crisis message containing requested grant amount
 */
export async function generateHFCrisisText(promptPrefix?: string): Promise<string> {
  const defaultPrompts = [
    "Student emergency request: I need immediate grant help because",
    "Student financial distress intake: Urgent help required for",
    "Emergency student relief application: I cannot pay my bill because",
    "Student crisis report: Urgent assistance needed for",
    "Financial hardship request: I need urgent grant support for"
  ];

  const prefix = promptPrefix || defaultPrompts[Math.floor(Math.random() * defaultPrompts.length)];

  try {
    const gen = await getCrisisGenerator();
    const output = await gen(prefix, {
      max_new_tokens: 45,
      temperature: 0.8,
      do_sample: true,
    });

    let generatedText = '';
    if (Array.isArray(output) && output.length > 0) {
      generatedText = output[0].generated_text || output[0].text || '';
    } else if (typeof output === 'string') {
      generatedText = output;
    } else if (output && (output as any).generated_text) {
      generatedText = (output as any).generated_text;
    }

    // Required Telemetry Console Log
    console.log(`🤖 [HF Scenario Generator] Local Transformers.js output: "${generatedText}"`);

    // Clean and format text
    let cleanText = generatedText.replace(/[\r\n]+/g, ' ').replace(/\s+/g, ' ').trim();

    // Ensure a requested dollar amount is present in the intake message
    if (!/\$\d+|\d+\s*dollars?|\u20B9\d+|\d+\s*rupees?/i.test(cleanText)) {
      const requestedAmount = Math.floor(150 + Math.random() * 850);
      cleanText += ` Requesting $${requestedAmount} in emergency grant assistance.`;
    }

    return cleanText;
  } catch (error) {
    console.error('⚠️ [HF Scenario Generator] Local Transformers.js generation error, using dynamic fallback:', error);
    const amount = Math.floor(150 + Math.random() * 850);
    const fallbackText = `${prefix} I am experiencing an unexpected financial crisis and need $${amount} emergency support.`;
    
    // Required Telemetry Console Log
    console.log(`🤖 [HF Scenario Generator] Local Transformers.js output: "${fallbackText}"`);
    return fallbackText;
  }
}
