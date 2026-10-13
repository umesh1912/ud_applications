import { useState } from 'react';

/**
 * Single-series bar chart (one hue, so no legend; the title names the series).
 * Thin bars with 4px rounded tops on a recessive baseline; tap a bar for its value.
 */
export function BarChart({ data, format, height = 150 }: { data: { label: string; value: number }[]; format: (v: number) => string; height?: number }) {
  const [sel, setSel] = useState<number>(data.length - 1);
  const max = Math.max(...data.map((d) => d.value), 1);
  const W = 320, H = height, top = 28, bottom = 22, gap = 2;
  const slot = W / data.length;
  const bw = Math.min(26, slot * 0.56);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label="Earnings by day" style={{ display: 'block', overflow: 'visible' }}>
      {[0.5, 1].map((f) => (
        <line key={f} x1={0} x2={W} y1={top + (H - top - bottom) * (1 - f)} y2={top + (H - top - bottom) * (1 - f)} stroke="var(--line)" strokeDasharray="3 4" />
      ))}
      <line x1={0} x2={W} y1={H - bottom} y2={H - bottom} stroke="var(--line)" />
      {data.map((d, i) => {
        const h = Math.max(2, ((H - top - bottom) * d.value) / max);
        const x = slot * i + (slot - bw) / 2;
        const y = H - bottom - h;
        const on = i === sel;
        return (
          <g key={d.label} onClick={() => setSel(i)} style={{ cursor: 'pointer' }}>
            <rect x={slot * i} y={top - 20} width={slot} height={H - top + 20} fill="transparent" />
            <path
              d={`M${x},${H - bottom - gap / 2} V${y + 4} Q${x},${y} ${x + 4},${y} H${x + bw - 4} Q${x + bw},${y} ${x + bw},${y + 4} V${H - bottom - gap / 2} Z`}
              fill="var(--brand)"
              opacity={on ? 1 : 0.38}
            />
            <text x={x + bw / 2} y={H - 5} textAnchor="middle" fontSize="11" fontWeight={on ? 800 : 600} fill={on ? 'var(--ink)' : 'var(--muted)'}>{d.label}</text>
            {on && (
              <g>
                <rect x={Math.min(Math.max(x + bw / 2 - 38, 0), W - 76)} y={y - 30} width={76} height={22} rx={7} fill="var(--ink)" />
                <text x={Math.min(Math.max(x + bw / 2, 38), W - 38)} y={y - 15} textAnchor="middle" fontSize="11.5" fontWeight={700} fill="#fff">{format(d.value)}</text>
              </g>
            )}
          </g>
        );
      })}
    </svg>
  );
}

/** Small 2px trend line for a vital sign; the last point is marked and labelled. */
export function Sparkline({ values, width = 120, height = 40, color = 'var(--brand)' }: { values: number[]; width?: number; height?: number; color?: string }) {
  const min = Math.min(...values), max = Math.max(...values);
  const pad = 5;
  const pts = values.map((v, i) => [
    pad + (i * (width - pad * 2)) / (values.length - 1),
    pad + (height - pad * 2) * (1 - (v - min) / (max - min || 1)),
  ]);
  const [lx, ly] = pts[pts.length - 1];
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden style={{ display: 'block' }}>
      <polyline points={pts.map((p) => p.join(',')).join(' ')} fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={lx} cy={ly} r={4} fill={color} stroke="var(--surface)" strokeWidth={2} />
    </svg>
  );
}
