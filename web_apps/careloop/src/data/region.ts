export type Region = 'IN' | 'US';

export interface PayMethod {
  id: string;
  label: string;
  sub: string;
  icon: string;
}

export const REGIONS: Record<Region, {
  name: string;
  currency: string;
  locale: string;
  phonePrefix: string;
  samplePhone: string;
  pay: PayMethod[];
  /** Patient-side convenience fee per consult (platform revenue). */
  bookingFee: number;
  /** Lab home-collection and medicine delivery fees, waived for Plus members. */
  homeCollection: number;
  delivery: number;
  plus: { monthly: number; yearly: number };
  /** Doctor plans: monthly price and platform commission on each consult. */
  doctorPlans: { id: 'starter' | 'pro' | 'clinic'; name: string; price: number; commission: number; perks: string[] }[];
  emergency: string;
  compliance: string;
}> = {
  IN: {
    name: 'India',
    currency: 'INR',
    locale: 'en-IN',
    phonePrefix: '+91',
    samplePhone: '98250 12345',
    pay: [
      { id: 'upi', label: 'UPI', sub: 'Google Pay, PhonePe, Paytm', icon: 'Smartphone' },
      { id: 'card', label: 'Credit / debit card', sub: 'Visa, Mastercard, RuPay', icon: 'CreditCard' },
      { id: 'netbanking', label: 'Net banking', sub: 'All major banks', icon: 'Landmark' },
      { id: 'wallet', label: 'CareLoop wallet', sub: 'Balance ₹250', icon: 'Wallet' },
    ],
    bookingFee: 29,
    homeCollection: 99,
    delivery: 49,
    plus: { monthly: 299, yearly: 1999 },
    doctorPlans: [
      { id: 'starter', name: 'Starter', price: 0, commission: 0.2, perks: ['Listed in search', 'Video and clinic bookings', 'Basic e-prescriptions'] },
      { id: 'pro', name: 'Pro', price: 1999, commission: 0.1, perks: ['Half the commission', 'Priority in search results', 'Prescription templates', 'Earnings analytics'] },
      { id: 'clinic', name: 'Clinic', price: 4999, commission: 0.08, perks: ['Up to 5 doctors', 'Front-desk login', 'Clinic page and reviews', 'Dedicated account manager'] },
    ],
    emergency: '112',
    compliance: 'Follows the Telemedicine Practice Guidelines 2020 and DPDP Act 2023',
  },
  US: {
    name: 'United States',
    currency: 'USD',
    locale: 'en-US',
    phonePrefix: '+1',
    samplePhone: '(415) 555-0132',
    pay: [
      { id: 'insurance', label: 'Insurance', sub: 'Aetna, Cigna, UnitedHealthcare, BCBS', icon: 'ShieldCheck' },
      { id: 'card', label: 'Credit / debit card', sub: 'Visa, Mastercard, Amex', icon: 'CreditCard' },
      { id: 'gpay', label: 'Google Pay', sub: 'Fast checkout', icon: 'Smartphone' },
      { id: 'hsa', label: 'HSA / FSA card', sub: 'Pre-tax health dollars', icon: 'Wallet' },
    ],
    bookingFee: 3,
    homeCollection: 15,
    delivery: 5,
    plus: { monthly: 14.99, yearly: 119 },
    doctorPlans: [
      { id: 'starter', name: 'Starter', price: 0, commission: 0.2, perks: ['Listed in search', 'Video and in-person bookings', 'Basic e-prescriptions'] },
      { id: 'pro', name: 'Pro', price: 49, commission: 0.1, perks: ['Half the commission', 'Priority in search results', 'Prescription templates', 'Earnings analytics'] },
      { id: 'clinic', name: 'Practice', price: 149, commission: 0.08, perks: ['Up to 5 providers', 'Front-desk login', 'Practice page and reviews', 'Dedicated account manager'] },
    ],
    emergency: '911',
    compliance: 'HIPAA-ready: encrypted visits and records, BAA available',
  },
};

export function money(region: Region, amount: number, opts: { decimals?: boolean } = {}) {
  const r = REGIONS[region];
  const decimals = opts.decimals ?? (region === 'US' && amount % 1 !== 0);
  return new Intl.NumberFormat(r.locale, {
    style: 'currency',
    currency: r.currency,
    minimumFractionDigits: decimals ? 2 : 0,
    maximumFractionDigits: decimals ? 2 : 0,
  }).format(amount);
}
