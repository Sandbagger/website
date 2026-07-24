# Kamal Setup Helper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers-ruby:subagent-driven-development` (recommended) or `superpowers-ruby:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe, repeatable command for guided validation of Kamal prerequisites and a deliberate first production deployment.

**Architecture:** `bin/setup-kamal` will load the existing gitignored deploy environment, ensure the four required handoff values exist without displaying them, run the existing durable-host preflight, and verify Kamal is available. Its default mode is guided validation that names a missing prerequisite and the exact next action. `--apply` delegates to `bin/deploy setup` (`kamal setup`), which itself performs the initial application deployment. Later releases use `bin/deploy`.

**Tech Stack:** Bash, existing deploy/preflight scripts, shell test scripts.

---

### Task 1: Specify safe setup behavior

**Files:**
- Create: `test/scripts/setup_kamal_test.sh`

- [ ] **Step 1: Write the failing test.**

  Stub `ssh` and `bundle`, provide a temporary deploy environment containing `KAMAL_HOST`, `APP_SHARED_ROOT`, `KAMAL_REGISTRY_PASSWORD`, and `RAILS_MASTER_KEY`, then run `bin/setup-kamal`. Assert that it runs preflight and `bundle exec kamal version`, does not invoke setup or deploy, and does not print either secret. Run `bin/setup-kamal --apply` and assert it delegates to `bin/deploy setup` (`kamal setup`), which itself performs the initial application deployment. Finally, omit the two secret variables and assert the helper names the missing variables and the next action without running `ssh` or `bundle` and without printing a secret value. Pass an unexpected argument and assert it is rejected before any external command runs.

- [ ] **Step 2: Verify the test fails.**

  Run: `bash test/scripts/setup_kamal_test.sh`

  Expected: failure because `bin/setup-kamal` does not exist.

### Task 2: Implement the setup helper

**Files:**
- Create: `bin/setup-kamal`
- Test: `test/scripts/setup_kamal_test.sh`

- [ ] **Step 1: Add the minimal helper.**

  Accept no arguments for validation mode and `--apply` for the initial deployment mode; reject any other argument. Load `DEPLOY_ENV_FILE` or `.env.deploy`; fail with named missing variables and their next action but never their values. Run `bin/deploy-preflight` and `bundle exec kamal version`. For `--apply`, delegate to `bin/deploy setup` (`kamal setup`), which itself performs the initial application deployment; otherwise print the next command.

- [ ] **Step 2: Verify the test passes.**

  Run: `bash test/scripts/setup_kamal_test.sh`

  Expected: pass.

### Task 3: Document the operator workflow

**Files:**
- Modify: `docs/DEPLOY.md`

- [ ] **Step 1: Replace the bootstrap commands.**

  Document `bin/setup-kamal` for guided validation, including its missing-prerequisite next action, and `bin/setup-kamal --apply` as a delegation to `bin/deploy setup` (`kamal setup`), which itself performs the initial application deployment. Document `bin/deploy` for later releases. Update the guarded-cutover checklist to use the same `bin/setup-kamal --apply` command only after a separate, manual production DNS change is publicly resolved to the Hetzner host. State that the helper neither provisions Hetzner nor changes DNS, and never asks for or prints secrets.

- [ ] **Step 2: Run the relevant regression checks.**

  Run: `bash test/scripts/setup_kamal_test.sh && bash test/scripts/deploy_preflight_test.sh && bash test/scripts/deploy_staging_wrapper_test.sh && git diff --check`

  Expected: all commands succeed.

- [ ] **Step 3: Commit the completed change.**

  Run: `git add bin/setup-kamal test/scripts/setup_kamal_test.sh docs/DEPLOY.md docs/superpowers/plans/2026-07-24-kamal-setup-helper.md && git commit -m "feat(deploy): Add Kamal setup helper"`
