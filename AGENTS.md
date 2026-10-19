# AGENTS.md

## Repo
42 school "Inception-of-Things" (IoT) project.

Four self-contained root parts, no shared build/test/lint/CI:
- `p1/` (§IV.1) — Vagrant + VirtualBox, 2 VMs: `deordoneS` (K3s controller,
  192.168.56.110) and `deordoneSW` (K3s agent, 192.168.56.111). Worker token is passed
  through the `/vagrant` synced folder.
- `p2/` (§IV.2) — Vagrant + VirtualBox, 1 VM `deordoneS` running K3s + Traefik.
  `p2/conf/*.yml` are `file`-provisioned to `/home/vagrant/` then `kubectl apply`-ed by
  `p2/script/setup.sh`.
- `p3/` (§IV.3) — Runs on the HOST, not Vagrant (its Vagrantfile was deleted). Installs
  docker + k3d + kubectl + argocd, creates a k3d cluster, Argo CD into `argocd` ns, app
  into `dev` ns.
- `bonus/` (§V) — Host-based; adds Helm + GitLab (`gitlab` ns) and Argo CD on k3d.

## Commands
- p1/p2: `vagrant up` / `vagrant destroy` from inside the part dir. Needs VirtualBox and
  the `ubuntu/jammy64` box; .110/.111 must be free.
- p3: `sudo ./scripts/setup.sh` from `p3/`.
- bonus: `sudo ./scripts/setup.sh` full install; `./scripts/setup.sh run` only starts the
  port-forwards (Argo CD :8181, GitLab :8443) without reinstalling.
- No test/lint/typecheck. Verify with `kubectl get ns`, `kubectl get pods -A`, and `curl`.

## Requirements that drive the code
- Hostnames = 42 login + `S`/`SW` (`deordoneS`, `deordoneSW`); server .110, worker .111.
- p2: `app1.com`->app1, `app2.com`->app2 (3 replicas), default->app3, routed by Traefik.
- p3: app has two tagged versions (v1/v2) on port 8888; Argo CD auto-syncs from the public
  GitHub repo `Droied4/deordone-argoCD` (repo name contains login `deordone`). To redeploy,
  change the image tag in that repo and push. Expect `curl http://localhost:8888/` ->
  `{"status":"ok","message":"v1"}`.
- Bonus is graded only if the mandatory parts are flawless.
- p1/p2 subject says "latest stable version of the distribution of your choice";
  `ubuntu/jammy64` is 22.04 and p1 uses 2 CPU / 2048 MB versus the advised
  1 CPU / 512-1024 MB. Consider `generic/ubuntu2404` and reduced resources.

## VM test harness (planned — tooling only, not part of the submission)
Goal: run p1/p2/p3 entirely inside one lightweight VM created rootlessly with
`qemu:///session`, because the host grants no elevated permissions. Everything except the
harness runs inside that VM, satisfying §III's "whole project in a virtual machine".

- Outer VM: Debian 13 cloud image. Reason: stable repos ship `vagrant`,
  `vagrant-libvirt`, `libvirt` and `qemu`, and it keeps the apt-based scripts working.
  Alpine is rejected as the outer VM: no `vagrant`/`virtualbox` packages and Vagrant is
  glibc-only.
- Networking: usermode (SLIRP). Host reaches the guest only through:
  `virsh -c qemu:///session qemu-monitor-command --hmp iot-test 'hostfwd_add ::2222-:4242'`
  i.e. host:2222 -> guest:4242. Under usermode the host-to-guest address is
  127.0.0.1:2222; `virbr0` only exists for `qemu:///system` NAT and is not used.
- Resources: 8 GiB RAM / 4 vCPU / 40 GiB sparse disk; `doctor.sh` checks host capacity.
- p1/p2 inside the guest: `VAGRANT_DEFAULT_PROVIDER=libvirt`, `IOT_TCG=1`,
  `IOT_BOX=generic/ubuntu2404`, 1024 MiB / 1 vCPU. No KVM means QEMU TCG; p1/p2 are slow
  but functional.
- p3 inside the guest: apt as today, plus root-cause fixes (arch-aware kubectl/argocd
  downloads, bounded waits, working port-forward guard).
- Repo sync: rsync the checkout into `~/iot` in the guest so p3's hardcoded
  `$HOME/iot/...` paths resolve.
- Planned files (new, tooling): `tools/vm/{vm.conf,doctor.sh,create.sh,enter.sh,sync.sh,`
  `run.sh,destroy.sh}`, `tools/vm/cloud-init/{user-data,meta-data}`,
  `tools/vm/guest/{bootstrap.sh,test-p1.sh,test-p2.sh,test-p3.sh,run-tests.sh}`,
  `tools/vm/README.md`, `tools/vm/.gitignore`. All Bash, all following the style rules.

## House style for changes
New and touched code follows the `style` skill: `set -euo pipefail`; every loop bounded
with a max attempt count and timeout; preconditions asserted (`command -v`, non-empty
arguments, free port); every error handled or explicitly ignored; no abbreviations; units
in names (`_mib`, `_gib`, `_seconds`); comments say why, not what; 100 columns; 70 lines
per function; 4-space indentation in shell. Ruby (Vagrantfiles) stays at the idiomatic
2 spaces unless decided otherwise. Verification: `bash -n`, optional `shellcheck`,
`ruby -c`, plus the subject checks.

## Open decisions (resolve before implementation)
1. Outer VM distro: Debian 13 (recommended) vs Alpine (needs containerized Vagrant).
2. Inner box: `generic/ubuntu2404` (latest stable) vs `ubuntu/jammy64` (current).
3. Ruby indentation: 2 (idiomatic, current) vs 4 (style-strict).
4. Bonus/GitLab: in scope, or explicitly excluded (very heavy under TCG).
5. Rename to `scripts/`+`confs/` now, or keep current names and document as pending.

## Folder-name reconciliation (subject wants `scripts/` + `confs/`; repo differs)
The subject's example structure uses `scripts/` and `confs/` per part. Rename if matching
the example exactly; each rename also requires fixing the references listed:
- `p1/server/` -> `p1/scripts/`; update `p1/Vagrantfile:19,28` (`server/setup.sh`).
- `p2/script/` -> `p2/scripts/`; update `p2/Vagrantfile:23` (`script/setup.sh`).
- `p2/conf/` -> `p2/confs/`; update `p2/Vagrantfile:19-22` (`./conf/*.yml` sources).
- `p3/conf/` -> `p3/confs/`; update `p3/scripts/setup.sh:117-118` (`$HOME/iot/p3/conf/*.yml`).
- `bonus/conf/` -> `bonus/confs/`; update `bonus/scripts/setup.sh:104,153,154`
  (`$HOME/iot/bonus/conf/*`). `bonus/scripts/` is already correctly named.
- p3 and bonus intentionally have NO `Vagrantfile` (they are host-based); the subject's
  sample tree shows one but §IV.3 says "without Vagrant". Do not add one.
- Root part names (`p1`, `p2`, `p3`, `bonus`) already match the subject.

## Gotchas
- All provisioning scripts are idempotent (`set -e` + `command -v` / `kubectl get ns`
  guards). Preserve that — re-running must be safe.
- p3 and bonus hardcode `$HOME/iot/...` when applying `conf/*.yml`. If the checkout is not
  at `$HOME/iot`, those applies target nonexistent paths (silently). Symlink to `$HOME/iot`
  or fix the paths.
- p3/bonus need root/Docker on a fresh VM and call `sudo usermod -aG docker` + `newgrp
  docker`; group changes do not apply to the current shell, so later docker/k3d calls may
  require a re-login.
- The `ps aux | grep ...` guard for an existing port-forward is a fragile substring match.
- `.vagrant/` is gitignored per part; `en.subject.pdf` is currently untracked.
- The VM harness uses usermode networking, so inner 192.168.56.x VMs are reachable only
  from inside the outer VM, not from the host.
