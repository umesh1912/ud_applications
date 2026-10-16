import { test } from 'node:test';
import assert from 'node:assert/strict';
import { contrast, darkVariant, fromHex, hueName, oklchToRgb, rgbToOklch, sanitizeName, toHex } from './color.ts';

const hex = (h: string) => fromHex(h)!;
const dark = (h: string, role: Parameters<typeof darkVariant>[1]) => darkVariant(hex(h), role);

test('hex round trip', () => {
  assert.equal(toHex(hex('#3366FF')), '#3366FF');
  assert.equal(toHex(hex('#abc')), '#AABBCC');
  assert.equal(toHex({ r: 0, g: 0, b: 0, a: 0.5 }, true), '#00000080');
  assert.equal(fromHex('nope'), null);
});

test('oklch round trip keeps the colour', () => {
  for (const h of ['#FFFFFF', '#000000', '#3366FF', '#E5484D', '#30A46C', '#777777']) {
    assert.equal(toHex(oklchToRgb(rgbToOklch(hex(h)))), h);
  }
});

test('white page background becomes a dark background', () => {
  const d = dark('#FFFFFF', 'background');
  assert.ok(rgbToOklch(d).l < 0.25);
});

test('light grey cards come out lighter than the page in dark mode (elevation)', () => {
  const page = rgbToOklch(dark('#FFFFFF', 'background')).l;
  const card = rgbToOklch(dark('#F2F2F2', 'background')).l;
  assert.ok(card > page);
});

test('dark text becomes light and readable on the dark page', () => {
  const page = dark('#FFFFFF', 'background');
  for (const t of ['#111111', '#555555', '#888888']) {
    assert.ok(contrast(dark(t, 'text'), page) >= 4.5, `${t} should read on dark`);
  }
});

test('text hierarchy is kept (primary stays brighter than secondary)', () => {
  assert.ok(rgbToOklch(dark('#111111', 'text')).l > rgbToOklch(dark('#666666', 'text')).l);
});

test('white text on a coloured button stays white', () => {
  assert.equal(toHex(dark('#FFFFFF', 'text')), '#FFFFFF');
});

test('brand colours keep their hue', () => {
  const blue = hex('#2563EB');
  for (const role of ['background', 'text', 'border'] as const) {
    const d = darkVariant(blue, role);
    assert.equal(hueName(d), hueName(blue));
  }
});

test('coloured links get readable on the dark page', () => {
  const page = dark('#FFFFFF', 'background');
  assert.ok(contrast(dark('#2563EB', 'text'), page) >= 4.5);
});

test('shadows get stronger', () => {
  const d = darkVariant({ r: 0, g: 0, b: 0, a: 0.1 }, 'shadow');
  assert.ok(d.a > 0.1);
});

test('variable names are made valid', () => {
  assert.equal(sanitizeName(' text / primary.1 '), 'text/primary-1');
  assert.equal(sanitizeName('//'), 'color');
});

import { blend, fixContrast } from './color.ts';

test('blend paints half black over white as mid grey', () => {
  const g = blend({ r: 0, g: 0, b: 0, a: 0.5 }, { r: 1, g: 1, b: 1 });
  assert.equal(toHex(g), '#808080');
});

test('fixContrast reaches the target with the smallest change and keeps the hue', () => {
  const bg = hex('#FFFFFF');
  const fg = hex('#9CA3AF'); // light grey text, about 2.5:1
  const fixed = fixContrast(fg, bg, 4.5)!;
  assert.ok(contrast(fromHex(toHex(fixed))!, bg) >= 4.5);
  assert.ok(rgbToOklch(fixed).l < rgbToOklch(fg).l);
  assert.ok(rgbToOklch(fixed).l > 0.4, 'not pushed all the way to black');
  const blue = fixContrast(hex('#60A5FA'), bg, 4.5)!;
  assert.equal(hueName(blue), 'blue');
  assert.equal(fixContrast(hex('#777777'), hex('#777777'), 21), null);
});
