// Creates its own disposable cluster. Never connects to a user/production DB.
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';
import { mkdtemp, mkdir, readdir, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const work = await mkdtemp(join(tmpdir(), 'vstudy-sql-'));
const socket = join(work, 'socket');
await mkdir(socket);
const port = 20000 + Math.floor(Math.random() * 30000);
const server = new EmbeddedPostgres({
  databaseDir: join(work, 'data'), user: 'postgres', password: 'disposable-test-only',
  port, persistent: true,
  postgresFlags: ['-k', socket, '-h', ''],
  onLog: () => {}, onError: (message) => console.error(message),
});
let client;
let started = false;
let assertions = 0;
try {
  await server.initialise();
  await server.start();
  started = true;
  client = new pg.Client({host: socket, port, user: 'postgres', password: 'disposable-test-only'});
  await client.connect();
  client.on('notice', notice => {
    if (notice.message?.startsWith('PASS:')) { assertions++; console.log(notice.message); }
  });
  const migrations = (await readdir(join(root, 'supabase/migrations'))).filter(p => p.endsWith('.sql')).sort();
  if (migrations.length === 0) throw new Error('No migrations found');
  const files = ['supabase/tests/bootstrap.sql', ...migrations.map(p => `supabase/migrations/${p}`), 'supabase/tests/security.sql', 'supabase/tests/quiz_security.sql', 'supabase/tests/statistics_security.sql', 'supabase/tests/account_security.sql', 'supabase/tests/ai_workspace_security.sql', 'supabase/tests/document_library_security.sql'];
  for (const path of files) {
    await client.query(await readFile(resolve(root, path), 'utf8'));
    console.log(`Completed ${path}`);
  }
  if (assertions === 0) throw new Error('No SQL assertions executed');
  console.log(`${assertions} SQL assertions passed (disposable PostgreSQL; auth/storage are test doubles).`);
} finally {
  if (client) await client.end();
  if (started) await server.stop();
  await rm(work, {recursive: true, force: true});
}
