import { Worker, Job } from 'bullmq';
import { 
  redisConnection, 
  NOTIFICATION_QUEUE_NAME, 
  moveToDeadLetterQueue 
} from './queueManager.js';
import twilio from 'twilio';
import nodemailer from 'nodemailer';
import { getApps, initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { io } from 'socket.io-client';

const socket = io(process.env.WEBSOCKET_URL || 'http://localhost:3000');

// Initialize Services
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID || 'AC_dummy', 
  process.env.TWILIO_AUTH_TOKEN || 'dummy_token'
);

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.ethereal.email',
  port: parseInt(process.env.SMTP_PORT || '587'),
  auth: {
    user: process.env.SMTP_USER || 'dummy',
    pass: process.env.SMTP_PASS || 'dummy',
  },
});

// Initialize Firebase Admin (Mock config if env not set)
if (!getApps().length) {
  try {
    initializeApp({
      credential: cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      }),
    });
  } catch (e: any) {
    console.error('[NotificationWorker] Firebase Admin initialization failed:', e.message);
  }
}

export const notificationWorker = new Worker(
  NOTIFICATION_QUEUE_NAME,
  async (job: Job) => {
    const { 
      ticketId, 
      type, // 'SMS', 'PUSH', 'EMAIL', or 'ALL'
      recipientPhone, 
      recipientEmail, 
      fcmToken,
      title,
      body 
    } = job.data;
    
    console.log(`[NotificationWorker] Processing Job ${job.id} for Ticket ${ticketId}`);

    const results = {
      sms: false,
      push: false,
      email: false,
      errors: [] as string[]
    };

    // 1. Send SMS (Twilio)
    if (type === 'SMS' || type === 'ALL') {
      if (recipientPhone) {
        try {
          await twilioClient.messages.create({
            body: body,
            from: process.env.TWILIO_PHONE_NUMBER || '+15550000000',
            to: recipientPhone
          });
          results.sms = true;
          console.log(`[NotificationWorker] SMS sent to ${recipientPhone}`);
        } catch (error: any) {
          console.error(`[NotificationWorker] SMS failed: ${error.message}`);
          results.errors.push(`SMS: ${error.message}`);
        }
      } else {
         results.errors.push(`SMS: Missing recipientPhone`);
      }
    }

    // 2. Send Push Notification (Firebase Admin)
    if (type === 'PUSH' || type === 'ALL') {
      if (fcmToken) {
        try {
          await getMessaging().send({
            token: fcmToken,
            notification: { title, body },
            data: { ticketId }
          });
          results.push = true;
          console.log('✅ Push notification dispatched via FCM');
          console.log(`[NotificationWorker] Push sent to token ${fcmToken.substring(0, 8)}...`);
        } catch (error: any) {
          console.error(`[NotificationWorker] Push failed: ${error.message}`);
          results.errors.push(`PUSH: ${error.message}`);
        }
      } else {
         results.errors.push(`PUSH: Missing fcmToken`);
      }
    }

    // 3. Send Email (Nodemailer)
    if (type === 'EMAIL' || type === 'ALL') {
      if (recipientEmail) {
        try {
          await transporter.sendMail({
            from: '"EduAccess Support" <support@eduaccess.local>',
            to: recipientEmail,
            subject: title,
            text: body,
            html: `<div style="font-family: sans-serif; padding: 20px;"><h2>${title}</h2><p>${body}</p></div>`,
          });
          results.email = true;
          console.log(`[NotificationWorker] Email sent to ${recipientEmail}`);
        } catch (error: any) {
          console.error(`[NotificationWorker] Email failed: ${error.message}`);
          results.errors.push(`EMAIL: ${error.message}`);
        }
      } else {
         results.errors.push(`EMAIL: Missing recipientEmail`);
      }
    }

    if (results.errors.length > 0 && type !== 'ALL') {
       throw new Error(`Notification failed: ${results.errors.join(', ')}`);
    }

    return results;
  },
  {
    connection: redisConnection,
    concurrency: 10, // Higher concurrency for lightweight I/O tasks
  }
);

notificationWorker.on('failed', async (job: Job | undefined, error: Error) => {
  if (!job) return;
  console.error(`[NotificationWorker] Job ${job.id} failed on attempt ${job.attemptsMade}`);

  if (job.attemptsMade >= (job.opts.attempts || 3)) {
    console.error(`[NotificationWorker] Job ${job.id} exhausted all retries. Moving to DLQ.`);
    await moveToDeadLetterQueue(job, error);
    
    // Emit socket failure to the specific ticket/job room
    console.log(`[NotificationWorker] Emitting job:failed event for ${job.id}`);
    socket.emit('job:failed', {
      jobId: job.id,
      ticketId: job.data.ticketId,
      error: error.message
    });
  }
});
