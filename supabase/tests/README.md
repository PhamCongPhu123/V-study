# Database security tests

`security.sql` runs with plain PostgreSQL assertions and throws on the first failure. Every test fixture and helper function is inside a transaction that rolls back. It tests authentication/profile creation, RLS isolation between two users, grants (including TRUNCATE), owner-preserving foreign keys, private file access/path validation, recurring event/checklist atomicity, hidden answer keys, server grading/retry behavior, atomic AI chat, and shared AI concurrency/rate limits.

Against a disposable **local Supabase** instance after `supabase start` and `supabase db reset`:

```sh
psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' \
  -v ON_ERROR_STOP=1 -f supabase/tests/security.sql
```

Never run fixtures against a production project. The fixed UUIDs are intentionally test-only. SQL notice lines begin with `PASS:`; any exception or nonzero runner exit is a failure.

`account_security.sql` adds 20 checks for account profile fields and preferences, including ownership, anonymous access, immutable identity/timestamp, valid dates/avatar presets and preservation of existing details. `npm test --prefix tools` applies all migrations and runs this suite together with the core, quiz and statistics suites in a disposable cluster.

`ai_workspace_security.sql` adds 29 checks for private AI history, owned sources, feedback-only updates, request replay, quiz creation/grading with 40 questions, public learning hints and private grading keys. The full disposable runner now executes 221 assertions across all suites.

## PostgreSQL-only validation

`bootstrap.sql` defines minimal auth/storage schemas for an otherwise empty disposable PostgreSQL 15+ database. It mirrors Supabase broad default table grants, including privileges such as TRUNCATE that RLS does not protect. **Do not execute bootstrap against Supabase**; it is only a local test double.

```sh
createdb vstudy_test
psql -d vstudy_test -v ON_ERROR_STOP=1 \
  -f supabase/tests/bootstrap.sql \
  -f supabase/migrations/202611030001_vstudy.sql \
  -f supabase/tests/security.sql
```

Run under a local superuser that can create the test roles. This validates PostgreSQL schema, constraints, policies, grants and RPC behavior, but does not validate the live Supabase Auth service, Storage MIME enforcement, HTTP API, email or OAuth configuration. The production connection and credentials are not part of these tests.
