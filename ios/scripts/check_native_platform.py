"""Guard Flutter's shared native-assets staging when switching simulator/device.

Run before Flutter assemble to remove stale frameworks for the other SDK, and
again after embed to reject a malformed archive. Never changes Mach-O headers or
merely strips x86_64: arm64 simulator code is also invalid for a device archive.
"""
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile


def validate(binary, expected):
    result = subprocess.run(['xcrun', 'vtool', '-show-build', str(binary)],
                            capture_output=True, text=True, check=True)
    platforms = re.findall(r'^\s*platform\s+(\S+)', result.stdout, re.M)
    if not platforms:
        # Older third-party frameworks can use LC_VERSION_MIN_IPHONEOS instead.
        load = subprocess.check_output(['xcrun', 'otool', '-l', str(binary)], text=True)
        if expected == 'IOS' and 'LC_VERSION_MIN_IPHONEOS' in load:
            return
        raise RuntimeError(f'Cannot verify target platform: {binary.name}')
    if any(p != expected for p in platforms):
        raise RuntimeError(f'{binary.name}: expected {expected}, found {platforms}')
    arches = subprocess.check_output(['xcrun', 'lipo', '-archs', str(binary)], text=True).split()
    if expected == 'IOS' and any(a not in ('arm64', 'arm64e', 'armv7', 'armv7s') for a in arches):
        raise RuntimeError(f'{binary.name}: unsupported device architectures {arches}')


def frameworks(root):
    for framework in root.glob('*.framework'):
        info = framework / 'Info.plist'
        name = plistlib.loads(info.read_bytes()).get('CFBundleExecutable', framework.stem) if info.exists() else framework.stem
        binary = framework / name
        if binary.is_file():
            yield framework, binary



def binary_uuids(path):
    output = subprocess.check_output(['xcrun', 'dwarfdump', '--uuid', str(path)], text=True)
    result = set(re.findall(r'UUID: ([A-Fa-f0-9-]+) \(([^)]+)\)', output))
    if not result:
        raise RuntimeError(f'No build UUID in {path.name}')
    return result


def emit_objective_c_symbols(binary, output_folder):
    """Generate real symbols from this binary's debug map and original .o files.

    Native assets are not Xcode framework targets, so Xcode does not run dsymutil
    for them. Write into DWARF_DSYM_FOLDER_PATH before Xcode gathers archive
    symbols. Never make a placeholder or change a UUID to match another build.
    """
    output_folder.mkdir(parents=True, exist_ok=True)
    dest = output_folder / 'objective_c.framework.dSYM'
    with tempfile.TemporaryDirectory(prefix='native-dsym-', dir=output_folder) as temporary:
        generated = Path(temporary) / dest.name
        result = subprocess.run(['xcrun', 'dsymutil', str(binary), '-o', str(generated)],
                                capture_output=True, text=True, check=True)
        if 'warning:' in result.stderr.lower() or 'error:' in result.stderr.lower():
            raise RuntimeError('Native symbols could not use the original object files: ' + result.stderr)
        if binary_uuids(generated) != binary_uuids(binary):
            raise RuntimeError('Native dSYM UUID differs from embedded framework')
        dwarf = generated / 'Contents/Resources/DWARF/objective_c'
        info = subprocess.check_output(['xcrun', 'dwarfdump', '--debug-info', str(dwarf)], text=True)
        if 'DW_TAG_compile_unit' not in info:
            raise RuntimeError('Native dSYM has no compilation debug information')
        subprocess.run(['xcrun', 'dwarfdump', '--verify', str(generated)],
                       capture_output=True, text=True, check=True)
        if dest.exists():
            shutil.rmtree(dest)
        shutil.move(str(generated), str(dest))
    print('Generated matching objective_c.framework.dSYM with verified debug information', flush=True)


def main():
    sdk = os.environ.get('PLATFORM_NAME', '')
    if sdk not in ('iphoneos', 'iphonesimulator'):
        raise RuntimeError(f'Unsupported iOS SDK: {sdk}')
    expected = 'IOS' if sdk == 'iphoneos' else 'IOSSIMULATOR'
    mode = sys.argv[1]
    if mode == 'prepare':
        project = Path(os.environ['SRCROOT']).parent
        build = Path(os.environ.get('FLUTTER_BUILD_DIR', 'build'))
        if not build.is_absolute():
            build = project / build
        refresh = not (build / 'native_assets/ios/objective_c.framework/objective_c').is_file()
        for framework, binary in frameworks(build / 'native_assets/ios'):
            try:
                validate(binary, expected)
            except RuntimeError as error:
                print(f'Removing stale generated native asset: {error}', flush=True)
                shutil.rmtree(framework)
                refresh = True
        if refresh:
            # The installer stamp can otherwise claim success after staging was
            # removed. Preserve compiled Dart/hooks, rerun only asset installation.
            for stamp in (project / '.dart_tool/flutter_build').glob('*/install_code_assets.stamp'):
                stamp.unlink()
    elif mode == 'verify':
        root = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['FRAMEWORKS_FOLDER_PATH']
        # Required by our current objective_c/path_provider native dependency.
        # Missing is as invalid as embedding a simulator framework.
        if not (root / 'objective_c.framework/objective_c').is_file():
            raise RuntimeError('Required objective_c.framework is missing')
        for _, binary in frameworks(root):
            validate(binary, expected)
        print(f'Embedded frameworks verified for {expected}', flush=True)
        if sdk == 'iphoneos' and os.environ.get('ACTION') == 'install':
            symbols_folder = os.environ.get('DWARF_DSYM_FOLDER_PATH')
            if not symbols_folder:
                raise RuntimeError('Archive dSYM output directory is not configured')
            emit_objective_c_symbols(root / 'objective_c.framework/objective_c', Path(symbols_folder))
    else:
        raise RuntimeError('Expected prepare or verify')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'error: iOS native platform validation failed: {error}', file=sys.stderr)
        sys.exit(1)
