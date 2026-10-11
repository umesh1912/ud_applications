// UI strings and lookup tables, carried over verbatim from the design prototype. Each entry is [Gujarati, English].
export type Pair = readonly [string, string];

export const D = {
  home:['હોમ','Home'], bills:['બિલ','Bills'], gate:['ગેટ','Gate'], community:['સમુદાય','Community'], more:['વધુ','More'],
  reports:['વસૂલાત','Collections'], expenses:['ખર્ચ','Expenses'], visitors:['મુલાકાતીઓ','Visitors'], help:['સ્ટાફ','Staff'],
  complaints:['ફરિયાદ','Complaints'], amenities:['સુવિધા બુકિંગ','Amenity booking'], parking:['પાર્કિંગ','Parking'],
  directory:['સભ્ય યાદી','Directory'], docs:['દસ્તાવેજો','Documents'], events:['કાર્યક્રમ','Events'], notices:['નોટિસ','Notices'], polls:['મતદાન','Polls'],
  dailyHelp:['ઘરકામ સ્ટાફ','Daily help'], gatePass:['ગેટ પાસ','Gate pass'],
  greeting:['નમસ્તે','Hello'], flat:['ફ્લેટ','Flat'], wingB:['બી વિંગ','B wing'], society:['શિવમ રેસિડેન્સી','Shivam Residency'],
  totalDue:['કુલ બાકી રકમ','Total due'], payNow:['હમણાં ચૂકવો','Pay now'], dueBy:['છેલ્લી તારીખ','Due'], allPaid:['બધા બિલ ચૂકવાઈ ગયા','All bills paid'],
  atGate:['ગેટ પર મુલાકાતી રાહ જુએ છે','Visitor waiting at gate'], approve:['મંજૂર','Approve'], deny:['નામંજૂર','Deny'], reject:['નામંજૂર','Reject'],
  services:['સેવાઓ','Services'], latestNotice:['તાજી નોટિસ','Latest notice'], upcoming:['આગામી કાર્યક્રમ','Upcoming event'],
  paid:['ચૂકવેલ','Paid'], unpaid:['બાકી','Due'], selectBills:['ચૂકવવા માટે બિલ પસંદ કરો','Tap bills to select them for payment'],
  history:['ચુકવણી ઇતિહાસ','Payment history'], payMethod:['ચુકવણી પદ્ધતિ','Payment method'],
  autopay:['ઓટો-પે','Auto-pay'], autopaySub:['દર મહિને 5 તારીખે મેન્ટેનન્સ આપમેળે કપાશે','Maintenance is debited automatically on the 5th'],
  pay:['ચૂકવો','Pay'], billsSel:['બિલ પસંદ કર્યા','bills selected'], secure:['100% સુરક્ષિત ચુકવણી','Secured payment'],
  receiptPdf:['રસીદ PDF','Receipt PDF'], done:['થઈ ગયું','Done'], success:['ચુકવણી સફળ','Payment successful'],
  fundBalance:['સોસાયટી ફંડ બેલેન્સ','Society fund balance'], asOn:['તારીખ','As on'], octCollection:['ઓક્ટોબર મેન્ટેનન્સ વસૂલાત','October maintenance collection'],
  flatsPending:['ફ્લેટ બાકી','flats pending'], monthExpense:['આ મહિનાનો ખર્ચ','Expenses this month'], pendingApproval:['મંજૂરી બાકી','Awaiting approval'],
  quickActions:['ઝડપી કાર્યો','Quick actions'], openComplaints:['ખુલ્લી ફરિયાદો','Open complaints'],
  newEntry:['નવી એન્ટ્રી','New visitor entry'], verifyPass:['ગેટ પાસ કોડ ચકાસો','Verify gate pass code'], check:['ચકાસો','Check'],
  insideNow:['આજના મુલાકાતીઓ','Today’s visitors'], inAt:['પ્રવેશ','In'], exit:['બહાર','Exit'],
  createPass:['મહેમાન માટે ગેટ પાસ બનાવો','Create a guest gate pass'], activePasses:['સક્રિય પાસ','Active passes'], visitorLog:['મારા મુલાકાતીઓ','My visitors'],
  important:['મહત્વપૂર્ણ','Important'], postNotice:['નવી નોટિસ મૂકો','Post a notice'], raiseComplaint:['નવી ફરિયાદ નોંધાવો','Raise a complaint'],
  pickDate:['તારીખ પસંદ કરો','Pick a date'], pickSlot:['સમય પસંદ કરો','Pick a time slot'], myBookings:['મારા બુકિંગ','My bookings'],
  guestParking:['મહેમાન પાર્કિંગ','Guest parking'], free:['ખાલી','free'], reqGuestParking:['આજ માટે મહેમાન પાર્કિંગ માંગો','Request guest parking for today'],
  parkRule:['ફાળવેલ જગ્યા સિવાય વાહન પાર્ક કરવું નહીં. મહેમાન પાર્કિંગ મહત્તમ 12 કલાક માટે.','Park only in your allotted slot. Guest parking is limited to 12 hours.'],
  searchPh:['નામ અથવા ફ્લેટ નંબર શોધો','Search name or flat'], daysMonth:['દિવસ / મહિનો','days this month'],
  recordCash:['રોકડ નોંધો','Record cash'], remindAll:['બધાને યાદ અપાવો','Remind all'], reportPdf:['માસિક રિપોર્ટ','Monthly report'],
  defaulters:['બાકીદારો','Pending dues'], noDefaulters:['બધા ફ્લેટની ચુકવણી થઈ ગઈ','Every flat has paid'],
  submitBill:['બિલ જમા કરો (લાઇટ, AMC, વગેરે)','Submit a bill (light, AMC, etc.)'], awaitingSec:['સેક્રેટરીની મંજૂરીની રાહ','Waiting for the secretary’s approval'],
  allExpenses:['બધા ખર્ચ','All expenses'], switchRole:['ભૂમિકા બદલો','Switch role'],
  sendAlert:['ઇમરજન્સી એલર્ટ મોકલો','Send emergency alert'], sosNote:['બધા વોચમેન અને કમિટી સભ્યોને તરત જાણ થશે','All guards and committee members are notified instantly'],
  alertSent:['એલર્ટ મોકલાઈ ગયું','Alert sent'], alertSentSub:['ગેટ પરના વોચમેન અને કમિટીને જાણ કરવામાં આવી છે. મદદ રસ્તામાં છે.','Gate guards and committee have been notified. Help is on the way.'],
  callGuard:['વોચમેનને કૉલ કરો','Call the guard'], responding:['હું જઈ રહ્યો છું','I’m responding'],
  guestName:['મહેમાનનું નામ','Guest name'], generate:['પાસ બનાવો','Generate pass'], today:['આજે','Today'], tomorrow:['કાલે','Tomorrow'],
  category:['પ્રકાર','Category'], describe:['વિગત','Details'], describePh:['સમસ્યા ટૂંકમાં લખો','Describe the issue briefly'], submit:['જમા કરો','Submit'],
  visitorName:['મુલાકાતીનું નામ','Visitor name'], flatNo:['ફ્લેટ નંબર','Flat no.'], purpose:['હેતુ','Purpose'], sendApproval:['મંજૂરી માટે મોકલો','Send for approval'],
  titleLbl:['શીર્ષક','Title'], message:['સંદેશ','Message'], markImportant:['મહત્વપૂર્ણ તરીકે દર્શાવો','Mark as important'], publish:['પ્રકાશિત કરો','Publish'],
  vendor:['વેન્ડર / બિલનું નામ','Vendor / bill name'], amount:['રકમ (₹)','Amount (₹)'], sendForApproval:['મંજૂરી માટે મોકલો','Send for approval'],
  recordIssue:['રોકડ નોંધો અને રસીદ આપો','Record and issue receipt'],
  secretary:['સેક્રેટરી','Secretary'], treasurer:['ખજાનચી','Treasurer'], resident:['સભ્ય','Resident'], watchman:['વોચમેન','Watchman'],
  committee:['કમિટી','Committee'], residents:['સભ્યો','Residents'], emergency:['ઇમરજન્સી / સેવા','Emergency & services'],
  inside:['અંદર','Inside'], waiting:['રાહમાં','Waiting'], out:['બહાર ગયા','Left'], denied:['નામંજૂર','Denied'],
  expected:['અપેક્ષિત પાસ','Expected passes'], helpIn:['સ્ટાફ હાજર','Staff in'], visitorsIn:['અંદર મુલાકાતી','Visitors inside'],
  remind:['યાદ અપાવો','Remind'], reminded:['મોકલ્યું','Sent'], going:['જશે','going'], imGoing:['હું આવીશ','I’m going'], youGoing:['તમે આવો છો','You’re going'],
  votes:['મત','votes'], endsOn:['છેલ્લી તારીખ','Ends'], book:['બુક કરો','Book'], pickFirst:['સમય પસંદ કરો','Select a slot'],
  attach:['બિલનો ફોટો / PDF જોડો','Attach bill photo / PDF'], photo:['મુલાકાતીનો ફોટો લો','Take visitor photo'], photoAdd:['ફોટો ઉમેરો (વૈકલ્પિક)','Add photo (optional)'],
  open:['ખુલ્લી','Open'], progress:['ચાલુ','In progress'], resolved:['ઉકેલાઈ','Resolved'], start:['શરૂ કરો','Start'], resolve:['ઉકેલ્યું','Resolve'],
  present:['હાજર','In'], left:['ગયા','Left'], absent:['ગેરહાજર','Not in'], markIn:['પ્રવેશ','In'], markOut:['બહાર','Out'],
} satisfies Record<string, Pair>;

export type Role = 'resident' | 'secretary' | 'treasurer' | 'watchman';

/** Strings added for the real app (login, errors, relative dates) — not in the prototype. */
export const E = {
  login:['લૉગિન','Sign in'], loginSub:['તમારો નોંધાયેલ મોબાઇલ નંબર દાખલ કરો','Enter your registered mobile number'],
  mobile:['મોબાઇલ નંબર','Mobile number'], sendOtp:['OTP મોકલો','Send OTP'], otp:['OTP','OTP'],
  otpSent:['OTP મોકલ્યો: ','OTP sent to '], verify:['ચકાસો અને આગળ વધો','Verify and continue'], changeNumber:['નંબર બદલો','Change number'],
  demoHint:['ડેમો: કોઈપણ ભૂમિકાનો નંબર, OTP ','Demo: any role’s number, OTP '], logout:['લૉગઆઉટ','Sign out'],
  yesterday:['ગઈકાલે','Yesterday'], noVisitors:['કોઈ મુલાકાતી નથી','No visitors yet'], noPasses:['કોઈ સક્રિય પાસ નથી','No active passes'],
  noComplaints:['કોઈ ફરિયાદ નથી','No complaints'], noParking:['તમારા નામે પાર્કિંગ નથી','No parking slots allotted to you'],
  offline:['સર્વર સાથે જોડાણ નથી – ફરી પ્રયાસ થઈ રહ્યો છે','Can’t reach the server – retrying'], noFlat:['આ માટે ફ્લેટ જરૂરી છે','This needs a flat'],
  pollClosed:['મતદાન બંધ','Voting closed'], viewFile:['ફાઇલ જુઓ','View file'], parkingFull:['મહેમાન પાર્કિંગ ભરાઈ ગયું','Guest parking is full'],
  slotTaken:['આ સમય બુક થઈ ગયો છે','That slot was just booked'], error:['કંઈક ખોટું થયું','Something went wrong'],
  phoneUnknown:['આ નંબર સોસાયટીમાં નોંધાયેલ નથી','This number isn’t registered with the society'], phoneInvalid:['10 અંકનો મોબાઇલ નંબર લખો','Enter a 10-digit mobile number'],
  otpInvalid:['ખોટો OTP','Incorrect OTP'], otpExpired:['OTP ની મુદત પૂરી – ફરી મોકલો','OTP expired – send a new one'], flatUnknown:['આ ફ્લેટ નંબર મળ્યો નથી','Flat number not found'],
  offlineFile:['ઓફલાઇન ડેમોમાં PDF ઉપલબ્ધ નથી','PDFs aren’t available in the offline demo'],
} satisfies Record<string, Pair>;

export const ROLES: { id: Role; icon: string; en: string; sub: string }[] = [
  { id:'resident', icon:'IconHome', en:'Resident', sub:'Rajesh Patel · B-304' },
  { id:'secretary', icon:'IconClipboardCheck', en:'Secretary', sub:'Hasmukh Desai · A-101' },
  { id:'treasurer', icon:'IconWallet', en:'Treasurer', sub:'Nilesh Shah · C-202' },
  { id:'watchman', icon:'IconShield', en:'Watchman', sub:'Bhikhabhai · Main gate' },
];
export const TABS: Record<Role, [string, string][]> = {
  resident:[['home','IconHome'],['bills','IconReceipt'],['gate','IconShieldCheck'],['community','IconMegaphone'],['more','IconLayoutGrid']],
  secretary:[['home','IconLayoutDashboard'],['reports','IconIndianRupee'],['expenses','IconPieChart'],['community','IconMegaphone'],['more','IconLayoutGrid']],
  treasurer:[['home','IconLayoutDashboard'],['reports','IconIndianRupee'],['expenses','IconPieChart'],['community','IconMegaphone'],['more','IconLayoutGrid']],
  watchman:[['home','IconShield'],['log','IconClipboardList'],['help','IconUsers'],['more','IconLayoutGrid']],
};
export const CATS: Record<string, Pair> = { security:['સિક્યુરિટી','Security'], light:['લાઇટ બિલ','Electricity'], clean:['સફાઈ','Housekeeping'], repair:['રિપેર / AMC','Repairs & AMC'], water:['પાણી','Water'], event:['કાર્યક્રમ','Events'] };
export const CAT_ICON: Record<string, string> = { security:'IconShield', light:'IconZap', clean:'IconTrash2', repair:'IconWrench', water:'IconDroplets', event:'IconPartyPopper' };
export const COMP_CATS: [string, Pair][] = [['plumb',['પ્લમ્બિંગ','Plumbing']],['elec',['ઇલેક્ટ્રિકલ','Electrical']],['lift',['લિફ્ટ','Lift']],['clean',['સફાઈ','Cleaning']],['sec',['સિક્યુરિટી','Security']],['other',['અન્ય','Other']]];
export const PURPOSES: [string, Pair][] = [['guest',['મહેમાન','Guest']],['delivery',['ડિલિવરી','Delivery']],['cab',['કેબ','Cab']],['service',['સર્વિસ / રિપેર','Service']],['courier',['કુરિયર','Courier']]];
export const SLOTS = ['06–08','08–10','10–12','16–18','18–20','20–22'];
export const DOW: Pair[] = [['રવિ','Sun'],['સોમ','Mon'],['મંગળ','Tue'],['બુધ','Wed'],['ગુરુ','Thu'],['શુક્ર','Fri'],['શનિ','Sat']];
export const MON_EN = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
export const MON_GU = ['જાન્યુ','ફેબ્રુ','માર્ચ','એપ્રિલ','મે','જૂન','જુલાઈ','ઓગસ્ટ','સપ્ટે','ઓક્ટો','નવે','ડિસે'];
export const SOS_TYPES: [string, string, Pair][] = [['medical','IconPlusCircle',['મેડિકલ','Medical']],['fire','IconAlertTriangle',['આગ','Fire']],['theft','IconShieldAlert',['ચોરી / ઘૂસણખોરી','Theft / intruder']],['lift','IconAlertOctagon',['લિફ્ટમાં ફસાયા','Stuck in lift']]];
export const SOS_SHORT: Record<string, Pair> = { medical:['મેડિકલ','Medical'], fire:['આગ','Fire'], theft:['ચોરી','Theft'], lift:['લિફ્ટમાં ફસાયા','Stuck in lift'] };

export type Strings = { [K in keyof typeof D | keyof typeof E]: string };
export const strings = (L: 0 | 1): Strings => {
  const T = {} as Strings;
  for (const [k, v] of Object.entries({ ...D, ...E })) T[k as keyof Strings] = v[L];
  return T;
};
export const MONTH_FULL: Pair[] = [['જાન્યુઆરી','January'],['ફેબ્રુઆરી','February'],['માર્ચ','March'],['એપ્રિલ','April'],['મે','May'],['જૂન','June'],['જુલાઈ','July'],['ઓગસ્ટ','August'],['સપ્ટેમ્બર','September'],['ઓક્ટોબર','October'],['નવેમ્બર','November'],['ડિસેમ્બર','December']];
export const WING_GU: Record<string, string> = { A: 'એ', B: 'બી', C: 'સી', D: 'ડી' };
