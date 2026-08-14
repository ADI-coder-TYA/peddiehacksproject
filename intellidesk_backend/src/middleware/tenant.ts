import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from './authMiddleware.js';

export function tenantScopeMiddleware(req: Request, res: Response, next: NextFunction) {
  const authReq = req as AuthenticatedRequest;
  const headerInstitutionId = req.header('x-institution-id');

  // Derive institution_id from authenticated user or request header
  const effectiveInstitutionId = authReq.user?.institutionId || headerInstitutionId;

  if (!effectiveInstitutionId) {
    res.status(400).json({ error: 'Missing x-institution-id header or invalid tenant context.' });
    return;
  }

  // Inject into request object for downstream database queries
  req.institution_id = effectiveInstitutionId;
  next();
}
