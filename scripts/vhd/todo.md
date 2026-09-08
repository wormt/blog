# vhd.py — build Azure VHD from a nix image.tar

Pipeline: `nix/image.tar -> vhd.py -> image.vhd`

## Python API functions (osbuild v193, pinned in uv.lock)

```python
from osbuild.meta import Index
from osbuild.pipeline import Manifest, Runner
from osbuild.objectstore import ObjectStore
from osbuild.monitor import NullMonitor
```

| Function | Purpose |
| --- | --- |
| `Index(libdir)` | Load stage/source/input/runner modules from a dir |
| `index.detect_host_runner()` | Runner for the build host |
| `Runner(info)` | Wrap a runner |
| `Manifest()` | The build graph |
| `manifest.add_pipeline(name, runner, build_id)` | Add a pipeline; returns `Pipeline` |
| `pipeline.add_stage(module_info, options)` | Add a stage; returns `Stage` |
| `stage.add_input(name, input_info, origin)` | Attach an input; returns `Input` |
| `input.add_reference(ref, options)` | Point input at a pipeline id or source item |
| `manifest.add_source(module_info, items, options)` | Register a source (e.g. curl) |
| `ObjectStore(storedir)` | Cache dir for trees/artifacts |
| `manifest.depsolve(store, [target])` | Ordered pipeline names to build |
| `manifest.build(store, pipelines, monitor, libdir)` | Run it; returns `ManifestBuildResult` |
| `store.get(pipeline.id).export(dest)` | Copy final artifact out |

## Pipelines / stages

1. **`build`** — empty (or `org.osbuild.rpm` if a buildroot is needed; skip for pure tar→vhd, use host runner).
2. **`os`** — one stage:
   - `org.osbuild.untar` — unpack nix tar into tree. Input `file` (type `org.osbuild.files`, origin `org.osbuild.source`, ref = curl source item).
3. **`image`** — two stages:
   - `org.osbuild.truncate` — `{"filename": "image.raw", "size": ...}` creates raw disk.
   - `org.osbuild.qemu` — `{"filename": "image.vhd", "format": {"type": "vpc"}}` converts raw → VHD. Input `image` (type `org.osbuild.files`, origin `org.osbuild.pipeline`, ref `name:image` with `{"file": "image.raw"}`).

## Azure specifics

- Azure wants **VHD (fixed, `vpc` format)**, not VHDX — `qemu-img convert -O vpc -o subformat=fixed,force_size`. The `org.osbuild.qemu` stage does this with `format: {type: "vpc"}`.
- Add `org.osbuild.waagent.conf` stage in the `os` pipeline (Azure Linux Agent config) — the only Azure-specific stage in osbuild.
- Disk must be MBR (`pttype: dos`), single bootable partition, root fs ext4. In v2 format build the partition table yourself with `org.osbuild.truncate` + `org.osbuild.sfdisk` + `org.osbuild.mkfs.ext4` + `org.osbuild.grub2.inst`, then `org.osbuild.qemu` just converts.

## Source for the tar

`org.osbuild.curl` (URL) or `org.osbuild.inline` (local file content):

```python
m.add_source(index.get_module_info("Source", "org.osbuild.curl"),
             {"sha256:...": {"url": "file:///abs/path/image.tar"}}, {})
```

## Minimal skeleton

```python
index = Index(libdir)
host = Runner(index.detect_host_runner())
m = Manifest()

os_pl = m.add_pipeline("os", host, None)
os_pl.add_stage(index.get_module_info("Stage", "org.osbuild.untar"),
                {"prefix": "/"})

image_pl = m.add_pipeline("image", host, None)
image_pl.add_stage(index.get_module_info("Stage", "org.osbuild.truncate"),
                   {"filename": "image.raw", "size": 4 * 1024**3})
qemu = image_pl.add_stage(index.get_module_info("Stage", "org.osbuild.qemu"),
                          {"filename": "image.vhd", "format": {"type": "vpc"}})
qemu.add_input("image", index.get_module_info("Input", "org.osbuild.files"),
               "org.osbuild.pipeline").add_reference(image_pl.id, {"file": "image.raw"})

m.add_source(index.get_module_info("Source", "org.osbuild.curl"),
             {"sha256:...": {"url": "file:///abs/path/image.tar"}}, {})

with ObjectStore(storedir) as store:
    res = m.build(store, m.depsolve(store, ["image"]), NullMonitor(), libdir)
    store.get(m["image"].id).export(outdir)
```

## Gotcha

`libdir` must contain `stages/`, `sources/`, `inputs/`, `runners/`, `schemas/`. The pip package only ships the `osbuild/` Python package — need the repo's module dirs, or the `osbuild` package from nixpkgs (installs to `/usr/lib/osbuild`).

---

## Folding osbuild into the Nix build (goal)

Desire: **fold the whole `image.tar -> image.vhd` pipeline into a single Nix derivation** so the tar is a build-time intermediate and the VHD is the derivation's real output — no human step in the middle.

## The complication (two flakes)

- The `nix/` flake (nix-caliga) produces `config.build.image` — but that is a **streaming *script*** (`dockerTools.streamLayeredImage`), **not** the tar. The justfile runs `./result > nix/image.tar` at the shell level, outside Nix.
- So the tar is **not a derivation output** — it only exists after executing a script on the machine. A downstream derivation cannot depend on it.
- The tar lives in a **different flake** (`nix/`) than the osbuild uv2nix env (root `flake.nix`). Two flakes, two locks, no linkage.
- `.gitignore` already ignores `*.tar`, `*.qcow2`, `result` — no pollution.

## Fix 1 — make the tar a derivation output (in `nix/flake.nix`)

`streamLayeredImage` is pure and sandbox-safe, so wrap it:

```nix
outputs = { ... }@inputs:
  let
    caliga = inputs.nix-caliga.lib.makeCaligaConfigurations {
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      specialArgs = { inherit inputs; };
      modules = [ ./images/edge ./images/edge/users ./images/edge/services ];
    };
    edge = caliga.x86_64-linux.edge;
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    imageTar = pkgs.runCommand "image.tar" { } ''
      ${edge.config.build.image} > $out/image.tar
      chmod +w $out/image.tar
    '';
  in {
    inherit caliga; # keeps `caligaConfigurations.x86_64-linux.edge...` working
    packages.x86_64-linux.imageTar = imageTar;
  };
```

Now `nix build nix#packages.x86_64-linux.imageTar` yields a store path containing the real tar; any derivation can depend on it. The tar never hits the filesystem (except as `result` symlink / store path).

## Fix 2 — root flake pulls in `nix/` as a path input

Root flake already has the uv2nix `vhdEnv`; declare the other flake as an input:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  wormtpkgs.url = "github:wormt/nixpkgs";
  # ... existing ...
  nix-image = { url = "path:./nix"; flake = true; };  # <-- separate flake becomes an input
};
```

```nix
imageTar = nix-image.packages.${system}.imageTar;

vhd = pkgs.runCommand "image.vhd" {
  __noChroot = true; # osbuild needs mount/loop/root
  nativeBuildInputs = [ vhdEnv pkgs.qemu pkgs.util-linux ...osbuild module dirs... ];
  sourceRoot = ./scripts/vhd;
} ''
  python ${./scripts/vhd/vhd.py} ${imageTar}/image.tar $out/image.vhd
'';
```

`justfile` collapses to:

```just
build-vhd:
 nix build .#packages.x86_64-linux.vhd
```

One derivation, tar in, VHD out, no human step in the middle.

## The wall that is *not* the flake

The flake split is solved. The real obstacle remains: **osbuild needs root + loop devices + mounts**, which a normal Nix sandbox forbids. `__noChroot = true` only means "no chroot" — the builder still runs as the unprivileged `nixbld` user unless a root daemon is used. osbuild re-execs into a user namespace when rootless, so `unshare` capability is required. Host is stubby/ostree with a read-only root — that is where the effort goes.
