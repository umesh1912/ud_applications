// Spacing and radius scales: snapping values onto a scale and naming the tokens.
// Pure functions so they can be unit tested.

export type Kind = 'spacing' | 'radius';
export type Naming = 'number' | 'tshirt';

export const FULL = 9999;

export const SPACING_SCALES: Record<4 | 8, number[]> = {
  4: [2, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96, 128],
  8: [4, 8, 16, 24, 32, 40, 48, 64, 80, 96, 128],
};

export const RADIUS_SCALE = [2, 4, 6, 8, 10, 12, 16, 20, 24, 32, FULL];

// Nearest scale value; ties go to the larger one. Values past the end of the scale
// are kept as they are (rounded), since a big hero padding is usually deliberate.
export function snap(value: number, scale: number[]): number {
  const finite = scale.filter((v) => v !== FULL);
  const max = finite[finite.length - 1];
  if (value > max * 1.25) return Math.round(value);
  let best = finite[0];
  for (const v of finite) if (Math.abs(v - value) <= Math.abs(best - value)) best = v;
  return best;
}

// A corner that is half the short side (or more) makes a pill or circle.
export function isPill(radius: number, width: number, height: number): boolean {
  return radius >= Math.min(width, height) / 2 - 0.5;
}

const SIZES_UP = ['md', 'lg', 'xl', '2xl', '3xl', '4xl', '5xl', '6xl', '7xl', '8xl', '9xl'];
const SIZES_DOWN = ['sm', 'xs', '2xs', '3xs', '4xs', '5xs'];

// Token names for a sorted list of values. T-shirt sizes put "md" at the value
// closest to `middle` (16 for spacing, 8 for radius).
export function tokenNames(kind: Kind, values: number[], naming: Naming): Map<number, string> {
  const names = new Map<number, string>();
  const sorted = [...new Set(values)].sort((a, b) => a - b);
  const finite = sorted.filter((v) => v !== FULL);
  if (sorted.includes(FULL)) names.set(FULL, `${kind}/full`);
  if (naming === 'number' || !finite.length) {
    for (const v of finite) names.set(v, `${kind}/${String(v).replace('.', '_')}`);
    return names;
  }
  const middle = kind === 'spacing' ? 16 : 8;
  let mid = 0;
  finite.forEach((v, i) => {
    if (Math.abs(v - middle) < Math.abs(finite[mid] - middle)) mid = i;
  });
  finite.forEach((v, i) => {
    const d = i - mid;
    const label = d >= 0 ? SIZES_UP[d] ?? `${d + 1}xl` : SIZES_DOWN[-d - 1] ?? `${-d}xs`;
    names.set(v, `${kind}/${label}`);
  });
  return names;
}
