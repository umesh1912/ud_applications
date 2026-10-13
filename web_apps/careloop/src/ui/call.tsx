import { useEffect, useState } from 'react';
import { Avatar, Icon } from './kit';

/**
 * Video visit screen. The remote video is a placeholder tile (a real build plugs in a WebRTC
 * provider such as Twilio, Agora or 100ms); timer, mute/camera/speaker state and chat are live.
 */
export function CallScreen({ name, sub, hue, selfName, onEnd, sidePanel, sideLabel }: {
  name: string;
  sub: string;
  hue: number;
  selfName: string;
  onEnd: (seconds: number) => void;
  /** Optional panel (doctor: consult notes) toggled from the controls. */
  sidePanel?: React.ReactNode;
  sideLabel?: string;
}) {
  const [secs, setSecs] = useState(0);
  const [mic, setMic] = useState(true);
  const [cam, setCam] = useState(true);
  const [speaker, setSpeaker] = useState(true);
  const [panel, setPanel] = useState(false);
  const [connecting, setConnecting] = useState(true);

  useEffect(() => {
    const c = window.setTimeout(() => setConnecting(false), 1400);
    const id = window.setInterval(() => setSecs((s) => s + 1), 1000);
    return () => { window.clearTimeout(c); window.clearInterval(id); };
  }, []);

  const mm = String(Math.floor(secs / 60)).padStart(2, '0');
  const ss = String(secs % 60).padStart(2, '0');

  return (
    <div className="call">
      <div className="remote">
        <div className="stack center gap-12" style={{ textAlign: 'center' }}>
          <div className={connecting ? '' : 'pulse'} style={{ borderRadius: '50%' }}>
            <Avatar name={name} hue={hue} size={120} />
          </div>
          <div className="t-h2" style={{ color: '#fff' }}>{name}</div>
          <div style={{ fontSize: 13.5, color: 'rgba(255,255,255,.7)' }}>{connecting ? 'Connecting securely…' : sub}</div>
        </div>
        <div style={{ position: 'absolute', top: 18, left: 16, right: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span className="hero-pill"><Icon name="Lock" size={13} />End-to-end encrypted</span>
          <span className="hero-pill num" style={{ background: connecting ? 'rgba(255,255,255,.16)' : '#ef4444' }}>
            {!connecting && <span style={{ width: 7, height: 7, borderRadius: 4, background: '#fff' }} />}{mm}:{ss}
          </span>
        </div>
        <div className="self">
          {cam ? <Avatar name={selfName} hue={210} size={52} /> : <Icon name="VideoOff" size={26} style={{ opacity: 0.7 }} />}
          {!mic && <span style={{ position: 'absolute', bottom: 8, right: 8, background: '#ef4444', borderRadius: 8, padding: 3, display: 'flex' }}><Icon name="MicOff" size={12} /></span>}
        </div>
        {panel && sidePanel && (
          <div style={{ position: 'absolute', left: 12, right: 12, bottom: 12, maxHeight: '58%', overflowY: 'auto', background: '#fff', color: 'var(--ink)', borderRadius: 22, padding: 16, animation: 'sheet-up 240ms' }}>
            {sidePanel}
          </div>
        )}
      </div>
      <div className="controls">
        <button className={mic ? '' : 'off'} onClick={() => setMic(!mic)} aria-label="Microphone"><Icon name={mic ? 'Mic' : 'MicOff'} size={22} /></button>
        <button className={cam ? '' : 'off'} onClick={() => setCam(!cam)} aria-label="Camera"><Icon name={cam ? 'Video' : 'VideoOff'} size={22} /></button>
        <button className="end" onClick={() => onEnd(secs)} aria-label="End call"><Icon name="PhoneOff" size={24} /></button>
        {sidePanel ? (
          <button className={panel ? 'off' : ''} onClick={() => setPanel(!panel)} aria-label={sideLabel}><Icon name="NotebookPen" size={22} /></button>
        ) : (
          <button className={speaker ? '' : 'off'} onClick={() => setSpeaker(!speaker)} aria-label="Speaker"><Icon name={speaker ? 'Volume2' : 'VolumeX'} size={22} /></button>
        )}
      </div>
    </div>
  );
}
