import { Server as HttpServer } from 'http';
import { Server } from 'socket.io';

let io: Server | null = null;

export function initializeSocket(httpServer: HttpServer): Server {
  io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST']
    },
    transports: ['websocket'],
    pingTimeout: 60000,
    pingInterval: 25000
  });

  io.on('connection', (socket) => {
    console.log(`🔌 [Socket.io] Client connected: ${socket.id}`);
    
    socket.on('disconnect', () => {
      console.log(`🔌 [Socket.io] Client disconnected: ${socket.id}`);
    });

    socket.on('join_admin', (data?: { institutionId?: string }) => {
      const instId = data?.institutionId || 'default';
      socket.join('admin');
      socket.join(instId);
      socket.join(`institution:${instId}`);
      console.log(`🩺 [Socket.io] Client joined War Room admin channel for institution: ${instId}`);
    });

    socket.on('join_institution', (institutionId: string) => {
      const instId = institutionId || 'default';
      socket.join(instId);
      socket.join(`institution:${instId}`);
    });

    socket.on('join_claim', (claimId: string) => {
      socket.join(`claim:${claimId}`);
      socket.join(`ticket:${claimId}`);
    });

    socket.on('join_ticket', (ticketId: string) => {
      socket.join(`ticket:${ticketId}`);
      socket.join(`claim:${ticketId}`);
    });

    socket.on('telemetry:request_initial', async (data?: { institutionId?: string }) => {
      const instId = data?.institutionId || 'default';
      try {
        const { supabase } = await import('../config/supabase.js');
        
        // Fetch active claims
        let claimsList: any[] = [];
        const { data: claims } = await supabase
          .from('claims')
          .select('id, created_at, status, clinical_category, approved_amount, recommended_copay_amount, crisis_severity_index, fraud_risk_score, esi_level')
          .eq('institution_id', instId);

        if (claims && claims.length > 0) {
          claimsList = claims;
        } else {
          const { data: tickets } = await supabase
            .from('tickets')
            .select('id, created_at, resolved_at, status, parsed_category, calculated_amount, crisis_severity_index, anomaly_score')
            .eq('institution_id', instId);
          claimsList = tickets || [];
        }

        // Fetch health funds
        const { data: funds } = await supabase
          .from('health_funds')
          .select('total_allocated, total_disbursed')
          .eq('institution_id', instId);

        let totalAllocated = 80000;
        let totalDisbursed = 0;

        if (funds && funds.length > 0) {
          totalAllocated = funds.reduce((acc, f) => acc + Number(f.total_allocated || 0), 0);
          totalDisbursed = funds.reduce((acc, f) => acc + Number(f.total_disbursed || 0), 0);
        } else {
          for (const c of claimsList) {
            if (c.status === 'Disbursed' || c.status === 'Auto-Approved' || c.status === 'Approved') {
              totalDisbursed += Number(c.approved_amount || c.calculated_amount || c.recommended_copay_amount || 0);
            }
          }
        }

        let fraudCount = 0;
        let totalSeverity = 0;
        let autoApprovedCount = 0;

        for (const c of claimsList) {
          if (c.status === 'Disbursed' || c.status === 'Auto-Approved') autoApprovedCount++;
          if (c.status === 'Flagged' || (c.fraud_risk_score && Number(c.fraud_risk_score) > 0.65)) fraudCount++;
          if (c.crisis_severity_index) totalSeverity += Number(c.crisis_severity_index);
        }

        const totalClaims = claimsList.length || 1;
        const avgSeverity = totalSeverity / totalClaims;
        const autoApprovalAcc = autoApprovedCount / totalClaims;

        socket.emit('telemetry:update', {
          avg_resolution_time_min: 12.4,
          auto_approval_accuracy: Math.round(autoApprovalAcc * 100) / 100 || 0.92,
          fraud_spike_count: fraudCount,
          avg_crisis_severity: Math.round(avgSeverity * 100) / 100 || 0.58,
          financial_aid_remaining: Math.max(0, totalAllocated - totalDisbursed),
          alumniFundRemaining: 35000.0,
          financial_aid_disbursed: totalDisbursed,
          alumni_fund_disbursed: 0.0,
          estimated_days_financial_aid: 48,
          estimated_days_alumni_fund: 65,
          crisis_trend: [
            { hour: 0, ticket_count: 2, avg_severity: 0.7 },
            { hour: 4, ticket_count: 5, avg_severity: 0.85 },
            { hour: 8, ticket_count: 14, avg_severity: 0.6 },
            { hour: 12, ticket_count: 22, avg_severity: 0.52 },
            { hour: 16, ticket_count: 18, avg_severity: 0.68 },
            { hour: 20, ticket_count: 9, avg_severity: 0.74 }
          ]
        });
      } catch (err) {
        console.error('[SocketManager] Error handling telemetry:request_initial:', err);
      }
    });
  });

  return io;
}

export function getIO(): Server {
  if (!io) {
    throw new Error('Socket.io has not been initialized. Please call initializeSocket first.');
  }
  return io;
}
