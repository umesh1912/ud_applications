import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/plus-jakarta-sans/latin-400.css';
import '@fontsource/plus-jakarta-sans/latin-500.css';
import '@fontsource/plus-jakarta-sans/latin-600.css';
import '@fontsource/plus-jakarta-sans/latin-700.css';
import '@fontsource/plus-jakarta-sans/latin-800.css';
import './ui/theme.css';
import { PatientApp } from './patient/App';
import { DoctorApp } from './doctor/App';

/** VITE_ROLE picks the app for an Android build; without it, both run side by side for review. */
const role = import.meta.env.VITE_ROLE;

function Viewer() {
  return (
    <div className="viewer">
      <div>
        <div className="label">CareLoop<span>Patient app</span></div>
        <div className="device"><PatientApp storageKey="careloop-viewer-patient" /></div>
      </div>
      <div>
        <div className="label">CareLoop Pro<span>Doctor app</span></div>
        <div className="device"><DoctorApp storageKey="careloop-viewer-doctor" /></div>
      </div>
    </div>
  );
}

document.documentElement.style.background = role === 'doctor' ? '#0e1330' : role === 'patient' ? '#f4f7f6' : '#e8ebf0';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {role === 'patient' ? <PatientApp /> : role === 'doctor' ? <DoctorApp /> : <Viewer />}
  </StrictMode>,
);
