import type { Role } from './i18n';

// Mirrors server/src/state.ts → buildState() and the /me route.
export interface Bill { id: number; icon: string; titleGu: string; titleEn: string; amount: number; due: string; paid: boolean; claimed: boolean }
export interface PaymentRow { id: number; titleGu: string; titleEn: string; amount: number; method: string; receiptNo: string | null; createdAt: string; status: 'pending' | 'confirmed' }
export interface Visitor { id: number; name: string; flat: string; purpose: string; status: 'waiting' | 'inside' | 'out' | 'denied'; inAt: string; outAt: string | null }
export interface Pass { id: number; flat: string; name: string; validOn: string; windowGu: string; windowEn: string; code: string }
export interface Complaint { id: number; code: string; flat: string; category: string; textGu: string; textEn: string; status: 'open' | 'progress' | 'resolved'; createdAt: string }
export interface Notice { id: number; titleGu: string; titleEn: string; bodyGu: string; bodyEn: string; pinned: boolean; createdAt: string }
export interface EventItem { id: number; titleGu: string; titleEn: string; startsOn: string; whenGu: string; whenEn: string; placeGu: string; placeEn: string; going: number; me: boolean }
export interface Poll { id: number; qGu: string; qEn: string; endsOn: string; closed: boolean; votedOption: number | null; options: { id: number; labelGu: string; labelEn: string; votes: number }[] }
export interface Amenity { id: string; icon: string; nameGu: string; nameEn: string; fee: number; unit: 'slot' | 'night' }
export interface Staff { id: number; nameGu: string; nameEn: string; roleGu: string; roleEn: string; flats: string; inTime: string | null; outTime: string | null; days: number }
export interface DueFlat { flat: string; name: string; amount: number; months: number; overdue: number; reminded: boolean }
export interface Finance {
  fund: number; collected: number; target: number; split: { upi: number; card: number; cash: number };
  defaulters: DueFlat[]; dueFlats: DueFlat[];
  expenses: { id: number; category: string; titleGu: string; titleEn: string; amount: number; date: string }[];
  monthExpense: number; monthByCategory: { category: string; amount: number }[];
  pending: { id: number; category: string; titleGu: string; titleEn: string; amount: number; by: string; date: string; fileName: string | null; hasFile: boolean }[];
  claims: { id: number; flat: string; amount: number; method: string; reference: string | null; createdAt: string; by: string }[];
}
export interface Members {
  pending: { id: number; name: string; phone: string; flat: string | null; role: Role; occupancy: string; createdAt: string }[];
  active: { id: number; name: string; phone: string; flat: string | null; role: Role; me: boolean }[];
}
export interface AppState {
  demo: boolean; onlinePay: boolean; today: string; now: string;
  society: { id: number; gu: string; en: string; cityGu: string; cityEn: string; address: string; totalFlats: number; upiId: string; code?: string; maintenance?: number; dueDay?: number; guestParking?: number };
  me: { id: number; memberId: number; name: string; nameGu: string; role: Role; flat: string | null; phone: string };
  autopay: boolean; bills: Bill[]; history: PaymentRow[]; visitors: Visitor[]; myWaiting: Visitor[]; passes: Pass[]; complaints: Complaint[];
  notices: Notice[]; events: EventItem[]; polls: Poll[];
  amenities: Amenity[]; bookedSlots: { amenity: string; date: string; slot: string }[]; myBookings: { id: number; amenity: string; date: string; slot: string; fee: number }[];
  parking: { id: number; slot: string; vehicle: string; kind: 'car' | 'two'; location: string }[]; guestFree: number; guestTotal: number;
  staff: Staff[];
  directory: { id?: number; grp: 'committee' | 'resident' | 'emergency'; initials: string; nameGu: string; nameEn: string; subGu: string; subEn: string; phone: string }[];
  documents: { id: number; nameGu: string; nameEn: string; size: string; date: string }[];
  sos: { id: number; flat: string | null; type: string; createdAt: string; mine: boolean } | null;
  finance: Finance | null;
  members: Members | null;
}
export interface Membership { id: number; societyId: number; society: string; societyGu: string; city: string; flat: string | null; role: Role; status: 'active' | 'pending' }
export interface Me { account: { id: number; name: string; nameGu: string; phone: string }; memberships: Membership[]; activeMemberId: number | null }
