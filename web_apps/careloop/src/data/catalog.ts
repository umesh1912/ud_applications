import type { Region } from './region';

export interface Specialty {
  id: string;
  name: string;
  /** What a patient would search for. */
  symptoms: string;
  icon: string;
  tint: string;
}

export const SPECIALTIES: Specialty[] = [
  { id: 'gp', name: 'General Physician', symptoms: 'Fever, cold, cough', icon: 'Thermometer', tint: '#0f766e' },
  { id: 'derm', name: 'Dermatology', symptoms: 'Acne, rashes, hair fall', icon: 'Sparkles', tint: '#c026d3' },
  { id: 'peds', name: 'Pediatrics', symptoms: 'Child health, vaccines', icon: 'Baby', tint: '#0284c7' },
  { id: 'gyn', name: 'Gynecology', symptoms: 'Periods, pregnancy', icon: 'HeartHandshake', tint: '#db2777' },
  { id: 'cardio', name: 'Cardiology', symptoms: 'Chest pain, blood pressure', icon: 'HeartPulse', tint: '#dc2626' },
  { id: 'ortho', name: 'Orthopedics', symptoms: 'Back and joint pain', icon: 'Bone', tint: '#9a6b00' },
  { id: 'psych', name: 'Mental health', symptoms: 'Stress, anxiety, sleep', icon: 'Brain', tint: '#7c3aed' },
  { id: 'endo', name: 'Diabetes & thyroid', symptoms: 'Sugar, thyroid, weight', icon: 'Droplet', tint: '#ea580c' },
];

export interface Review {
  name: string;
  rating: number;
  text: string;
  when: string;
}

export interface Doctor {
  id: string;
  name: string;
  specialty: string;
  degrees: string;
  years: number;
  rating: number;
  reviews: number;
  patients: number;
  languages: string[];
  clinic: string;
  area: string;
  distanceKm: number;
  feeVideo: number;
  feeClinic: number;
  nextFree: string;
  hue: number;
  about: string;
  topReviews: Review[];
  /** Accepts insurance (US) / offers free follow-up within 7 days (IN). */
  perk: string;
}

type DoctorSeed = Omit<Doctor, 'id' | 'name' | 'degrees' | 'languages' | 'clinic' | 'area' | 'feeVideo' | 'feeClinic' | 'topReviews' | 'perk'>;

const SHARED: DoctorSeed[] = [
  { specialty: 'gp', years: 12, rating: 4.9, reviews: 2140, patients: 18400, distanceKm: 1.2, nextFree: 'in 20 min', hue: 168, about: 'Treats common infections, fevers, allergies and lifestyle conditions. Known for unhurried consults and clear follow-up plans.' },
  { specialty: 'cardio', years: 18, rating: 4.8, reviews: 1320, patients: 9600, distanceKm: 3.4, nextFree: 'Today, 5:30 PM', hue: 352, about: 'Interventional cardiologist focused on hypertension, chest pain evaluation and heart-failure care.' },
  { specialty: 'derm', years: 9, rating: 4.9, reviews: 1810, patients: 12100, distanceKm: 2.1, nextFree: 'in 1 hr', hue: 300, about: 'Medical and cosmetic dermatology: acne, pigmentation, eczema, hair loss. Photo-based follow-ups.' },
  { specialty: 'peds', years: 14, rating: 4.9, reviews: 2560, patients: 21000, distanceKm: 0.8, nextFree: 'in 40 min', hue: 205, about: 'Newborn to teen care, growth tracking, vaccination schedules and fever management for children.' },
  { specialty: 'gyn', years: 16, rating: 4.8, reviews: 1690, patients: 11300, distanceKm: 2.9, nextFree: 'Tomorrow, 10 AM', hue: 330, about: 'Pregnancy care, PCOS, menstrual health and menopause, with a calm, private consultation style.' },
  { specialty: 'ortho', years: 11, rating: 4.7, reviews: 980, patients: 7400, distanceKm: 4.6, nextFree: 'Today, 6 PM', hue: 38, about: 'Back and neck pain, sports injuries and arthritis. Builds exercise plans you can follow at home.' },
  { specialty: 'psych', years: 10, rating: 4.9, reviews: 1150, patients: 6200, distanceKm: 5.0, nextFree: 'in 2 hr', hue: 262, about: 'Anxiety, depression, sleep and burnout. Evidence-based therapy with medication when it helps.' },
  { specialty: 'endo', years: 15, rating: 4.8, reviews: 1430, patients: 10200, distanceKm: 3.0, nextFree: 'Today, 4 PM', hue: 24, about: 'Type 1 and type 2 diabetes, thyroid disorders and weight management with monthly check-ins.' },
];

const IN_PEOPLE = [
  { name: 'Dr. Ananya Rao', degrees: 'MBBS, MD (Internal Medicine)', languages: ['English', 'Hindi', 'Kannada'], clinic: 'Sunrise Health Clinic', area: 'Indiranagar, Bengaluru', feeVideo: 499, feeClinic: 700 },
  { name: 'Dr. Vikram Mehta', degrees: 'MBBS, MD, DM (Cardiology)', languages: ['English', 'Hindi', 'Gujarati'], clinic: 'HeartCare Centre', area: 'Koramangala, Bengaluru', feeVideo: 999, feeClinic: 1200 },
  { name: 'Dr. Priya Nair', degrees: 'MBBS, MD (Dermatology)', languages: ['English', 'Malayalam', 'Hindi'], clinic: 'Skin & Hair Studio', area: 'HSR Layout, Bengaluru', feeVideo: 599, feeClinic: 800 },
  { name: 'Dr. Arjun Shah', degrees: 'MBBS, MD (Pediatrics)', languages: ['English', 'Hindi', 'Marathi'], clinic: 'Little Steps Children’s Clinic', area: 'Indiranagar, Bengaluru', feeVideo: 549, feeClinic: 750 },
  { name: 'Dr. Kavita Iyer', degrees: 'MBBS, MS (Obstetrics & Gynaecology)', languages: ['English', 'Tamil', 'Hindi'], clinic: 'Bloom Women’s Health', area: 'Jayanagar, Bengaluru', feeVideo: 699, feeClinic: 900 },
  { name: 'Dr. Rohan Desai', degrees: 'MBBS, MS (Orthopaedics)', languages: ['English', 'Hindi', 'Gujarati'], clinic: 'Motion Ortho Clinic', area: 'Whitefield, Bengaluru', feeVideo: 649, feeClinic: 900 },
  { name: 'Dr. Sana Qureshi', degrees: 'MBBS, MD (Psychiatry)', languages: ['English', 'Hindi', 'Urdu'], clinic: 'MindSpace Clinic', area: 'Online only', feeVideo: 899, feeClinic: 1100 },
  { name: 'Dr. Meera Joshi', degrees: 'MBBS, MD, DM (Endocrinology)', languages: ['English', 'Hindi', 'Marathi'], clinic: 'Sugar & Thyroid Care', area: 'Malleshwaram, Bengaluru', feeVideo: 799, feeClinic: 1000 },
];

const US_PEOPLE = [
  { name: 'Dr. Emily Carter', degrees: 'MD, Board-certified Family Medicine', languages: ['English'], clinic: 'Bayview Family Health', area: 'Mission District, San Francisco', feeVideo: 59, feeClinic: 89 },
  { name: 'Dr. James Wilson', degrees: 'MD, FACC (Cardiology)', languages: ['English'], clinic: 'Golden Gate Heart Institute', area: 'Nob Hill, San Francisco', feeVideo: 149, feeClinic: 199 },
  { name: 'Dr. Sofia Martinez', degrees: 'MD, FAAD (Dermatology)', languages: ['English', 'Spanish'], clinic: 'Clear Skin Dermatology', area: 'SoMa, San Francisco', feeVideo: 99, feeClinic: 139 },
  { name: 'Dr. Michael Chen', degrees: 'MD, FAAP (Pediatrics)', languages: ['English', 'Mandarin'], clinic: 'Sunset Pediatrics', area: 'Inner Sunset, San Francisco', feeVideo: 79, feeClinic: 109 },
  { name: 'Dr. Rachel Green', degrees: 'MD, FACOG (OB-GYN)', languages: ['English'], clinic: 'Pacific Women’s Health', area: 'Marina, San Francisco', feeVideo: 99, feeClinic: 149 },
  { name: 'Dr. David Kim', degrees: 'MD (Orthopedic Surgery)', languages: ['English', 'Korean'], clinic: 'Bay Sports & Spine', area: 'Potrero Hill, San Francisco', feeVideo: 109, feeClinic: 159 },
  { name: 'Dr. Aisha Johnson', degrees: 'MD (Psychiatry)', languages: ['English'], clinic: 'Calm Mind Telepsychiatry', area: 'Online only', feeVideo: 129, feeClinic: 169 },
  { name: 'Dr. Robert Patel', degrees: 'MD (Endocrinology)', languages: ['English', 'Hindi', 'Gujarati'], clinic: 'Bay Area Diabetes Center', area: 'Palo Alto', feeVideo: 119, feeClinic: 159 },
];

const REVIEWS: Record<Region, Review[]> = {
  IN: [
    { name: 'Neha S.', rating: 5, text: 'Listened patiently and explained everything. The prescription was in the app before the call ended.', when: '2 days ago' },
    { name: 'Karthik R.', rating: 5, text: 'Joined on time, no waiting. Follow-up chat the next day was free.', when: '1 week ago' },
    { name: 'Fatima K.', rating: 4, text: 'Very knowledgeable. Clinic was a little busy but the token system worked well.', when: '3 weeks ago' },
  ],
  US: [
    { name: 'Jordan P.', rating: 5, text: 'Got seen within 20 minutes from my couch. Clear plan, and the prescription went straight to my pharmacy.', when: '3 days ago' },
    { name: 'Maria L.', rating: 5, text: 'Took my insurance and the copay was shown before booking. No surprise bills.', when: '1 week ago' },
    { name: 'Chris T.', rating: 4, text: 'Thorough and kind. Lab order showed up in the app right away.', when: '1 month ago' },
  ],
};

export function doctorsFor(region: Region): Doctor[] {
  const people = region === 'IN' ? IN_PEOPLE : US_PEOPLE;
  return SHARED.map((seed, i) => ({
    ...seed,
    ...people[i],
    id: `${region.toLowerCase()}-${i}`,
    topReviews: REVIEWS[region],
    perk: region === 'IN' ? 'Free follow-up chat for 7 days' : 'In-network for most major insurers',
  }));
}

export const specialtyOf = (id: string) => SPECIALTIES.find((s) => s.id === id)!;

// ---------------------------------------------------------------- dates and slots

export const DAY = 86400000;
export const startOfToday = () => { const d = new Date(); d.setHours(0, 0, 0, 0); return d.getTime(); };
export const fmtDay = (t: number) => new Date(t).toLocaleDateString('en', { weekday: 'short', day: 'numeric', month: 'short' });
export const fmtTime = (t: number) => new Date(t).toLocaleTimeString('en', { hour: 'numeric', minute: '2-digit' });
export const dow = (t: number) => new Date(t).toLocaleDateString('en', { weekday: 'short' });
export function relDay(t: number) {
  const diff = Math.round((new Date(t).setHours(0, 0, 0, 0) - startOfToday()) / DAY);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Tomorrow';
  if (diff === -1) return 'Yesterday';
  return fmtDay(t);
}

/** Bookable slots for a doctor on a day; some are deterministically taken so the grid looks real. */
export function slotsFor(doctorId: string, day: number) {
  const hours = [9, 9.5, 10, 10.5, 11, 11.5, 12, 14, 14.5, 15, 15.5, 16, 17, 17.5, 18, 18.5, 19, 19.5];
  const seed = [...doctorId].reduce((a, c) => a + c.charCodeAt(0), 0) + new Date(day).getDate();
  const now = Date.now();
  return hours.map((h, i) => {
    const t = day + h * 3600000;
    const taken = (seed * (i + 3)) % 5 === 0 || t < now + 15 * 60000;
    return { t, taken };
  });
}

// ---------------------------------------------------------------- labs and medicines

export interface LabPackage {
  id: string;
  name: string;
  tests: number;
  includes: string[];
  price: Record<Region, number>;
  mrp: Record<Region, number>;
  tat: string;
  popular?: boolean;
}

export const LAB_PACKAGES: LabPackage[] = [
  { id: 'full', name: 'Full body checkup', tests: 86, includes: ['CBC', 'Lipid profile', 'Liver & kidney', 'Thyroid', 'HbA1c', 'Vitamin D & B12'], price: { IN: 1499, US: 129 }, mrp: { IN: 3999, US: 249 }, tat: 'Reports in 24 hrs', popular: true },
  { id: 'diabetes', name: 'Diabetes care', tests: 32, includes: ['HbA1c', 'Fasting sugar', 'Kidney function', 'Urine microalbumin'], price: { IN: 799, US: 79 }, mrp: { IN: 1800, US: 140 }, tat: 'Reports in 12 hrs' },
  { id: 'heart', name: 'Heart health', tests: 28, includes: ['Lipid profile', 'hs-CRP', 'ECG at home', 'Homocysteine'], price: { IN: 1299, US: 119 }, mrp: { IN: 2900, US: 210 }, tat: 'Reports in 24 hrs' },
  { id: 'women', name: 'Women’s wellness', tests: 54, includes: ['Hormone panel', 'Iron studies', 'Thyroid', 'Vitamin D'], price: { IN: 1699, US: 149 }, mrp: { IN: 3600, US: 260 }, tat: 'Reports in 36 hrs' },
];

export interface Medicine {
  name: string;
  form: string;
  price: Record<Region, number>;
}

export const MEDICINES: Medicine[] = [
  { name: 'Paracetamol 650 mg', form: 'Tablet', price: { IN: 32, US: 6 } },
  { name: 'Cetirizine 10 mg', form: 'Tablet', price: { IN: 24, US: 8 } },
  { name: 'Azithromycin 500 mg', form: 'Tablet', price: { IN: 118, US: 14 } },
  { name: 'Amoxicillin 500 mg', form: 'Capsule', price: { IN: 96, US: 12 } },
  { name: 'Pantoprazole 40 mg', form: 'Tablet', price: { IN: 88, US: 11 } },
  { name: 'Metformin 500 mg', form: 'Tablet', price: { IN: 42, US: 9 } },
  { name: 'Amlodipine 5 mg', form: 'Tablet', price: { IN: 56, US: 10 } },
  { name: 'Vitamin D3 60,000 IU', form: 'Capsule', price: { IN: 130, US: 12 } },
  { name: 'ORS sachet', form: 'Powder', price: { IN: 20, US: 5 } },
  { name: 'Ibuprofen 400 mg', form: 'Tablet', price: { IN: 28, US: 7 } },
  { name: 'Levocetirizine 5 mg', form: 'Tablet', price: { IN: 38, US: 9 } },
  { name: 'Montelukast 10 mg', form: 'Tablet', price: { IN: 145, US: 15 } },
];

export const medicineByName = (n: string) => MEDICINES.find((m) => m.name === n);

export const COMMON_TESTS = ['CBC', 'CRP', 'Dengue NS1', 'Malaria antigen', 'Chest X-ray', 'HbA1c', 'Lipid profile', 'Thyroid profile', 'Urine routine', 'Vitamin D'];
export const DOSES = ['1-0-1', '1-0-0', '0-0-1', '1-1-1', 'SOS'];
export const DURATIONS = ['3 days', '5 days', '7 days', '14 days', '1 month'];

/** Drug families for allergy checks: an allergy to the family name also covers its members. */
const ALLERGY_CLASSES: Record<string, string[]> = {
  penicillin: ['penicillin', 'amoxicillin', 'ampicillin', 'cloxacillin', 'piperacillin'],
  sulfa: ['sulfamethoxazole', 'sulfasalazine', 'sulfadiazine'],
  nsaid: ['ibuprofen', 'diclofenac', 'naproxen', 'aspirin', 'aceclofenac'],
  ibuprofen: ['ibuprofen'],
  aspirin: ['aspirin'],
  cephalosporin: ['cefixime', 'cefuroxime', 'ceftriaxone', 'cephalexin'],
  macrolide: ['azithromycin', 'clarithromycin', 'erythromycin'],
};

/** The allergy a medicine conflicts with, if any. */
export function allergyConflict(medicine: string, allergies: string | undefined): string | null {
  if (!allergies || allergies.toLowerCase() === 'none') return null;
  const med = medicine.toLowerCase();
  for (const raw of allergies.toLowerCase().split(/[,;/]+/).map((x) => x.trim()).filter(Boolean)) {
    const key = Object.keys(ALLERGY_CLASSES).find((k) => raw.includes(k));
    const members = key ? ALLERGY_CLASSES[key] : [raw];
    if (members.some((m) => m.length > 3 && med.includes(m))) return raw;
  }
  return null;
}
