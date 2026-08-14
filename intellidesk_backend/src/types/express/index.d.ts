declare global {
  namespace Express {
    export interface Request {
      institution_id?: string;
    }
  }
}

export {};
