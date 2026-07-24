# Guided Kamal Setup Design

## Goal

Make `bin/setup-kamal` a safe, beginner-friendly first-deployment guide. It
must explain the next action whenever a prerequisite is missing, while never
asking for or printing deploy secrets.

## Command contract

`bin/setup-kamal` has two modes:

1. **Guided validation (default).** It checks `.env.deploy`, validates the
   four required values, rejects the checked-in template host, rejects a
   group/world-readable deploy environment, runs the existing host preflight,
   and confirms Kamal is installed. It prints the next exact command after
   each outcome.
2. **First deployment (`--apply`).** After the same checks, it delegates to
   `bin/deploy setup`. In Kamal 2.11, `setup` bootstraps Docker if required
   and performs the application's first deployment. The command says this
   plainly; it is only appropriate after the user has manually pointed DNS to
   the Hetzner host and ports 80/443 are reachable.

Unexpected arguments fail with usage before checking files, connecting to the
host, or running Kamal.

## Guided outcomes

| Situation | Safe next step shown |
| --- | --- |
| `.env.deploy` is absent | Generate it with `dotfiles-hetzner-tf handoff website --format env > .env.deploy`, then fill its blank secrets. |
| Required values missing | Identify each field and its source: host from the Hetzner handoff, durable root stays `/srv/apps/website/shared`, registry password from the GitHub Packages token in 1Password, Rails key from the production credentials key in 1Password. |
| Template host remains | Replace `shared-kamal-01` with the Hetzner host/IP from the handoff. |
| Insecure permissions | Run `chmod 600 .env.deploy`. |
| All local checks and host preflight pass | Point DNS manually (if not already done), then run `bin/setup-kamal --apply`; explain that this is the first deployment. |
| First deployment succeeds | State that later releases use `bin/deploy`. |

The helper does not provision Hetzner, modify DNS, create secrets, or persist
values. It does not print the deploy environment or its secret values.

## Validation and tests

The shell test will cover the missing-file guidance, a missing secret that
short-circuits SSH/Kamal, placeholder-host rejection, unsafe-permission
rejection, successful guided validation, the exact `--apply` delegation, and
unexpected arguments. Every output path will assert that synthetic secrets do
not appear.

Documentation will distinguish validation from the actual first deployment:
after manual DNS cutover, `bin/setup-kamal --apply` is the one initial Kamal
command; `bin/deploy` is for later releases.
