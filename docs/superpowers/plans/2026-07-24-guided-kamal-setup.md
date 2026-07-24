# Guided Kamal Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers-ruby:subagent-driven-development` (recommended) or `superpowers-ruby:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Kamal setup command explain the user’s next safe action while keeping deploy secrets private.

**Architecture:** Keep `bin/setup-kamal` as a small Bash wrapper around existing `bin/deploy-preflight` and `bin/deploy`. In default mode it provides noninteractive validation and guidance. `--apply` delegates to `bin/deploy setup`, which is explicitly the first application deployment in Kamal 2.11. The focused shell test stubs SSH/Kamal and asserts behavior without contacting a host.

**Tech Stack:** Bash, Kamal 2.11, shell test scripts.

---

### Task 1: Define the guided command behavior with tests

**Files:**
- Modify: `test/scripts/setup_kamal_test.sh`

- [ ] **Step 1: Add failing cases for each guided stop.**

  Cover: missing `.env.deploy` tells the user to generate it; missing secret names the missing field and does not call SSH/Kamal; `KAMAL_HOST=shared-kamal-01` tells the user to replace the template host; a group/world-readable environment tells the user to run `chmod 600`; a complete safe environment runs preflight/version and says DNS must be pointed before `--apply`; and `--apply` says it is the first deployment and delegates exactly to setup. Assert neither synthetic secret appears in any output.

- [ ] **Step 2: Run the focused test to verify RED.**

  Run: `bash test/scripts/setup_kamal_test.sh`

  Expected: failure because current guidance either claims setup is non-deploying or lacks the new guided outcomes.

### Task 2: Implement guided validation and truthful deployment messaging

**Files:**
- Modify: `bin/setup-kamal`
- Test: `test/scripts/setup_kamal_test.sh`

- [ ] **Step 1: Implement the smallest guided outcome helpers.**

  Validate the environment path before sourcing it, check permissions without printing contents, reject the known template host, explain the source for each missing required value, and preserve existing preflight/version checks. Make all hints nonsecret. For `--apply`, print a warning that Kamal setup performs the first deployment, then delegate to `bin/deploy setup`; successful default mode tells the operator to manually point DNS before running that command.

- [ ] **Step 2: Run focused validation.**

  Run: `bash -n bin/setup-kamal test/scripts/setup_kamal_test.sh && bash test/scripts/setup_kamal_test.sh`

  Expected: pass.

### Task 3: Align the deployment guide and prior plan

**Files:**
- Modify: `docs/DEPLOY.md`
- Modify: `docs/superpowers/plans/2026-07-24-kamal-setup-helper.md`
- Test: `test/scripts/setup_kamal_test.sh`

- [ ] **Step 1: Correct the operational language.**

  Replace every “setup only, then deploy” claim with the truthful sequence: validate before DNS, manually change DNS, run `bin/setup-kamal --apply` as the first deployment, and use `bin/deploy` for later releases. Explain that the default helper tells the operator which prerequisite needs attention.

- [ ] **Step 2: Run related regression checks.**

  Run: `bash test/scripts/setup_kamal_test.sh && bash test/scripts/deploy_preflight_test.sh && bash test/scripts/deploy_staging_wrapper_test.sh && git diff --check`

  Expected: all pass.

### Task 4: Verify and commit

**Files:**
- Create: `docs/superpowers/specs/2026-07-24-guided-kamal-setup-design.md`
- Create: `docs/superpowers/plans/2026-07-24-guided-kamal-setup.md`
- Modify: files from Tasks 1-3

- [ ] **Step 1: Run the complete repository verification.**

  Run: `for test_file in test/scripts/*_test.sh; do bash "$test_file"; done && bundle check && bin/rails test && git diff --check`

  Expected: all checks pass.

- [ ] **Step 2: Commit the finished implementation.**

  Run: `git add bin/setup-kamal test/scripts/setup_kamal_test.sh docs/DEPLOY.md docs/superpowers/specs/2026-07-24-guided-kamal-setup-design.md docs/superpowers/plans/2026-07-24-kamal-setup-helper.md docs/superpowers/plans/2026-07-24-guided-kamal-setup.md && git commit -m "feat(deploy): Guide initial Kamal deployment"`
