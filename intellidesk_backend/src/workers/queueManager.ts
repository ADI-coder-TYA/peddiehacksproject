import { Queue, Worker, QueueEvents, Job } from 'bullmq';
import { Redis } from 'ioredis';

// Shared Redis Connection
const redisUrl = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
export const redisConnection = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
});

// Define Queue Names
export const INTAKE_QUEUE_NAME = 'intake-processing-queue';
export const NOTIFICATION_QUEUE_NAME = 'notification-dispatch-queue';
export const ML_RETRAINING_QUEUE_NAME = 'ml-retraining-queue';
export const DEAD_LETTER_QUEUE_NAME = 'dead-letter-queue';

// Instantiate Queues
export const intakeQueue = new Queue(INTAKE_QUEUE_NAME, { connection: redisConnection });
export const notificationQueue = new Queue(NOTIFICATION_QUEUE_NAME, { connection: redisConnection });
export const mlRetrainingQueue = new Queue(ML_RETRAINING_QUEUE_NAME, { connection: redisConnection });
export const deadLetterQueue = new Queue(DEAD_LETTER_QUEUE_NAME, { connection: redisConnection });

// Default Job Options (Retry Strategy)
// 3 retries with 5-second exponential backoff
export const defaultJobOptions = {
  attempts: 3,
  backoff: {
    type: 'exponential',
    delay: 5000,
  },
  removeOnComplete: true,
  removeOnFail: false, // Keep in failed set to move to DLQ manually if needed, or handle in worker
};

/**
 * Utility to move a failed job to the Dead Letter Queue
 */
export async function moveToDeadLetterQueue(job: Job, error: Error) {
  console.error(`Moving Job ${job.id} to Dead Letter Queue. Reason: ${error.message}`);
  
  await deadLetterQueue.add(
    job.name,
    {
      originalJobId: job.id,
      originalData: job.data,
      failedReason: error.message,
      stackTrace: error.stack,
      failedAt: new Date().toISOString(),
    },
    {
      attempts: 1,
      removeOnComplete: true,
      removeOnFail: false
    }
  );
}
