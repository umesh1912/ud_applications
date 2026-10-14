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

  // Accounts, onboarding and administration
  profileTitle:['તમારું નામ','Your name'], profileSub:['સોસાયટીના સભ્યો તમને આ નામથી ઓળખશે','This is how society members will see you'],
  nameLbl:['પૂરું નામ','Full name'], nameGuLbl:['ગુજરાતીમાં નામ (વૈકલ્પિક)','Name in Gujarati (optional)'], continue:['આગળ વધો','Continue'],
  welcome:['સ્વાગત છે','Welcome'], welcomeSub:['તમારી સોસાયટી નોંધાવો અથવા તેમાં જોડાઓ','Register your society or join one'],
  registerSociety:['નવી સોસાયટી નોંધાવો','Register a society'], registerSub:['તમે તેના સેક્રેટરી (એડમિન) બનશો','You become its secretary (admin)'],
  joinSociety:['સોસાયટીમાં જોડાઓ','Join a society'], joinSub:['સેક્રેટરી પાસેથી મળેલ કોડ વાપરો','Use the code from your secretary'],
  pendingRequests:['બાકી વિનંતીઓ','Pending requests'], waitingApproval:['સેક્રેટરીની મંજૂરીની રાહ','Waiting for the secretary to approve'],
  cancelRequest:['રદ કરો','Cancel'], refresh:['તાજું કરો','Refresh'],
  societyName:['સોસાયટીનું નામ','Society name'], societyNameGu:['ગુજરાતીમાં નામ (વૈકલ્પિક)','Name in Gujarati (optional)'], city:['શહેર','City'], address:['સરનામું','Address'],
  wings:['વિંગ / બ્લોક','Wings / blocks'], wingName:['વિંગ','Wing'], floors:['માળ','Floors'], perFloor:['માળ દીઠ ફ્લેટ','Flats / floor'], addWing:['વિંગ ઉમેરો','Add wing'],
  flatsPreview:['કુલ ફ્લેટ','Total flats'], maintenanceAmt:['માસિક મેન્ટેનન્સ (₹)','Monthly maintenance (₹)'], dueDay:['દર મહિનાની છેલ્લી તારીખ','Due day each month'],
  upiId:['સોસાયટીનો UPI ID','Society UPI ID'], upiIdHint:['સભ્યો આ UPI ID પર સીધું ચૂકવશે','Members pay straight to this UPI ID'], yourFlat:['તમારો ફ્લેટ','Your flat'],
  noFlatOption:['હું અહીં રહેતો નથી','I don’t live here'], create:['સોસાયટી બનાવો','Create society'],
  societyCode:['સોસાયટી કોડ','Society code'], findSociety:['શોધો','Find'], joinAs:['હું છું','I am a'], asResident:['રહેવાસી','Resident'], asGuard:['સિક્યુરિટી ગાર્ડ','Security guard'],
  owner:['માલિક','Owner'], tenant:['ભાડૂઆત','Tenant'], sendRequest:['વિનંતી મોકલો','Send request'], requestSent:['વિનંતી મોકલી – સેક્રેટરી મંજૂર કરશે','Request sent – the secretary will approve it'],
  members:['સભ્યો','Members'], joinRequests:['જોડાવાની વિનંતીઓ','Join requests'], activeMembers:['સક્રિય સભ્યો','Active members'], remove:['દૂર કરો','Remove'],
  you:['તમે','You'], noRequests:['કોઈ વિનંતી નથી','No requests'], approvedMsg:['મંજૂર કર્યું','Approved'], rejectedMsg:['નામંજૂર કર્યું','Rejected'],
  settings:['સોસાયટી સેટિંગ્સ','Society settings'], shareCode:['કોડ શેર કરો','Share code'], shareText:['અમારી સોસાયટી એપમાં જોડાઓ. સોસાયટી કોડ: ','Join our society on the app. Society code: '],
  save:['સાચવો','Save'], saved:['સાચવ્યું','Saved'], guestSlots:['મહેમાન પાર્કિંગ જગ્યા','Guest parking slots'],
  raiseBill:['ચાર્જ ઉમેરો','Raise a charge'], allFlats:['બધા ફ્લેટ','All flats'], oneFlat:['એક ફ્લેટ','One flat'], dueDate:['છેલ્લી તારીખ','Due date'],
  billRaised:['ચાર્જ ઉમેર્યો – ફ્લેટ: ','Charge added – flats: '],
  payUpi:['UPI થી ચૂકવો','Pay by UPI'], openUpi:['UPI એપ ખોલો','Open UPI app'], upiStep1:['1. કોઈપણ UPI એપથી સોસાયટીને ચૂકવો','1. Pay the society from any UPI app'],
  upiStep2:['2. ચુકવણીનો UTR / સંદર્ભ નંબર લખો','2. Enter the payment’s UTR / reference number'], utr:['UTR / સંદર્ભ નંબર','UTR / reference no.'],
  iPaid:['મેં ચૂકવી દીધું','I’ve paid'], claimSent:['ખજાનચીને ચકાસણી માટે મોકલ્યું','Sent to the treasurer to confirm'],
  noUpi:['સોસાયટીએ હજી UPI ID ઉમેર્યો નથી. ખજાનચીને રોકડ કે ચેકથી ચૂકવો.','The society hasn’t added a UPI ID yet. Pay the treasurer by cash or cheque.'],
  verifying:['ચકાસણી બાકી','Being verified'], toVerify:['ચકાસવાની ચુકવણી','Payments to confirm'], confirm:['પુષ્ટિ કરો','Confirm'],
  recordPayment:['ચુકવણી નોંધો','Record payment'], method:['પદ્ધતિ','Method'], cash:['રોકડ','Cash'], cheque:['ચેક','Cheque'], bank:['બેંક ટ્રાન્સફર','Bank transfer'],
  reference:['સંદર્ભ (વૈકલ્પિક)','Reference (optional)'], pickFlat:['ફ્લેટ પસંદ કરો','Choose a flat'], nothingDue:['કોઈ ફ્લેટનું બાકી નથી','No flat has anything due'],
  paymentConfirmed:['ચુકવણીની પુષ્ટિ થઈ','Payment confirmed'],
  newEvent:['નવો કાર્યક્રમ','New event'], eventTitle:['કાર્યક્રમનું નામ','Event name'], eventDate:['તારીખ','Date'], eventTime:['સમય','Time'], eventPlace:['સ્થળ','Place'],
  newPoll:['નવું મતદાન','New poll'], question:['પ્રશ્ન','Question'], option:['વિકલ્પ','Option'], addOption:['વિકલ્પ ઉમેરો','Add option'], pollEnds:['મતદાન બંધ થવાની તારીખ','Voting closes on'],
  addStaff:['સ્ટાફ ઉમેરો','Add staff'], staffRole:['કામ (ઉદા. ઘરકામ)','Work (e.g. maid)'], staffFlats:['ફ્લેટ','Flats'],
  addVehicle:['વાહન ઉમેરો','Add vehicle'], vehicleNo:['વાહન નંબર','Vehicle number'], parkingSlot:['પાર્કિંગ નંબર','Parking slot'], car:['કાર','Car'], twoWheeler:['ટુ-વ્હીલર','Two-wheeler'],
  location:['જગ્યા (વૈકલ્પિક)','Location (optional)'], addContact:['સંપર્ક ઉમેરો','Add contact'], phoneLbl:['ફોન','Phone'], contactRole:['કામ (ઉદા. પ્લમ્બર)','Service (e.g. plumber)'],
  uploadDoc:['દસ્તાવેજ અપલોડ કરો','Upload a document'], docName:['દસ્તાવેજનું નામ','Document name'], chooseFile:['ફાઇલ પસંદ કરો (PDF / ફોટો)','Choose file (PDF / photo)'],
  added:['ઉમેર્યું','Added'], deleted:['દૂર કર્યું','Removed'], switchSociety:['સોસાયટી બદલો','Switch society'], addSociety:['બીજી સોસાયટી ઉમેરો / જોડાઓ','Register or join another society'],
  noDocs:['હજી કોઈ દસ્તાવેજ નથી','No documents yet'], noStaff:['હજી કોઈ સ્ટાફ નથી','No staff added yet'], noEvents:['કોઈ આગામી કાર્યક્રમ નથી','No upcoming events'], noPolls:['કોઈ મતદાન નથી','No polls'], noNotices:['હજી કોઈ નોટિસ નથી','No notices yet'],
  // Server error codes (snake_case → camelCase)
  nameRequired:['નામ લખો','Enter a name'], wingsInvalid:['વિંગની વિગત તપાસો (નામ, માળ, ફ્લેટ)','Check the wing details (name, floors, flats)'], tooManyFlats:['ફ્લેટ ઘણા વધારે છે','Too many flats'],
  societyNameRequired:['સોસાયટીનું નામ લખો','Enter the society name'], cityRequired:['શહેર લખો','Enter the city'], codeUnknown:['આ કોડની કોઈ સોસાયટી નથી','No society has this code'],
  alreadyMember:['તમે પહેલેથી સભ્ય છો','You’re already a member'], lastSecretary:['ઓછામાં ઓછો એક સેક્રેટરી જરૂરી છે','A society needs at least one secretary'],
  referenceInvalid:['સાચો UTR નંબર લખો (6–30 અક્ષર)','Enter a valid UTR (6–30 letters/digits)'], upiInvalid:['UPI ID ખોટો છે (ઉદા. name@bank)','Invalid UPI ID (e.g. name@bank)'],
  otpWait:['થોડી સેકંડ પછી ફરી પ્રયાસ કરો','Wait a few seconds and try again'], smsFailed:['SMS મોકલી શકાયો નહીં, ફરી પ્રયાસ કરો','Couldn’t send the SMS, try again'],
  dateInvalid:['તારીખ તપાસો','Check the date'], amountRequired:['રકમ લખો','Enter an amount'], titleRequired:['શીર્ષક લખો','Add a title'], optionsRequired:['ઓછામાં ઓછા 2 વિકલ્પ લખો','Add at least 2 options'],
  questionRequired:['પ્રશ્ન લખો','Enter the question'], fileRequired:['ફાઇલ પસંદ કરો','Choose a file'], flatRequired:['ફ્લેટ નંબર જરૂરી','A flat is required'], vehicleRequired:['વાહન નંબર લખો','Enter the vehicle number'],
  roleRequired:['કામ લખો','Enter the work'], textRequired:['વિગત લખો','Add a short description'], nothingDue2:['કંઈ બાકી નથી','Nothing due'], onlinePayUnavailable:['ઓનલાઇન ચુકવણી ઉપલબ્ધ નથી','Online payment isn’t available'],
  billsUnavailable:['આ બિલ પહેલેથી ચૂકવાઈ ગયા છે','These bills are already paid'], forbidden:['આ માટે પરવાનગી નથી','You don’t have permission for this'], noSociety:['તમે હજી કોઈ સોસાયટીના સભ્ય નથી','You’re not in a society yet'],
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
