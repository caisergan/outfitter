#!/usr/bin/env node
// Loads admin/.env* into process.env BEFORE Next.js's CLI parses args, so
// `PORT=...` in .env.local actually changes the dev/start bind port.
// Without this wrapper, Next's commander reads process.env.PORT during arg
// parsing, which runs before its own .env loader populates the variable.

const path = require('node:path');
const { loadEnvConfig } = require('@next/env');

const projectDir = path.resolve(__dirname, '..');
loadEnvConfig(projectDir);

require(require.resolve('next/dist/bin/next', { paths: [projectDir] }));
