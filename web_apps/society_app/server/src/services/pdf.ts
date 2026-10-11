import PDFDocument from 'pdfkit';

const inr = (n: number) => 'Rs. ' + Math.round(n).toLocaleString('en-IN');

function render(build: (doc: PDFKit.PDFDocument) => void): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 56 });
    const chunks: Buffer[] = [];
    doc.on('data', c => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    build(doc);
    doc.end();
  });
}

const header = (doc: PDFKit.PDFDocument, society: string, title: string) => {
  doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(20).text(society);
  doc.font('Helvetica').fontSize(11).fillColor('#64748b').text(title);
  doc.moveDown(1.2);
};

const rows = (doc: PDFKit.PDFDocument, lines: [string, string][]) => {
  for (const [k, v] of lines) {
    const y = doc.y;
    doc.font('Helvetica').fontSize(11).fillColor('#64748b').text(k, 56, y, { width: 220 });
    doc.font('Helvetica-Bold').fillColor('#0f172a').text(v, 280, y, { width: 260, align: 'right' });
    doc.moveDown(0.6);
    doc.strokeColor('#f1f5f9').moveTo(56, doc.y).lineTo(540, doc.y).stroke();
    doc.moveDown(0.6);
  }
};

// PDFs are English-only: PDFKit has no Gujarati text shaping.
export const receiptPdf = (society: string, p: { receipt_no: string; flat_id: string | null; amount: number; method: string; title_en: string; created_at: string }) =>
  render(doc => {
    header(doc, society, 'Payment receipt');
    doc.font('Helvetica-Bold').fontSize(28).fillColor('#0f172a').text(inr(p.amount));
    doc.moveDown(1);
    rows(doc, [
      ['Receipt no.', p.receipt_no], ['Flat', p.flat_id ?? '—'], ['For', p.title_en],
      ['Method', { upi: 'UPI', card: 'Card', net: 'Net banking', cash: 'Cash' }[p.method] ?? p.method],
      ['Date', new Date(p.created_at).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', dateStyle: 'medium', timeStyle: 'short' })],
    ]);
    doc.moveDown(2).font('Helvetica').fontSize(9).fillColor('#94a3b8').text('This is a computer-generated receipt and needs no signature.');
  });

export const reportPdf = (society: string, r: {
  periodLabel: string; collected: number; target: number; split: Record<string, number>; fund: number;
  expenses: { title_en: string; category: string; amount: number }[]; defaulters: { flat: string; name: string; amount: number }[];
}) => render(doc => {
  header(doc, society, `Monthly report · ${r.periodLabel}`);
  rows(doc, [
    ['Maintenance collected', `${inr(r.collected)} / ${inr(r.target)}`], ['UPI', inr(r.split.upi ?? 0)],
    ['Card / Net banking', inr(r.split.card ?? 0)], ['Cash', inr(r.split.cash ?? 0)], ['Fund balance', inr(r.fund)],
  ]);
  doc.moveDown(0.5).font('Helvetica-Bold').fontSize(13).fillColor('#0f172a').text('Expenses');
  doc.moveDown(0.5);
  rows(doc, r.expenses.map(e => [`${e.title_en} (${e.category})`, inr(e.amount)]));
  doc.moveDown(0.5).font('Helvetica-Bold').fontSize(13).fillColor('#0f172a').text('Pending dues');
  doc.moveDown(0.5);
  rows(doc, r.defaulters.length ? r.defaulters.map(d => [`${d.flat} · ${d.name}`, inr(d.amount)]) : [['Every flat has paid', '']]);
});

export const placeholderDocPdf = (society: string, name: string) => render(doc => {
  header(doc, society, 'Society document');
  doc.font('Helvetica-Bold').fontSize(16).fillColor('#0f172a').text(name);
  doc.moveDown().font('Helvetica').fontSize(11).fillColor('#475569').text('The committee has not uploaded the original file for this document yet.');
});
