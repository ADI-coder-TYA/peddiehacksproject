import '@tensorflow/tfjs-node';
import * as tf from '@tensorflow/tfjs';

// Feature columns (xs): word_count, urgent_keyword_count, sentiment_score, historical_ticket_count
// Label column   (ys):  dropout_risk
// LSTM input shape: [timeSteps=1, features=4]  — mocking time-series with single static step
const NUM_FEATURES = 4;
const TIME_STEPS = 1;
const CSV_PATH = 'file://./data/synthetic_tickets.csv';
const MODEL_SAVE_PATH = 'file://./models/lstm';

export class TemporalAttritionLSTM {
  private model!: tf.Sequential;

  private build(): void {
    this.model = tf.sequential();
    this.model.add(tf.layers.lstm({
      units: 32,
      returnSequences: false,
      inputShape: [TIME_STEPS, NUM_FEATURES],
      dropout: 0.2,
      recurrentDropout: 0.2,
    }));
    this.model.add(tf.layers.dense({ units: 16, activation: 'relu' }));
    this.model.add(tf.layers.dense({ units: 1,  activation: 'sigmoid' }));
    this.model.compile({
      optimizer: tf.train.adam(0.001),
      loss: 'binaryCrossentropy',
    });
  }

  async train(): Promise<void> {
    console.log('[TemporalAttritionLSTM] Building model...');
    this.build();

    console.log('[TemporalAttritionLSTM] Streaming training data from CSV...');
    const csvDataset = tf.data.csv(CSV_PATH, {
      columnConfigs: {
        crisis_severity_index: { isLabel: true },
        recommended_grant:     { isLabel: true },
        dropout_risk:          { isLabel: true },
      },
    });

    // Normalize features to [0,1] then reshape to [1, 4] for LSTM timeSteps=1
    const mappedDataset = (csvDataset as any).map(({ xs, ys }: any) => {
      const raw = Object.values(xs) as number[];
      const normalized = [raw[0] / 500, raw[1] / 10, raw[2], raw[3] / 20];
      return {
        xs: tf.expandDims(tf.tensor1d(normalized), 0), // → [1, 4]
        ys: [ys.dropout_risk as number],
      };
    }).batch(128);

    await this.model.fitDataset(mappedDataset as any, {
      epochs: 10,
      callbacks: {
        onEpochEnd: (epoch: number, logs?: tf.Logs) =>
          console.log(`[TemporalAttritionLSTM] Epoch ${epoch + 1}/10 — loss: ${logs?.loss?.toFixed(6)}`),
      },
    });

    await this.model.save(MODEL_SAVE_PATH);
    console.log(`[TemporalAttritionLSTM] ✅ Model saved to ${MODEL_SAVE_PATH}`);
  }
}
