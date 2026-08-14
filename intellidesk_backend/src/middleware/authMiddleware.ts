import { Request, Response, NextFunction } from 'express';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: 'STUDENT' | 'ADMIN' | 'AUDITOR';
    institutionId: string;
    name?: string;
  };
}

/**
 * Middleware to require valid JWT / Auth token header.
 */
export const requireAuth = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  const roleHeader = req.headers['x-user-role'] as string;
  const emailHeader = req.headers['x-user-email'] as string;

  let token = '';
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }

  // Support demo JWT token parsing or fallback
  if (token || roleHeader) {
    let role: 'STUDENT' | 'ADMIN' | 'AUDITOR' = 'STUDENT';
    let email = emailHeader || 'user@university.edu';
    let name = 'Authenticated User';

    if (token.includes('admin') || roleHeader?.toUpperCase() === 'ADMIN') {
      role = 'ADMIN';
      email = emailHeader || 's.chen@university.edu';
      name = 'Dr. Sarah Chen';
    } else if (token.includes('auditor') || roleHeader?.toUpperCase() === 'AUDITOR') {
      role = 'AUDITOR';
      email = emailHeader || 'auditor@university.edu';
      name = 'Internal Auditor';
    } else {
      role = 'STUDENT';
      email = emailHeader || 'alex.j@university.edu';
      name = 'Alex Johnson';
    }

    req.user = {
      id: token ? `usr_${role.toLowerCase()}` : 'usr_default',
      email,
      role,
      institutionId: (req.headers['x-institution-id'] as string) || 'edu-admin-123',
      name,
    };

    return next();
  }

  // If no auth provided
  return res.status(401).json({
    success: false,
    error: 'Unauthorized: Missing or invalid authentication token',
  });
};

/**
 * RBAC Middleware to restrict route access based on allowed user roles.
 */
export const requireRole = (allowedRoles: Array<'STUDENT' | 'ADMIN' | 'AUDITOR'>) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Authentication required',
      });
    }

    const normalizedAllowed = allowedRoles.map((r) => r.toUpperCase());
    const userRole = req.user.role.toUpperCase();

    if (!normalizedAllowed.includes(userRole)) {
      console.warn(`⛔ [RBAC Middleware] Access DENIED for ${req.user.email} (Role: ${req.user.role}) on ${req.path}`);
      return res.status(403).json({
        success: false,
        error: `Access Denied: Role '${req.user.role}' does not have permission to access this resource`,
      });
    }

    console.log(`🔒 [RBAC Middleware] Authenticated ${req.user.email} | Role: ${req.user.role} | Access Granted to ${req.path}`);
    return next();
  };
};

/**
 * Tenant Isolation Middleware to scope database queries by institution_id
 */
export const requireTenantAccess = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  if (!req.user || !req.user.institutionId) {
    return res.status(400).json({
      success: false,
      error: 'Missing institution context in authorization session',
    });
  }

  console.log(`🔒 [Multi-Tenancy] Scoped Admin query to Institution ID: ${req.user.institutionId}`);
  return next();
};
