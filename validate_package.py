#!/usr/bin/env python3
"""Offline structural validation; does not install a package or prove device trust."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import plistlib
import struct
import subprocess
import sys
import tarfile


def deb(path):
    data = Path(path).read_bytes()
    assert data[:8] == b"!<arch>\n", "not a Debian ar archive"
    pos, members = 8, {}
    while pos < len(data):
        header = data[pos:pos + 60]
        assert len(header) == 60 and header[58:60] == b"`\n"
        name = header[:16].decode().strip().rstrip("/")
        size = int(header[48:58])
        assert name not in members
        members[name] = data[pos + 60:pos + 60 + size]
        assert len(members[name]) == size
        pos += 60 + size + (size % 2)
    assert members["debian-binary"] == b"2.0\n"
    assert len(members) == 3
    result = []
    for prefix in ("control.tar", "data.tar"):
        names = [x for x in members if x.startswith(prefix)]
        assert len(names) == 1
        # Produced package uses lzma; Python tarfile supports it directly.
        with tarfile.open(fileobj=io.BytesIO(members[names[0]]), mode="r:*") as tar:
            files, metadata = {}, []
            for item in tar:
                p = PurePosixPath(item.name)
                assert not p.is_absolute() and ".." not in p.parts
                name = str(p)
                if item.isdir(): continue
                marker = False
                assert item.isfile() or marker, "unexpected link or special file"
                assert name not in files
                files[name] = item.linkname.encode() if marker else tar.extractfile(item).read()
                metadata.append((name, item.uid, item.gid, oct(item.mode)))
            result.append((files, metadata))
    return result


def verify_signature(blob, signature):
    offset, size = signature
    sig = blob[offset:offset + size]
    magic, length, count = struct.unpack_from(">III", sig)
    assert magic == 0xfade0cc0 and length <= size
    slots = {}
    for i in range(count):
        slot, off = struct.unpack_from(">II", sig, 12 + i * 8)
        magic, length = struct.unpack_from(">II", sig, off)
        assert off + length <= len(sig)
        slots[slot] = sig[off:off + length]
    directories = []
    for slot, cd in slots.items():
        if struct.unpack_from(">I", cd)[0] != 0xfade0c02: continue
        _, _, version, flags, hashes, identifier, special, pages, limit = struct.unpack_from(">9I", cd)
        hash_size, hash_type, platform, power = struct.unpack_from("4B", cd, 36)
        assert hash_type in (1, 2) and power <= 20
        hashfn = hashlib.sha1 if hash_type == 1 else hashlib.sha256
        assert hash_size == hashfn().digest_size
        page_size = 1 << power
        assert limit == offset and pages == (limit + page_size - 1) // page_size
        assert hashes + pages * hash_size <= len(cd)
        for i in range(pages):
            actual = hashfn(blob[i * page_size:min((i + 1) * page_size, limit)]).digest()
            assert actual == cd[hashes + i * hash_size:hashes + (i + 1) * hash_size], "code hash mismatch"
        for i in range(1, special + 1):
            stored = cd[hashes - i * hash_size:hashes - (i - 1) * hash_size]
            if any(stored):
                assert i in slots and stored == hashfn(slots[i]).digest(), "special slot mismatch"
        directories.append({"slot": slot, "hash": hashfn().name, "verified_pages": pages, "flags": flags})
    assert len(directories) >= 1
    return directories


def slices(blob):
    if blob[:4] == bytes.fromhex('cffaedfe'):
        subtype = struct.unpack_from('<I', blob, 8)[0]
        assert subtype == 0x80000002
        return {subtype:blob}
    assert blob[:4] == bytes.fromhex('cafebabe'), 'expected a Mach-O image' 
    count = struct.unpack_from('>I', blob, 4)[0]
    assert count == 2
    result = {}
    for i in range(count):
        cpu, subtype, offset, size, align = struct.unpack_from('>5I', blob, 8 + i*20)
        assert cpu == 0x100000c and subtype in (0, 2, 0x80000002)
        assert offset % (1 << align) == 0 and offset + size <= len(blob)
        assert subtype not in result
        result[subtype] = blob[offset:offset+size]
    assert set(result) in ({0, 2}, {0, 0x80000002})
    return result


def commands(blob):
    header = struct.unpack_from('<8I', blob)
    assert header[0] == 0xfeedfacf and header[1] == 0x100000c
    pos, result = 32, []
    for _ in range(header[4]):
        cmd, size = struct.unpack_from('<II', blob, pos)
        assert size >= 8 and pos + size <= 32 + header[5]
        result.append((cmd, pos, size))
        pos += size
    return result

def signatures(blob):
    result = []
    for subtype, image in slices(blob).items():
        signature = None
        for cmd, pos, size in commands(image):
            if cmd == 0x1d: signature = struct.unpack_from('<II', image, pos+8)
            if cmd == 0x2c: assert struct.unpack_from('<I', image, pos+16)[0] == 0
        assert signature
        result.append({'cpu_subtype': hex(subtype), 'code_directories': verify_signature(image, signature)})
    return result

def main():
    path = Path(sys.argv[1])
    scheme = sys.argv[2]
    assert scheme in ('rootless','roothide')
    native = scheme == 'roothide'
    (control,cm),(data,dm)=deb(path)
    assert set(control)=={'control'}, 'no install scripts expected'
    fields=dict(line.split(': ',1) for line in control['control'].decode().splitlines() if ': ' in line)
    assert fields['Package']=='com.sahinkaa.noshutterscreenshotsounds'
    assert fields['Name']=='No Shutter & Screenshot Sounds'
    assert fields['Version']=='1.0'
    assert path.name==f"{fields['Package']}_{fields['Version']}_{fields['Architecture']}.deb"
    assert fields['Author']==fields['Maintainer']=='sahinkaa'
    assert fields['Architecture']==('iphoneos-arm64e' if native else 'iphoneos-arm64')
    assert 'firmware (>= 15.0)' in fields['Depends']
    assert 'rootless-compat' not in fields['Depends']
    payload_files=sorted(data)
    if not native:
        assert all(name.startswith('var/jb/') for name in data)
        data={name.removeprefix('var/jb/'):value for name,value in data.items()}
    assert all(uid==gid==0 and not int(mode,8)&0o022 for name,uid,gid,mode in cm+dm)
    bundle='Library/PreferenceBundles/NoCaptureSoundsPrefs.bundle/'
    engine='Library/MobileSubstrate/DynamicLibraries/NoCaptureSounds.dylib'
    pane=bundle+'NoCaptureSoundsPrefs'
    filterpath=engine[:-6]+'.plist'
    registration='Library/PreferenceLoader/Preferences/NoCaptureSounds.plist'
    expected={engine,pane,filterpath,registration,bundle+'Info.plist',bundle+'HeaderIcon.png'} | {bundle+'Icon'+scale+'.png' for scale in ['', '@2x','@3x']}
    assert set(data)==expected,(set(data)-expected,expected-set(data))
    entry=plistlib.loads(data[registration])['entry'];info=plistlib.loads(data[bundle+'Info.plist'])
    assert entry['label']==fields['Name'] and entry['icon']=='Icon.png'
    assert entry['isController'] is True, 'native preference controller must be registered for lazy loading'
    assert entry['detail']==info['NSPrincipalClass']=='NSCRootController'
    assert entry['bundle']==info['CFBundleExecutable']=='NoCaptureSoundsPrefs'
    assert info['CFBundleVersion']==info['CFBundleShortVersionString']=='1.0'
    assert plistlib.loads(data[filterpath])=={'Filter':{'Bundles':['com.apple.springboard','com.apple.camera']}}
    icons=[]
    for scale,suffix in [(1,''),(2,'@2x'),(3,'@3x')]:
        icon=data[bundle+'Icon'+suffix+'.png']
        assert icon[:8]==b'\x89PNG\r\n\x1a\n'
        width,height=struct.unpack_from('>II',icon,16)
        assert width==height==29*scale
        icons.append({'scale':scale,'pixels':width,'sha256':hashlib.sha256(icon).hexdigest()})
    header_icon=data[bundle+'HeaderIcon.png']
    assert header_icon[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack_from('>II',header_icon,16)==(512,512)
    assert b'HeaderIcon' in data[pane], 'Settings page must load the header icon'
    binaries={}
    for name in [engine,pane]:
        images=slices(data[name]);assert set(images)==({0x80000002} if native else {0,0x80000002})
        architectures=[]
        for subtype,image in images.items():
            dependencies,rpaths=[],[];deployment=False
            for cmd,pos,size in commands(image):
                if cmd in (0xc,0x80000018):
                    start=pos+struct.unpack_from('<I',image,pos+8)[0];dependencies.append(image[start:image.index(0,start,pos+size)].decode())
                if cmd==0x8000001c:
                    start=pos+struct.unpack_from('<I',image,pos+8)[0];rpaths.append(image[start:image.index(0,start,pos+size)].decode())
                if cmd==0x32:
                    platform,minos=struct.unpack_from('<II',image,pos+8);assert platform==2 and minos==0x000f0000;deployment=True
            assert deployment
            assert all('/Users/' not in dep for dep in dependencies)
            if native:
                assert '@loader_path/.jbroot/usr/lib/libroothide.dylib' in dependencies
                assert not any('/var/jb' in dep for dep in dependencies)
                if name==engine:assert '@loader_path/.jbroot/usr/lib/libsubstrate.dylib' in dependencies
            else:
                assert not any('libroothide' in dep for dep in dependencies)
                assert '/var/jb/Library/Frameworks' in rpaths and '/var/jb/usr/lib' in rpaths
                if name==engine:assert '@rpath/CydiaSubstrate.framework/CydiaSubstrate' in dependencies
            assert b'PSListController' not in image and b'NSCHostScreenCapturer' not in image and b'NSCHostPhotoSettings' not in image
            architectures.append({'cpu_subtype':hex(subtype),'dependencies':dependencies,'rpaths':rpaths})
        binaries[name]={'sha256':hashlib.sha256(data[name]).hexdigest(),'architectures':architectures,'signatures':signatures(data[name])}
    for name in ['AudioServicesPlaySystemSoundWithOptions','AudioServicesPlaySystemSound','AudioServicesPlaySystemSoundWithCompletion','AudioServicesPlayAlertSound','AudioServicesPlayAlertSoundWithCompletion','SSScreenCapturer','playScreenshotSound','AVCapturePhotoSettings','shutterSound']:
        assert name.encode() in data[engine],name
    assert b'wantsAudioForCapture' not in data[engine] and b'setShutterSound:' not in data[engine]
    assert b'com.sahinkaa.noshutterscreenshotsounds.plist' in data[engine] and b'com.sahinkaa.noshutterscreenshotsounds.plist' in data[pane]
    print(json.dumps({'package':path.name,'scheme':scheme,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'control':fields,'binaries':binaries,'icons':icons,'payload_files':payload_files,'result':'PASS: package ownership, payload inventory, architecture slices, iOS 15 deployment, jailbreak dependencies, signed code-page hashes and icon sizes. Device behavior not verified.'},indent=2))

if __name__=='__main__':main()
