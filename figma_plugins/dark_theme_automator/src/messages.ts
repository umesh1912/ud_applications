// Messages between the plugin (code.ts) and its window (ui.html).

import type { Role } from '../../shared/color';

export interface Row {
  key: string;
  role: Role;
  name: string;
  lightHex: string;
  darkHex: string;
  count: number;
  existing?: { id: string; name: string; collection: string };
}

export interface RowChoice {
  key: string;
  name: string;
  darkHex: string;
  enabled: boolean;
  // Bind to the matching existing variable instead of creating one.
  link: boolean;
}

export interface ApplySettings {
  // Empty means "create a new collection called collectionName".
  collectionId: string;
  collectionName: string;
  lightName: string;
  darkName: string;
  rows: RowChoice[];
}

export interface CollectionInfo {
  id: string;
  name: string;
  modes: string[];
}

export interface ScanStats {
  layers: number;
  colors: number;
  alreadyBound: number;
  styled: number;
  gradients: number;
}

export type UiMessage =
  | { type: 'ready' }
  | { type: 'scan'; scope: 'selection' | 'page'; includeStyles: boolean }
  | { type: 'dark-base'; value: number }
  | { type: 'apply'; settings: ApplySettings }
  | { type: 'set-mode'; collectionId?: string; mode: string }
  | { type: 'preview-dark'; collectionId?: string; darkName: string }
  | { type: 'export'; collectionId?: string }
  | { type: 'select'; key: string }
  | { type: 'resize'; width: number; height: number };
