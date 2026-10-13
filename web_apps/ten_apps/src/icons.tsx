import {
  Battery, Bell, BookOpen, Calendar, Camera, Check, ChevronLeft, ChevronRight, Clock, Compass, Ear, Hammer, Hand,
  Headphones, Home, Languages, Map, MapPin, Mic, Navigation, Plus, Recycle, Repeat, Scan, Shield, Shirt, Sprout,
  Timer, User, Users, Utensils, Wallet, Wrench, X, type LucideIcon,
} from 'lucide-react';

// The design references shadcn/ui DS glyphs as `Icon<LucideName>`; they map 1:1 onto lucide.
const ICONS: Record<string, LucideIcon> = {
  IconBattery: Battery, IconBell: Bell, IconBookOpen: BookOpen, IconCalendar: Calendar, IconCamera: Camera,
  IconCheck: Check, IconChevronLeft: ChevronLeft, IconChevronRight: ChevronRight, IconClock: Clock,
  IconCompass: Compass, IconEar: Ear, IconHammer: Hammer, IconHand: Hand, IconHeadphones: Headphones,
  IconHome: Home, IconLanguages: Languages, IconMap: Map, IconMapPin: MapPin, IconMic: Mic,
  IconNavigation: Navigation, IconPlus: Plus, IconRecycle: Recycle, IconRepeat: Repeat, IconScan: Scan,
  IconShield: Shield, IconShirt: Shirt, IconSprout: Sprout, IconTimer: Timer, IconUser: User, IconUsers: Users,
  IconUtensils: Utensils, IconWallet: Wallet, IconWrench: Wrench, IconX: X,
};

export function Icon({ name, size }: { name: string; size: number }) {
  const C = ICONS[name];
  if (!C) return <span style={{ width: size, height: size, display: 'inline-block' }} />;
  return <C size={size} strokeWidth={2} style={{ flex: 'none', display: 'block' }} />;
}
