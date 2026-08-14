import '@tensorflow/tfjs-node';
import * as tf from '@tensorflow/tfjs';

// Feature columns (xs): word_count, urgent_keyword_count, sentiment_score, historical_ticket_count
// Label column   (ys):  crisis_severity_index
const NUM_FEATURES = 4;
const TRAIN_CSV_PATH = 'file://./data/train.csv';
const VAL_CSV_PATH = 'file://./data/val.csv';
const MODEL_SAVE_PATH = 'file://./models/deep_rank';

export class DeepRankModel {
  private model!: tf.Sequential;

  private build(): void {
    this.model = tf.sequential();
    this.model.add(tf.layers.dense({ units: 64, activation: 'relu', inputShape: [NUM_FEATURES], kernelRegularizer: tf.regularizers.l2({ l2: 0.001 }) }));
    this.model.add(tf.layers.batchNormalization());
    this.model.add(tf.layers.dropout({ rate: 0.2 }));
    this.model.add(tf.layers.dense({ units: 32, activation: 'relu', kernelRegularizer: tf.regularizers.l2({ l2: 0.001 }) }));
    this.model.add(tf.layers.batchNormalization());
    this.model.add(tf.layers.dropout({ rate: 0.2 }));
    this.model.add(tf.layers.dense({ units: 16, activation: 'relu' }));
    this.model.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
    this.model.compile({
      optimizer: tf.train.adam(0.0005), // Lower learning rate
      loss: 'meanSquaredError',
      metrics: ['mse']
    });
  }

  async train(): Promise<void> {
    console.log('[DeepRank] Building model...');
    this.build();

    console.log('[DeepRank] Streaming training data from CSV...');
    const csvDataset = tf.data.csv(TRAIN_CSV_PATH, {
      columnConfigs: {
        crisis_severity_index: { isLabel: true },
        recommended_grant:     { isLabel: true },
        dropout_risk:          { isLabel: true },
      },
    });

    const valCsvDataset = tf.data.csv(VAL_CSV_PATH, {
      columnConfigs: {
        crisis_severity_index: { isLabel: true },
        recommended_grant:     { isLabel: true },
        dropout_risk:          { isLabel: true },
      },
    });

    // Features are already normalized in CSV except historical_ticket_count
    const mapFn = ({ xs, ys }: any) => {
      const raw = Object.values(xs) as number[];
      return {
        xs: [raw[0], raw[1], raw[2], raw[3] / 20],
        ys: [ys.crisis_severity_index as number],
      };
    };
    
    const mappedDataset = (csvDataset as any).map(mapFn).batch(128);
    const valDataset = (valCsvDataset as any).map(mapFn).batch(128);

    let bestLoss = Infinity;
    let wait = 0;
    const patience = 3;

    await this.model.fitDataset(mappedDataset as any, {
      epochs: 30,
      validationData: valDataset as any,
      callbacks: [
        {
          onEpochEnd: (epoch: number, logs?: tf.Logs) => {
            const currentLoss = logs?.val_loss;
            console.log(`[DeepRank] Epoch ${epoch + 1}/30 — loss: ${logs?.loss?.toFixed(6)} — val_loss: ${currentLoss?.toFixed(6)}`);
            
            // Custom Early Stopping Logic
            if (currentLoss !== undefined) {
              if (currentLoss < bestLoss) {
                bestLoss = currentLoss;
                wait = 0;
              } else {
                wait++;
                if (wait >= patience) {
                  console.log(`[DeepRank] 🛑 Early stopping triggered at epoch ${epoch + 1}`);
                  this.model.stopTraining = true;
                }
              }
            }
          }
        }
      ],
    });

    await this.model.save(MODEL_SAVE_PATH);
    console.log(`[DeepRank] ✅ Model saved to ${MODEL_SAVE_PATH}`);
  }
}
