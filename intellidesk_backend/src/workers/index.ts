import { intakeWorker } from './intakeWorker.js';
import { notificationWorker } from './notificationWorker.js';
import { mlRetrainingWorker } from './mlRetrainingWorker.js';
import { redisConnection } from './queueManager.js';

export function startWorkers() {
  console.log('[WorkerManager] Initialized background workers for Intake, Notifications, and ML Retraining.');
}

async function gracefulShutdown(signal: string) {
  console.log(`\n[WorkerManager] Received ${signal}. Starting graceful shutdown...`);

  try {
    // Stop accepting new jobs
    console.log('[WorkerManager] Pausing queues and closing workers...');
    await Promise.all([
      intakeWorker.close(),
      notificationWorker.close(),
      mlRetrainingWorker.close()
    ]);
    
    // Close Redis connection
    console.log('[WorkerManager] Closing Redis connection...');
    redisConnection.quit();

    console.log('[WorkerManager] Graceful shutdown complete. Exiting process.');
    process.exit(0);
  } catch (error) {
    console.error('[WorkerManager] Error during graceful shutdown:', error);
    process.exit(1);
  }
}

// Wire process signal listeners
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
