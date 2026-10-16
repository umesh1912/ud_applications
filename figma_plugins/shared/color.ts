// Colour maths for the dark theme: sRGB <-> OKLCH, and the light -> dark mapping.
// Pure functions, no Figma API, so they can be unit tested in Node.

export type Role = 'background' | 'text' | 'icon' | 'border' | 'shadow';

export interface RGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}

export interface Oklch {
  l: number;
  c: number;
  h: number;
}

// Below this chroma a colour counts as a neutral (white, black, grey).
export const NEUTRAL_CHROMA = 0.04;

// How dark the darkest dark-mode background is (OKLCH lightness).
// 0.18 is close to #121212, 0.24 close to #1E1E1E, 0 is true black.
export const DEFAULT_DARK_BASE = 0.18;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

const toLinear = (c: number) => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
const fromLinear = (c: number) => (c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);

export function rgbToOklch({ r, g, b }: { r: number; g: number; b: number }): Oklch {
  const lr = toLinear(r);
  const lg = toLinear(g);
  const lb = toLinear(b);
  const l_ = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  const m_ = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  const s_ = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  const L = 0.2104542553 * l_ + 0.793617785 * m_ - 0.0040720468 * s_;
  const A = 1.9779984951 * l_ - 2.428592205 * m_ + 0.4505937099 * s_;
  const B = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.808675766 * s_;
  const c = Math.sqrt(A * A + B * B);
  let h = (Math.atan2(B, A) * 180) / Math.PI;
  if (h < 0) h += 360;
  return { l: L, c, h };
}

function oklchToLinear({ l, c, h }: Oklch): [number, number, number] {
  const hr = (h * Math.PI) / 180;
  const A = c * Math.cos(hr);
  const B = c * Math.sin(hr);
  const l_ = Math.pow(l + 0.3963377774 * A + 0.2158037573 * B, 3);
  const m_ = Math.pow(l - 0.1055613458 * A - 0.0638541728 * B, 3);
  const s_ = Math.pow(l - 0.0894841775 * A - 1.291485548 * B, 3);
  return [
    4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
    -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
    -0.0041960863 * l_ - 0.7034186147 * m_ + 1.707614701 * s_,
  ];
}

const inGamut = (rgb: [number, number, number]) => rgb.every((v) => v >= -0.0001 && v <= 1.0001);

// Converts back to sRGB, lowering chroma until the colour fits (keeps hue and lightness).
export function oklchToRgb(color: Oklch): { r: number; g: number; b: number } {
  let { l, c, h } = color;
  l = clamp(l, 0, 1);
  let lin = oklchToLinear({ l, c, h });
  if (!inGamut(lin)) {
    let lo = 0;
    let hi = c;
    for (let i = 0; i < 24; i++) {
      const mid = (lo + hi) / 2;
      if (inGamut(oklchToLinear({ l, c: mid, h }))) lo = mid;
      else hi = mid;
    }
    lin = oklchToLinear({ l, c: lo, h });
  }
  const [r, g, b] = lin.map((v) => clamp(fromLinear(clamp(v, 0, 1)), 0, 1));
  return { r, g, b };
}

const hex2 = (v: number) => Math.round(clamp(v, 0, 1) * 255).toString(16).padStart(2, '0');

export function toHex(c: { r: number; g: number; b: number; a?: number }, withAlpha = false): string {
  const base = `#${hex2(c.r)}${hex2(c.g)}${hex2(c.b)}`.toUpperCase();
  return withAlpha && c.a !== undefined && c.a < 1 ? base + hex2(c.a).toUpperCase() : base;
}

export function fromHex(hex: string): RGBA | null {
  let h = hex.trim().replace(/^#/, '');
  if (h.length === 3 || h.length === 4) h = h.split('').map((ch) => ch + ch).join('');
  if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(h)) return null;
  const n = (i: number) => parseInt(h.slice(i, i + 2), 16) / 255;
  return { r: n(0), g: n(2), b: n(4), a: h.length === 8 ? n(6) : 1 };
}

export function isNeutral(c: { r: number; g: number; b: number }): boolean {
  return rgbToOklch(c).c < NEUTRAL_CHROMA;
}

// Relative luminance and contrast ratio as defined by WCAG 2.
export function luminance({ r, g, b }: { r: number; g: number; b: number }): number {
  return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
}

export function contrast(a: { r: number; g: number; b: number }, b: { r: number; g: number; b: number }): number {
  const la = luminance(a);
  const lb = luminance(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// Maps a light-theme lightness of a "surface" (background or border) onto the dark scale.
// White lands on the dark base; slightly darker light surfaces (cards, wells) come out
// slightly lighter, which is how elevation reads in a dark UI.
function surfaceLightness(l: number, base: number, spread: number): number {
  return clamp(base + (1 - l) * spread, 0, 0.6);
}

// Dark text: black becomes near-white, mid grey becomes light grey, keeping the order.
function foregroundLightness(l: number): number {
  return clamp(0.96 - l * 0.45, 0.6, 0.97);
}

/**
 * Picks the dark-mode value for a colour used in the light design.
 * The role matters: white as a page background becomes dark, but white text on a
 * blue button stays white, so the same hex can need two different dark values.
 */
export function darkVariant(color: RGBA, role: Role, darkBase = DEFAULT_DARK_BASE): RGBA {
  const { l, c, h } = rgbToOklch(color);
  const neutral = c < NEUTRAL_CHROMA;
  let L = l;
  let C = c;
  let a = color.a;

  switch (role) {
    case 'background':
      if (neutral) {
        // Dark blocks in a light design (tooltips, dark buttons) only lift a little.
        L = l >= 0.5 ? surfaceLightness(l, darkBase, 1.5) : Math.max(l, darkBase + 0.12);
      } else if (l >= 0.85) {
        // Pale tints (chips, alerts, selected rows) become deep tints of the same hue.
        L = surfaceLightness(l, darkBase, 1.5) + 0.06;
        C = Math.min(c * 1.4, 0.07);
      } else {
        // Brand fills (primary buttons) stay recognisable, slightly calmer.
        L = clamp(l + 0.04, 0.45, 0.75);
        C = c * 0.9;
      }
      break;
    case 'border':
      if (neutral) L = l >= 0.5 ? surfaceLightness(l, darkBase, 1.6) : clamp(1 - l * 0.8, 0.6, 0.9);
      else {
        L = clamp(Math.max(l, 0.6), 0.6, 0.8);
        C = c * 0.85;
      }
      break;
    case 'text':
    case 'icon':
      if (neutral) {
        // Light text in a light design sits on a dark or coloured fill: keep it light.
        L = l > 0.6 ? l : foregroundLightness(l);
      } else if (l <= 0.85) {
        // Coloured text and links need to be lighter to read on a dark background.
        L = clamp(Math.max(l + 0.12, 0.72), 0.72, 0.88);
        C = c * 0.85;
      }
      break;
    case 'shadow':
      // Shadows stay dark but need more opacity to show on dark surfaces.
      L = Math.min(l, 0.1);
      a = clamp(color.a * 1.6, 0, 0.9);
      break;
  }

  return { ...oklchToRgb({ l: L, c: C, h }), a };
}

const HUES: Array<[number, string]> = [
  [20, 'pink'],
  [45, 'red'],
  [70, 'orange'],
  [100, 'yellow'],
  [150, 'lime'],
  [175, 'green'],
  [215, 'teal'],
  [270, 'blue'],
  [305, 'indigo'],
  [345, 'purple'],
  [360, 'pink'],
];

export function hueName(c: { r: number; g: number; b: number }): string {
  const { h } = rgbToOklch(c);
  for (const [limit, name] of HUES) if (h < limit) return name;
  return 'pink';
}

const ORDINALS = ['primary', 'secondary', 'tertiary', 'quaternary'];
export const ordinal = (i: number) => ORDINALS[i] ?? `level-${i + 1}`;

// Figma variable names cannot contain "." "{" "}" and "/" separates groups.
export function sanitizeName(name: string): string {
  return (
    name
      .replace(/[.{}]/g, '-')
      .split('/')
      .map((p) => p.trim())
      .filter(Boolean)
      .join('/') || 'color'
  );
}

// Paints a (semi-transparent) colour over an opaque one.
export function blend(top: RGBA, bottom: { r: number; g: number; b: number }): { r: number; g: number; b: number } {
  const a = clamp(top.a, 0, 1);
  return {
    r: top.r * a + bottom.r * (1 - a),
    g: top.g * a + bottom.g * (1 - a),
    b: top.b * a + bottom.b * (1 - a),
  };
}

/**
 * The colour closest to `fg` (same hue and chroma, only lightness moves) that reaches
 * `target` contrast on `bg`. Returns null if no lightness can reach it.
 */
export function fixContrast(
  fg: { r: number; g: number; b: number },
  bg: { r: number; g: number; b: number },
  target: number
): { r: number; g: number; b: number } | null {
  if (contrast(fg, bg) >= target) return { ...fg };
  const { l, c, h } = rgbToOklch(fg);
  let best: { rgb: { r: number; g: number; b: number }; dist: number } | null = null;
  for (let i = 0; i <= 400; i++) {
    const L = i / 400;
    const rgb = oklchToRgb({ l: L, c, h });
    // Small margin so rounding to 8-bit hex never drops it below the target.
    if (contrast(rgb, bg) >= target + 0.02 && (!best || Math.abs(L - l) < best.dist)) best = { rgb, dist: Math.abs(L - l) };
  }
  return best ? best.rgb : null;
}
