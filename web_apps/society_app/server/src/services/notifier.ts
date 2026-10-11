/**
 * Outbound messaging boundary (SMS / WhatsApp / push). ConsoleNotifier only logs; plug in
 * MSG91, Twilio, the WhatsApp Business API or FCM by implementing this interface.
 */
export interface Notifier {
  sendOtp(phone: string, code: string): Promise<void>;
  sendDuesReminder(flatId: string, amount: number): Promise<void>;
  broadcastNotice(title: string, flats: number): Promise<void>;
  sosAlert(flatId: string | null, type: string): Promise<void>;
  visitorAtGate(flatId: string, visitor: string): Promise<void>;
}

export class ConsoleNotifier implements Notifier {
  private log(...a: unknown[]) { console.log('[notify]', ...a); }
  async sendOtp(phone: string, code: string) { this.log(`OTP for ${phone}: ${code}`); }
  async sendDuesReminder(flatId: string, amount: number) { this.log(`WhatsApp + SMS dues reminder → ${flatId} (₹${amount})`); }
  async broadcastNotice(title: string, flats: number) { this.log(`Notice "${title}" → ${flats} flats`); }
  async sosAlert(flatId: string | null, type: string) { this.log(`SOS ${type} from ${flatId ?? 'unknown'} → guards + committee`); }
  async visitorAtGate(flatId: string, visitor: string) { this.log(`Visitor ${visitor} waiting → ${flatId}`); }
}
