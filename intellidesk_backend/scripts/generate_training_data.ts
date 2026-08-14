import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DATA_DIR = path.resolve(__dirname, '../data');
const TRAIN_CSV_PATH = path.join(DATA_DIR, 'train.csv');
const VAL_CSV_PATH = path.join(DATA_DIR, 'val.csv');
const TOTAL_RECORDS = 100_000;

// CSV columns:
// xs (features): word_count, urgent_keyword_count, sentiment_score, historical_ticket_count
// ys (labels):   crisis_severity_index, recommended_grant, dropout_risk

function rand(min: number, max: number): number {
  return Math.random() * (max - min) + min;
}

function generateRow(severity: 'high' | 'medium' | 'low'): string {
  let urgentKeywordCount: number;
  let sentimentScore: number;
  let wordCount: number;

  // Generate input features
  if (severity === 'high') {
    urgentKeywordCount = Math.round(rand(4, 10));
    sentimentScore     = rand(-1.00, -0.60); // High distress, very negative
    wordCount          = Math.round(rand(150, 500));
  } else if (severity === 'medium') {
    urgentKeywordCount = Math.round(rand(1, 4));
    sentimentScore     = rand(-0.60, 0.10);
    wordCount          = Math.round(rand(80, 200));
  } else {
    urgentKeywordCount = Math.round(rand(0, 2));
    sentimentScore     = rand(0.10, 1.00); // Low distress, positive
    wordCount          = Math.round(rand(30, 100));
  }

  const historicalTicketCount = Math.round(rand(0, 20));

  // Normalize inputs for calculation
  const normKeywords = Math.min(urgentKeywordCount / 5, 1.0); 
  const normSentiment = (sentimentScore + 1.0) / 2.0; // -1.0 becomes 0.0 (high distress)
  const normWordCount = Math.min(wordCount / 100, 1.0);
  
  // Mathematical correlation: Keywords and Sentiment drive the CSI
  // normSentiment is close to 0.0 for high distress, so we invert it for CSI:
  const distressSentiment = 1.0 - normSentiment;
  let crisisSeverityIndex = (normKeywords * 0.45) + (distressSentiment * 0.45) + (Math.random() * 0.1);
  
  // Inject realistic variance (-0.15 to +0.15)
  const realWorldNoise = (Math.random() * 0.3) - 0.15; 
  crisisSeverityIndex += realWorldNoise;
  
  crisisSeverityIndex = Math.min(Math.max(crisisSeverityIndex, 0.0), 1.0); // Clamp between 0 and 1
  
  // Grant amount strictly scales with CSI
  const recommendedGrant = Math.floor(crisisSeverityIndex * 1000);
  
  // Dropout risk is also correlated
  const dropoutRisk = Math.min(Math.max(crisisSeverityIndex + rand(-0.1, 0.1), 0.0), 1.0);

  return (
    `${normWordCount.toFixed(4)},${normKeywords.toFixed(4)},${normSentiment.toFixed(4)},` +
    `${historicalTicketCount},${crisisSeverityIndex.toFixed(4)},` +
    `${recommendedGrant.toFixed(2)},${dropoutRisk.toFixed(4)}\n`
  );
}

async function waitForDrain(stream: fs.WriteStream): Promise<void> {
  return new Promise(resolve => stream.once('drain', resolve));
}

async function main(): Promise<void> {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }

  const trainStream = fs.createWriteStream(TRAIN_CSV_PATH, { encoding: 'utf8' });
  const valStream = fs.createWriteStream(VAL_CSV_PATH, { encoding: 'utf8' });
  const header =
    'word_count,urgent_keyword_count,sentiment_score,historical_ticket_count,' +
    'crisis_severity_index,recommended_grant,dropout_risk\n';

  if (!trainStream.write(header)) await waitForDrain(trainStream);
  if (!valStream.write(header)) await waitForDrain(valStream);

  console.log(`[DataGenerator] Writing ${TOTAL_RECORDS.toLocaleString()} records to train/val streams\n`);

  let trainCount = 0;
  let valCount = 0;

  // Probabilistic distribution: 30% High, 40% Medium, 30% Low
  for (let i = 0; i < TOTAL_RECORDS; i++) {
    const roll = Math.random();
    const severity = roll < 0.30 ? 'high' : roll < 0.70 ? 'medium' : 'low';
    const row = generateRow(severity);

    let canContinue;
    if (Math.random() < 0.8) {
      canContinue = trainStream.write(row);
      trainCount++;
      if (!canContinue) await waitForDrain(trainStream);
    } else {
      canContinue = valStream.write(row);
      valCount++;
      if (!canContinue) await waitForDrain(valStream);
    }

    if ((i + 1) % 10_000 === 0) {
      console.log(`[DataGenerator]   ${(i + 1).toLocaleString()} / ${TOTAL_RECORDS.toLocaleString()} records written...`);
    }
  }

  await Promise.all([
    new Promise<void>((resolve, reject) => {
      trainStream.end(resolve);
      trainStream.once('error', reject);
    }),
    new Promise<void>((resolve, reject) => {
      valStream.end(resolve);
      valStream.once('error', reject);
    })
  ]);

  console.log('\n[DataGenerator] ✅ CSV generation complete!');
  console.log(`[DataGenerator]    Train: ${trainCount} records -> ${TRAIN_CSV_PATH}`);
  console.log(`[DataGenerator]    Val:   ${valCount} records -> ${VAL_CSV_PATH}`);
}

main().catch(err => {
  console.error('[DataGenerator] ❌ Fatal error:', err);
  process.exit(1);
});
