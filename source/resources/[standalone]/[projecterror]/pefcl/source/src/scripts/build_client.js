const esbuild = require('esbuild');

esbuild
  .build({
    entryPoints: ['client/client.ts'],
    bundle: true,
    loader: { '.ts': 'ts' },
    minify: true,
    outfile: '../../src/dist/client.js',
  })
  .catch(() => process.exit(1));
