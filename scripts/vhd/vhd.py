"""Build a fixed Azure VHD from a bootc container archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import shutil
import subprocess  # ruff: ignore[suspicious-subprocess-import] -- skopeo is invoked without a shell.
import tarfile
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING, Any, cast

from osbuild.meta import Index, ModuleInfo
from osbuild.monitor import NullMonitor
from osbuild.objectstore import ObjectStore
from osbuild.pipeline import Manifest, ManifestBuildResult, Pipeline, Runner

if TYPE_CHECKING:
    from collections.abc import Iterator, Sequence

LOGGER = logging.getLogger(__name__)

SECTOR_SIZE = 512
PARTITION_START = 2048
DEFAULT_DISK_SIZE = 10 * 1024**3
DISK_UUID = '0x7b7795e7'
ROOT_UUID = '156f0420-627b-4151-ae6f-fda298097515'
DEFAULT_IMAGE_NAME = 'localhost/nix-image:latest'


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments.

    Args:
        argv: Arguments to parse, excluding the program name.

    Returns:
        The parsed arguments.
    """
    parser = argparse.ArgumentParser(
        description='Build a fixed Azure VHD from a bootc container archive.'
    )
    parser.add_argument(
        'tarball', type=Path, help='Docker or OCI bootc image archive'
    )
    parser.add_argument('output', type=Path, help='destination image.vhd path')
    parser.add_argument(
        '--libdir',
        type=Path,
        default=Path('/usr/lib/osbuild'),
        help='osbuild module directory (default: /usr/lib/osbuild)',
    )
    parser.add_argument(
        '--store',
        type=Path,
        help='persistent osbuild object store (default: temporary directory)',
    )
    parser.add_argument(
        '--size',
        type=int,
        default=DEFAULT_DISK_SIZE,
        help=f'raw disk size in bytes (default: {DEFAULT_DISK_SIZE})',
    )
    parser.add_argument(
        '--target-imgref',
        help='container reference recorded for subsequent bootc updates',
    )
    parser.add_argument(
        '--skopeo',
        default='skopeo',
        help='skopeo executable used for Docker archives (default: skopeo)',
    )
    return parser.parse_args(argv)


def validate_paths(tarball: Path, output: Path, libdir: Path) -> None:
    """Validate the input, output, and osbuild module paths.

    Args:
        tarball: Input container archive.
        output: Destination VHD path.
        libdir: osbuild module directory.

    Raises:
        ValueError: If an argument cannot be used.
    """
    if not tarball.is_file():
        msg = f'input tarball does not exist or is not a file: {tarball}'
        raise ValueError(msg)
    if output.exists() and output.is_dir():
        msg = f'output path is a directory: {output}'
        raise ValueError(msg)

    required_module_dirs = (
        'stages',
        'sources',
        'inputs',
        'devices',
        'mounts',
        'runners',
        'schemas',
    )
    missing = [
        name for name in required_module_dirs if not (libdir / name).is_dir()
    ]
    if missing:
        names = ', '.join(missing)
        msg = f'osbuild libdir {libdir} is missing: {names}'
        raise ValueError(msg)


def archive_member(archive: tarfile.TarFile, name: str) -> bool:
    """Return whether a tar archive contains an exact member name.

    Args:
        archive: Open tar archive.
        name: Member name to locate.

    Returns:
        ``True`` when the member exists.
    """
    try:
        archive.getmember(name)
    except KeyError:
        return False
    return True


def docker_image_name(tarball: Path) -> str | None:
    """Read the first tagged image name from a Docker archive.

    Args:
        tarball: Docker archive path.

    Returns:
        The first repository tag, or ``None`` when no tag is recorded.

    Raises:
        ValueError: If the manifest is invalid or contains multiple images.
    """
    try:
        with tarfile.open(tarball) as archive:
            manifest_file = archive.extractfile('manifest.json')
            if manifest_file is None:
                return None
            manifest = json.load(manifest_file)
    except (
        json.JSONDecodeError,
        KeyError,
        OSError,
        tarfile.TarError,
        UnicodeDecodeError,
    ) as error:
        msg = 'the Docker archive contains an invalid manifest.json'
        raise ValueError(msg) from error

    if (
        not isinstance(manifest, list)
        or len(manifest) != 1
        or not isinstance(manifest[0], dict)
    ):
        msg = 'the Docker archive must contain exactly one image'
        raise ValueError(msg)
    tags = manifest[0].get('RepoTags') or []
    if not isinstance(tags, list) or any(
        not isinstance(tag, str) for tag in tags
    ):
        msg = 'the Docker archive contains invalid repository tags'
        raise ValueError(msg)
    return tags[0] if tags else None


@contextmanager
def prepare_oci_archive(
    tarball: Path, skopeo: str
) -> Iterator[tuple[Path, str]]:
    """Yield an OCI archive and its image name.

    OCI archives are used in place. Docker archives, including the output of
    ``dockerTools.streamLayeredImage``, are converted with ``skopeo`` in a
    temporary directory. No image is loaded into host container storage.

    Args:
        tarball: Docker or OCI archive path.
        skopeo: skopeo executable name or path.

    Yields:
        The OCI archive path and container image name.

    Raises:
        ValueError: If the input is not a supported single-image archive.
        RuntimeError: If skopeo is unavailable or conversion fails.
    """
    try:
        with tarfile.open(tarball) as archive:
            is_oci = archive_member(archive, 'oci-layout') and archive_member(
                archive, 'index.json'
            )
            is_docker = archive_member(archive, 'manifest.json')
    except (OSError, tarfile.TarError) as error:
        msg = f'input is not a readable tar archive: {tarball}'
        raise ValueError(msg) from error

    if is_oci:
        yield tarball, DEFAULT_IMAGE_NAME
        return
    if not is_docker:
        msg = f'input is neither a Docker nor an OCI image archive: {tarball}'
        raise ValueError(msg)

    image_name = docker_image_name(tarball) or DEFAULT_IMAGE_NAME
    executable = shutil.which(skopeo)
    if executable is None:
        msg = f'skopeo executable was not found: {skopeo}'
        raise RuntimeError(msg)

    with tempfile.TemporaryDirectory(prefix='vhd-oci-') as temporary:
        oci_archive = Path(temporary) / 'image.oci.tar'
        command = [
            executable,
            'copy',
            f'docker-archive:{tarball}',
            f'oci-archive:{oci_archive}:image',
        ]
        LOGGER.info('converting Docker archive to OCI archive')
        try:
            # The executable is resolved with shutil.which, every argument is
            # constructed here, and no shell performs further interpretation.
            subprocess.run(command, check=True)  # ruff: ignore[subprocess-without-shell-equals-true]
        except subprocess.CalledProcessError as error:
            msg = f'skopeo failed with exit status {error.returncode}'
            raise RuntimeError(msg) from error
        except OSError as error:
            msg = f'could not execute skopeo: {executable}'
            raise RuntimeError(msg) from error
        if not oci_archive.is_file():
            msg = 'skopeo completed without producing an OCI archive'
            raise RuntimeError(msg)
        yield oci_archive, image_name


def sha256_file(path: Path) -> str:
    """Calculate a file's SHA-256 digest.

    Args:
        path: File to hash.

    Returns:
        The lowercase hexadecimal digest.
    """
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def module(index: Index, kind: str, name: str) -> ModuleInfo:
    """Look up an osbuild module and fail with its exact identity.

    Args:
        index: osbuild module index.
        kind: Module kind, such as ``Stage`` or ``Input``.
        name: Fully qualified module name.

    Returns:
        Module metadata.

    Raises:
        ValueError: If the module is unavailable.
    """
    info = index.get_module_info(kind, name)
    if info is None:
        msg = f'osbuild module is unavailable: {kind} {name}'
        raise ValueError(msg)
    return info


def validate_disk_size(disk_size: int) -> int:
    """Validate disk geometry and return the root partition size.

    Args:
        disk_size: Raw disk size in bytes.

    Returns:
        Root partition size in 512-byte sectors.

    Raises:
        ValueError: If the disk geometry is invalid.
    """
    if disk_size <= PARTITION_START * SECTOR_SIZE:
        msg = 'disk is too small to contain the aligned root partition'
        raise ValueError(msg)
    if disk_size % (1024 * 1024) != 0:
        msg = 'Azure VHD disk size must be a multiple of 1 MiB'
        raise ValueError(msg)
    return disk_size // SECTOR_SIZE - PARTITION_START


def add_archive_pipeline(
    manifest: Manifest,
    index: Index,
    runner: Runner,
    archive: Path,
    archive_digest: str,
) -> Pipeline:
    """Add a pipeline that exposes a local OCI archive to osbuild.

    Args:
        manifest: Manifest receiving the pipeline and source.
        index: osbuild module index.
        runner: Build-host runner.
        archive: Absolute OCI archive path.
        archive_digest: SHA-256 digest of ``archive``.

    Returns:
        The archive pipeline.
    """
    source_ref = f'sha256:{archive_digest}'
    archive_pipeline = manifest.add_pipeline('container-archive', runner, None)
    copy = archive_pipeline.add_stage(
        module(index, 'Stage', 'org.osbuild.copy'),
        {
            'paths': [
                {
                    'from': f'input://archive/{source_ref}',
                    'to': 'tree:///image.oci.tar',
                }
            ]
        },
    )
    archive_input = copy.add_input(
        'archive',
        module(index, 'Input', 'org.osbuild.files'),
        'org.osbuild.source',
    )
    archive_input.add_reference(source_ref)

    # osbuild v193 annotates this as List, but the source schema requires a
    # checksum-keyed mapping.
    source_items = cast('Any', {source_ref: {'url': archive.as_uri()}})
    manifest.add_source(
        module(index, 'Source', 'org.osbuild.curl'), source_items, {}
    )
    return archive_pipeline


def create_manifest(
    index: Index,
    archive: Path,
    archive_digest: str,
    image_name: str,
    target_imgref: str,
    disk_size: int,
) -> Manifest:
    """Create a bootc-to-fixed-VHD osbuild manifest.

    Args:
        index: osbuild module index.
        archive: Absolute OCI archive path.
        archive_digest: SHA-256 digest of ``archive``.
        image_name: Name assigned to the archive input.
        target_imgref: Container reference used for future bootc updates.
        disk_size: Raw disk size in bytes.

    Returns:
        A complete three-pipeline manifest.
    """
    partition_size = validate_disk_size(disk_size)
    runner = Runner(index.detect_host_runner())
    manifest = Manifest()
    archive_pipeline = add_archive_pipeline(
        manifest, index, runner, archive, archive_digest
    )

    disk_pipeline = manifest.add_pipeline('disk', runner, None)
    disk_pipeline.add_stage(
        module(index, 'Stage', 'org.osbuild.truncate'),
        {'filename': 'image.raw', 'size': str(disk_size)},
    )

    sfdisk = disk_pipeline.add_stage(
        module(index, 'Stage', 'org.osbuild.sfdisk'),
        {
            'label': 'dos',
            'uuid': DISK_UUID,
            'partitions': [
                {
                    'bootable': True,
                    'partnum': 1,
                    'start': PARTITION_START,
                    'size': partition_size,
                    'type': '83',
                }
            ],
        },
    )
    sfdisk.add_device(
        'device',
        module(index, 'Device', 'org.osbuild.loopback'),
        None,
        {'filename': 'image.raw'},
    )

    mkfs = disk_pipeline.add_stage(
        module(index, 'Stage', 'org.osbuild.mkfs.ext4'),
        {'uuid': ROOT_UUID, 'label': 'root'},
    )
    mkfs.add_device(
        'device',
        module(index, 'Device', 'org.osbuild.loopback'),
        None,
        {
            'filename': 'image.raw',
            'start': PARTITION_START,
            'size': partition_size,
            'lock': True,
        },
    )

    mkdir = disk_pipeline.add_stage(
        module(index, 'Stage', 'org.osbuild.mkdir'),
        {'paths': [{'path': 'mount://root/boot', 'mode': 0o755}]},
    )
    mkdir_device = mkdir.add_device(
        'disk',
        module(index, 'Device', 'org.osbuild.loopback'),
        None,
        {'filename': 'image.raw', 'partscan': True, 'lock': True},
    )
    mkdir.add_mount(
        'root',
        module(index, 'Mount', 'org.osbuild.ext4'),
        mkdir_device,
        1,
        '/',
        {},
    )

    install = disk_pipeline.add_stage(
        module(index, 'Stage', 'org.osbuild.bootc.install-to-filesystem'),
        {
            'root-mount-spec': f'UUID={ROOT_UUID}',
            'target-imgref': target_imgref,
        },
    )
    images = install.add_input(
        'images',
        module(index, 'Input', 'org.osbuild.containers'),
        'org.osbuild.pipeline',
    )
    images.add_reference(archive_pipeline.id, {'name': image_name})
    disk_device = install.add_device(
        'disk',
        module(index, 'Device', 'org.osbuild.loopback'),
        None,
        {'filename': 'image.raw', 'partscan': True, 'lock': True},
    )
    install.add_mount(
        'root',
        module(index, 'Mount', 'org.osbuild.ext4'),
        disk_device,
        1,
        '/',
        {},
    )

    image_pipeline = manifest.add_pipeline('image', runner, None)
    qemu = image_pipeline.add_stage(
        module(index, 'Stage', 'org.osbuild.qemu'),
        {
            'filename': 'image.vhd',
            'format': {
                'type': 'vpc',
                'subformat': 'fixed',
                'force_size': True,
            },
        },
    )
    raw_image = qemu.add_input(
        'image',
        module(index, 'Input', 'org.osbuild.files'),
        'org.osbuild.pipeline',
    )
    raw_image.add_reference(disk_pipeline.id, {'file': 'image.raw'})
    return manifest


def describe_failure(result: ManifestBuildResult) -> str:
    """Return the most specific available osbuild failure message.

    Args:
        result: Failed manifest result.

    Returns:
        A concise failure description.
    """
    for pipeline in reversed(result.pipeline_results.values()):
        for stage in reversed(pipeline.stages):
            if not stage.success:
                detail = stage.output.strip() or str(stage.error)
                return f'{pipeline.name}: {stage.name} failed: {detail}'
    return f'source download failed: {result.download_result.as_dict()}'


def build_vhd(
    manifest: Manifest,
    libdir: Path,
    store_dir: Path,
    output: Path,
) -> None:
    """Build ``manifest`` and copy its VHD artifact to ``output``.

    Args:
        manifest: Manifest returned by :func:`create_manifest`.
        libdir: osbuild module directory.
        store_dir: osbuild object-store directory.
        output: Destination VHD path.

    Raises:
        RuntimeError: If osbuild fails or omits the VHD artifact.
    """
    store_dir.mkdir(parents=True, exist_ok=True)
    with ObjectStore(str(store_dir)) as store:
        pipelines = manifest.depsolve(store, ['image'])
        result = manifest.build(
            store,
            pipelines,
            NullMonitor(2),
            str(libdir),
        )
        if not result.success:
            raise RuntimeError(describe_failure(result))

        with tempfile.TemporaryDirectory(prefix='vhd-export-') as export_tmp:
            export_dir = Path(export_tmp)
            image_object = store.get(manifest['image'].id)
            if image_object is None:
                msg = 'osbuild did not store the image pipeline result'
                raise RuntimeError(msg)
            image_object.export(str(export_dir))
            artifact = export_dir / 'image.vhd'
            if not artifact.is_file():
                msg = (
                    f'osbuild did not produce the expected artifact: {artifact}'
                )
                raise RuntimeError(msg)
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(artifact, output)


def run_with_store(
    manifest: Manifest,
    libdir: Path,
    store: Path | None,
    output: Path,
) -> None:
    """Run a manifest with a persistent or temporary object store.

    Args:
        manifest: Manifest to build.
        libdir: osbuild module directory.
        store: Persistent store path, or ``None``.
        output: Destination VHD path.
    """
    if store is not None:
        build_vhd(manifest, libdir, store.expanduser().resolve(), output)
        return
    with tempfile.TemporaryDirectory(prefix='osbuild-store-') as temporary:
        build_vhd(manifest, libdir, Path(temporary), output)


def main(argv: Sequence[str] | None = None) -> None:
    """Build the VHD described by the command-line arguments.

    Args:
        argv: Arguments to parse, excluding the program name.
    """
    logging.basicConfig(format='%(message)s', level=logging.INFO)
    args = parse_args(argv)
    tarball = args.tarball.expanduser().resolve()
    output = args.output.expanduser().resolve()
    libdir = args.libdir.expanduser().resolve()
    validate_paths(tarball, output, libdir)

    with prepare_oci_archive(tarball, args.skopeo) as (
        archive,
        image_name,
    ):
        LOGGER.info('hashing %s', archive)
        archive_digest = sha256_file(archive)
        target_imgref = args.target_imgref or image_name
        manifest = create_manifest(
            Index(str(libdir)),
            archive,
            archive_digest,
            image_name,
            target_imgref,
            args.size,
        )
        run_with_store(manifest, libdir, args.store, output)

    LOGGER.info('wrote %s', output)


if __name__ == '__main__':
    main()
