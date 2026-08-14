import 'dotenv/config';
import { transcribeLocalAudio } from '../src/services/localVoiceService.js';

/**
 * Generate a minimal valid 16kHz 16-bit Mono PCM WAV buffer
 */
function createDummyWavBuffer(): Buffer {
  const sampleRate = 16000;
  const numChannels = 1;
  const bitsPerSample = 16;
  const durationSeconds = 1;
  const numSamples = sampleRate * durationSeconds;
  const dataSize = numSamples * numChannels * (bitsPerSample / 8);
  const buffer = Buffer.alloc(44 + dataSize);

  // RIFF header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);

  // fmt chunk
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // Subchunk1Size
  buffer.writeUInt16LE(1, 20);  // AudioFormat (PCM)
  buffer.writeUInt16LE(numChannels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * numChannels * (bitsPerSample / 8), 28);
  buffer.writeUInt16LE(numChannels * (bitsPerSample / 8), 32);
  buffer.writeUInt16LE(bitsPerSample, 34);

  // data chunk
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);

  // Fill sine wave audio samples (440Hz tone)
  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    const sample = Math.sin(2 * Math.PI * 440 * t) * 32767;
    buffer.writeInt16LE(Math.round(sample), 44 + i * 2);
  }

  return buffer;
}

async function testLocalVoiceIntake() {
  console.log('🧪 Testing Local Whisper Voice Intake Offline Pipeline...\n');

  const wavBuffer = createDummyWavBuffer();
  console.log(`🎙️ Created test 16kHz PCM WAV buffer (${wavBuffer.length} bytes)`);

  const transcript = await transcribeLocalAudio(wavBuffer);

  console.log(`\n✅ Local Whisper Output: "${transcript}"`);
  if (!transcript || transcript.length === 0) {
    throw new Error('Local Voice Intake returned empty transcript.');
  }

  console.log('\n🎉 Local Voice Intake test passed successfully!');
}

testLocalVoiceIntake().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
