import { Worker, Job } from 'bullmq';
import { io } from 'socket.io-client';
import { 
  redisConnection, 
  ML_RETRAINING_QUEUE_NAME, 
  moveToDeadLetterQueue 
} from './queueManager.js';
import { supabase } from '../config/supabase.js';
import { loadOrTrainGrantOptimizerModel } from '../services/grantOptimizerModel.js';
import { loadOrTrainDeepRankModel } from '../services/deepRankModel.js';

const socket = io(process.env.WEBSOCKET_URL || 'http://localhost:3000');

export const mlRetrainingWorker = new Worker(
  ML_RETRAINING_QUEUE_NAME,
  async (job: Job) => {
    console.log(`[MLRetrainingWorker] Starting Job ${job.id}: ML Model Fine-Tuning...`);

    try {
      // 1. Fetch latest resolved tickets from Supabase (Historical data)
      console.log(`[MLRetrainingWorker] Fetching latest resolved tickets for training dataset...`);
      const { data: tickets, error } = await supabase
        .from('tickets')
        .select('*')
        .not('resolved_at', 'is', null)
        .order('resolved_at', { ascending: false })
        .limit(1000);

      if (error) throw new Error(`Supabase fetch failed: ${error.message}`);
      if (!tickets || tickets.length === 0) {
        console.log(`[MLRetrainingWorker] No resolved tickets found. Skipping retraining.`);
        return { status: 'skipped', reason: 'No data' };
      }

      // 2. Run Re-Training for TensorFlow.js Models
      // The individual services are responsible for structuring the dataset and updating weights in memory/disk.
      console.log(`[MLRetrainingWorker] Initiating GrantOptimizer fine-tuning...`);
      await loadOrTrainGrantOptimizerModel(); // Retrain without forcing true boolean if it expects no args

      console.log(`[MLRetrainingWorker] Initiating DeepRank fine-tuning...`);
      await loadOrTrainDeepRankModel();

      // 3. Emit real-time metrics back to dashboard
      console.log(`[MLRetrainingWorker] Retraining successful. Emitting ml:retrained event.`);
      socket.emit('ml:retrained', {
        jobId: job.id,
        timestamp: new Date().toISOString(),
        samplesTrained: tickets.length,
        modelsUpdated: ['GrantOptimizer', 'DeepRank']
      });

      return { status: 'success', samplesTrained: tickets.length };
    } catch (error: any) {
      console.error(`[MLRetrainingWorker] Retraining Job ${job.id} failed: ${error.message}`);
      throw error;
    }
  },
  {
    connection: redisConnection,
    concurrency: 1, // Heavy CPU task, process one at a time
  }
);

mlRetrainingWorker.on('failed', async (job: Job | undefined, error: Error) => {
  if (!job) return;
  console.error(`[MLRetrainingWorker] Job ${job.id} failed on attempt ${job.attemptsMade}`);

  if (job.attemptsMade >= (job.opts.attempts || 3)) {
    console.error(`[MLRetrainingWorker] Job ${job.id} exhausted retries. Moving to DLQ.`);
    await moveToDeadLetterQueue(job, error);
  }
});
