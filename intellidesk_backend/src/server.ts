import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import http from 'http';
import { initializeSocket } from './services/socketManager.js';
import asyncIntakeRouter from './routes/asyncIntake.js';
import chatRouter from './routes/chat.js';
import adminRouter from './routes/admin.js';
import knowledgeRouter from './routes/knowledge.js';
import workflowDispatchRouter from './routes/workflow_dispatch.js';
import telemetryRouter from './routes/telemetry.js';
import reportsRouter from './routes/reports.js';
import simulationRouter from './routes/simulation.js';
import { tenantScopeMiddleware } from './middleware/tenant.js';
import { loadOrTrainLSTMModel } from './services/attritionModel.js';
import { loadOrTrainGrantOptimizerModel } from './services/grantOptimizerModel.js';
import { loadOrTrainDeepRankModel } from './services/deepRankModel.js';
import { loadOrTrainAnomalyModel } from './services/anomalyModel.js';
import { startWorkers } from './workers/index.js';

import { ensureStorageBucketsExist } from './services/storageBootstrap.js';

import authRouter from './routes/auth.js';
import { requireAuth, requireRole } from './middleware/authMiddleware.js';

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const server = http.createServer(app);

initializeSocket(server);

app.use('/api/v1/auth', authRouter);
app.use('/api/v1/chat', chatRouter);
app.use('/api/v1/intake', asyncIntakeRouter);
app.use('/api/v1/admin/knowledge', requireAuth, requireRole(['ADMIN']), tenantScopeMiddleware, knowledgeRouter);
app.use('/api/v1/admin/telemetry', requireAuth, requireRole(['ADMIN']), tenantScopeMiddleware, telemetryRouter);
app.use('/api/v1/admin/reports', requireAuth, requireRole(['ADMIN']), tenantScopeMiddleware, reportsRouter);
app.use('/api/v1/admin', requireAuth, requireRole(['ADMIN']), tenantScopeMiddleware, adminRouter);
app.use('/api/v1/reports', requireAuth, requireRole(['ADMIN']), tenantScopeMiddleware, reportsRouter);
app.use('/api/v1/workflow', requireAuth, requireRole(['ADMIN']), tenantScopeMiddleware, workflowDispatchRouter);
app.use('/api/v1/simulation', requireAuth, requireRole(['ADMIN']), tenantScopeMiddleware, simulationRouter);

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;

async function bootstrapServer() {
  // 1. Ensure storage buckets exist
  await ensureStorageBucketsExist();

  // 2. Load ML Models
  try {
    await Promise.all([
      loadOrTrainLSTMModel(),
      loadOrTrainGrantOptimizerModel(),
      loadOrTrainDeepRankModel(),
      loadOrTrainAnomalyModel()
    ]);
  } catch (err) {
    console.error('Failed to initialize ML models on startup:', err);
  }

  // 3. Start HTTP server and background workers
  server.listen(PORT as number, '0.0.0.0', () => {
    console.log(`🏥 [MedAccess AI] Clinical Triage & Emergency Copay Engine running on port ${PORT}`);
    startWorkers();
  });
}

bootstrapServer();
