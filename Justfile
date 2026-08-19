DISK_SIZE  := "10G"
VM_NAME    := "edge-blog"
BCVK_PATH  := "/tmp/bcvk-build/target/release/bcvk"
IMAGE_URL  := "ghcr.io/wormt"
IMAGE_NAME := "edge"
IMAGE_TAG  := "latest"

build:
	distrobox enter fedora -- nix build /home/asv/workspaces/roc/blog/nix#caligaConfigurations.x86_64-linux.edge.config.build.image --refresh --repair
	@echo "[build] image built → nix/image.tar"

qcow:
	{{BCVK_PATH}} to-disk {{IMAGE_URL}}/{{IMAGE_NAME}}:{{IMAGE_TAG}} nix/{{IMAGE_NAME}}.qcow2 --format=qcow2 --disk-size={{DISK_SIZE}}

vm:
	{{BCVK_PATH}} ephemeral run nix/{{IMAGE_NAME}}.qcow2 --rm --name={{VM_NAME}} --detach --console --replace

build-qcow-vm: build qcow vm
	@echo "VM {{VM_NAME}} running"

build-qcow: build qcow
	@echo "nix/{{IMAGE_NAME}}.qcow2 ready"
