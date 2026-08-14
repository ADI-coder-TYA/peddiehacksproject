import '@tensorflow/tfjs-node';
import * as tf from '@tensorflow/tfjs';

// Feature columns (xs): word_count, urgent_keyword_count, sentiment_score, historical_ticket_count
// Autoencoder trains to reconstruct its own input → xs === ys
const NUM_FEATURES = 4;
const CSV_PATH = 'file://./data/synthetic_tickets.csv';
const MODEL_SAVE_PATH = 'file://./models/autoencoder';

export class AnomalyAutoencoder {
  private model!: tf.Sequential;

  private build(): void {
    this.model = tf.sequential();
    // Encoder
    this.model.add(tf.layers.dense({ units: 16, activation: 'relu', inputShape: [NUM_FEATURES] }));
    // Bottleneck / latent space
    this.model.add(tf.layers.dense({ units: 4,  activation: 'relu' }));
    // Decoder
    this.model.add(tf.layers.dense({ units: 16, activation: 'relu' }));
    // Reconstruction — output dim must match input dim
    this.model.add(tf.layers.dense({ units: NUM_FEATURES, activation: 'sigmoid' }));
    this.model.compile({
      optimizer: tf.train.adam(0.001),
      loss: 'meanSquaredError',
    });
  }

  async train(): Promise<void> {
    console.log('[AnomalyAutoencoder] Building model...');
    this.build();

    console.log('[AnomalyAutoencoder] Streaming training data from CSV...');
    const csvDataset = tf.data.csv(CSV_PATH, {
      columnConfigs: {
        crisis_severity_index: { isLabel: true },
        recommended_grant:     { isLabel: true },
        dropout_risk:          { isLabel: true },
      },
    });

    // Normalize all features to [0,1] to match the inference input range
    // (routes already send normalized values, so training must match)
    //   raw[0] = word_count          → ÷500
    //   raw[1] = urgent_keyword_count → ÷10
    //   raw[2] = sentiment_score      → already [0,1]
    //   raw[3] = historical_ticket_count → ÷20
    const mappedDataset = (csvDataset as any).map(({ xs }: any) => {
      const raw = Object.values(xs) as number[];
      const features = [raw[0] / 500, raw[1] / 10, raw[2], raw[3] / 20];
      return { xs: features, ys: features };
    }).batch(128);

    await this.model.fitDataset(mappedDataset as any, {
      epochs: 10,
      callbacks: {
        onEpochEnd: (epoch: number, logs?: tf.Logs) =>
          console.log(`[AnomalyAutoencoder] Epoch ${epoch + 1}/10 — loss: ${logs?.loss?.toFixed(6)}`),
      },
    });

    await this.model.save(MODEL_SAVE_PATH);
    console.log(`[AnomalyAutoencoder] ✅ Model saved to ${MODEL_SAVE_PATH}`);
  }
}
