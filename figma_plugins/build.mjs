// Builds src/code.ts of every plugin folder into its code.js (the file Figma loads).
// node build.mjs [--watch] [plugin_folder ...]
import * as esbuild from 'esbuild';
import { existsSync, readdirSync } from 'node:fs';

const args = process.argv.slice(2);
const watch = args.includes('--watch');
const only = args.filter((a) => !a.startsWith('--'));
const plugins = (only.length ? only : readdirSync('.')).filter((d) => existsSync(`${d}/manifest.json`));

for (const dir of plugins) {
  const options = {
    entryPoints: [`${dir}/src/code.ts`],
    outfile: `${dir}/code.js`,
    bundle: true,
    target: 'es2017',
    logLevel: 'info',
  };
  if (watch) await (await esbuild.context(options)).watch();
  else await esbuild.build(options);
}
