import { Router } from 'express';
import { ClaimsController } from '../controllers/claimsController.js';
import { ChatController } from '../controllers/chatController.js';

const router = Router();

// GET /api/v1/claims (Filter by ESI level, status, search, and priority sorting)
router.get('/', ClaimsController.getClaims);

// GET /api/v1/claims/:id
router.get('/:id', ClaimsController.getClaimById);

// POST /api/v1/claims/:id/disburse (Instant multi-rail copay disbursement)
router.post('/:id/disburse', ClaimsController.disburseClaim);

// POST /api/v1/claims/:id/override (Admin ESI / Fraud override)
router.post('/:id/override', ClaimsController.overrideClaim);

// POST /api/v1/claims/:id/messages (Multi-turn PFA counselor chat)
router.post('/:id/messages', ChatController.sendClaimMessage);

// GET /api/v1/claims/:id/messages (Fetch chat message history)
router.get('/:id/messages', ChatController.getClaimMessages);

export default router;
