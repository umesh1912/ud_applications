import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/plus-jakarta-sans/latin-400.css';
import '@fontsource/plus-jakarta-sans/latin-500.css';
import '@fontsource/plus-jakarta-sans/latin-600.css';
import '@fontsource/plus-jakarta-sans/latin-700.css';
import '@fontsource/plus-jakarta-sans/latin-800.css';
import './ui/theme.css';
import { ROLE } from './lib/role';
import { AuthProvider } from './lib/auth';
import { PatientApp } from './patient/App';
import { DoctorApp } from './doctor/App';

/** Dev only: both apps side by side, each in its own frame with its own sign-in. */
function Viewer() {
  const q = location.search.includes('emulator') ? '&emulator' : '';
  return (
    <div className="viewer">
      {(['patient', 'doctor'] as const).map((r) => (
        <div key={r}>
          <div className="label">{r === 'patient' ? 'CareLoop' : 'CareLoop Pro'}<span>{r === 'patient' ? 'Patient app' : 'Doctor app'}</span></div>
          <div className="device"><iframe title={r} src={`?app=${r}${q}`} style={{ width: '100%', height: '100%', border: 0, borderRadius: 44, background: '#fff' }} /></div>
        </div>
      ))}
    </div>
  );
}

document.documentElement.style.background = ROLE === 'doctor' ? '#0e1330' : ROLE === 'patient' ? '#f4f7f6' : '#e8ebf0';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {ROLE === 'viewer' ? <Viewer /> : (
      <AuthProvider>
        {ROLE === 'patient' ? <PatientApp /> : <DoctorApp />}
      </AuthProvider>
    )}
  </StrictMode>,
);
