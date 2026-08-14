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
    console.log(`Socket connected: ${socket.id}`);
    
    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
    });

    socket.on('join_admin', (data?: { institutionId?: string }) => {
      const instId = data?.institutionId || 'edu-admin-123';
      console.log(`Socket ${socket.id} joined admin room & institution room: institution:${instId}`);
      socket.join('admin');
      socket.join(`institution:${instId}`);
    });

    socket.on('join_institution', (institutionId: string) => {
      console.log(`Socket ${socket.id} joined institution room: institution:${institutionId}`);
      socket.join(`institution:${institutionId}`);
    });

    socket.on('telemetry:request_initial', async (data?: { institutionId?: string }) => {
      const instId = data?.institutionId || 'edu-admin-123';
      try {
        const { supabase } = await import('../config/supabase.js');
        const { data: tickets } = await supabase
          .from('tickets')
          .select('id, created_at, resolved_at, status, parsed_category, calculated_amount, crisis_severity_index, anomaly_score')
          .eq('institution_id', instId);

        let totalDisbursed = 0;
        let totalResolutionTimeMs = 0;
        let resolvedCount = 0;
        let autoApprovedCount = 0;
        let fraudCount = 0;
        let totalSeverity = 0;

        for (const t of tickets || []) {
          if (t.status === 'Auto-Approved' || t.status === 'Approved' || t.status === 'Resolved') {
            totalDisbursed += Number(t.calculated_amount) || 0;
          }
          if (t.status === 'Auto-Approved') {
            autoApprovedCount++;
          }
          if (t.anomaly_score && Number(t.anomaly_score) > 0.7) {
            fraudCount++;
          }
          if (t.crisis_severity_index) {
            totalSeverity += Number(t.crisis_severity_index);
          }
          if (t.resolved_at && t.created_at) {
            const created = new Date(t.created_at).getTime();
            const resolved = new Date(t.resolved_at).getTime();
            totalResolutionTimeMs += (resolved - created);
            resolvedCount++;
          }
        }

        const totalTickets = (tickets || []).length;
        const avgResMin = resolvedCount > 0 ? (totalResolutionTimeMs / (resolvedCount * 60000)) : 14.5;
        const autoApprovalAcc = totalTickets > 0 ? (autoApprovedCount / totalTickets) : 0.88;
        const avgSeverity = totalTickets > 0 ? (totalSeverity / totalTickets) : 0.65;

        socket.emit('telemetry:update', {
          avg_resolution_time_min: Math.round(avgResMin * 10) / 10,
          auto_approval_accuracy: Math.round(autoApprovalAcc * 100) / 100,
          fraud_spike_count: fraudCount,
          avg_crisis_severity: Math.round(avgSeverity * 100) / 100,
          financial_aid_remaining: Math.max(0, 50000 - totalDisbursed),
          alumniFundRemaining: 25000.0,
          financial_aid_disbursed: totalDisbursed,
          alumni_fund_disbursed: 0.0,
          estimated_days_financial_aid: 45,
          estimated_days_alumni_fund: 60,
          crisis_trend: [
            { hour: 0, ticket_count: 2, avg_severity: 0.7 },
            { hour: 4, ticket_count: 5, avg_severity: 0.85 },
            { hour: 8, ticket_count: 12, avg_severity: 0.6 },
            { hour: 12, ticket_count: 18, avg_severity: 0.5 },
            { hour: 16, ticket_count: 14, avg_severity: 0.65 },
            { hour: 20, ticket_count: 8, avg_severity: 0.75 }
          ]
        });
      } catch (err) {
        console.error('[SocketManager] Error handling telemetry:request_initial:', err);
      }
    });

    socket.on('join_ticket', (ticketId: string) => {
      console.log(`Socket ${socket.id} joined ticket room ${ticketId}`);
      socket.join(`ticket:${ticketId}`);
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
