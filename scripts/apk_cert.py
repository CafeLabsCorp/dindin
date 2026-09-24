#!/usr/bin/env python3
"""Print the SHA-1/SHA-256 of the certificate that signed an APK.

`keytool -printcert -jarfile` only reads v1 (JAR) signatures, and the APKs
Google Play delivers carry v2/v3 only, so keytool prints nothing for them.
This reads the APK Signing Block directly; no Android SDK needed.

Usage (phone connected over adb, app installed from Play):
  adb pull "$(adb shell pm path com.cafelabs.dindin | grep base.apk | sed 's/package://' | tr -d '\\r')" play.apk
  python3 scripts/apk_cert.py play.apk

See docs/DEPLOY.md, "Google Sign-In fails only for Play installs".
"""
import hashlib
import struct
import sys

V2, V3 = 0x7109871A, 0xF05368C0


def lp(buf, off):
    """Read a uint32 length-prefixed field."""
    n = struct.unpack('<I', buf[off:off + 4])[0]
    return buf[off + 4:off + 4 + n], off + 4 + n


def fmt(digest):
    h = digest.upper()
    return ':'.join(h[i:i + 2] for i in range(0, len(h), 2))


def main(path):
    data = open(path, 'rb').read()
    eocd = data.rfind(b'PK\x05\x06')
    cd = struct.unpack('<I', data[eocd + 16:eocd + 20])[0]
    if data[cd - 16:cd] != b'APK Sig Block 42':
        sys.exit('No v2/v3 signing block; try keytool -printcert -jarfile')
    size = struct.unpack('<Q', data[cd - 24:cd - 16])[0]
    block = data[cd - size:cd - 24]

    seen = set()
    off = 0
    while off < len(block):
        n, pid = struct.unpack('<QI', block[off:off + 12])
        value = block[off + 12:off + 8 + n]
        off += 8 + n
        if pid not in (V2, V3):
            continue
        signers, _ = lp(value, 0)
        so = 0
        while so < len(signers):
            signer, so = lp(signers, so)
            signed_data, _ = lp(signer, 0)
            _, p = lp(signed_data, 0)  # skip digests
            certs, _ = lp(signed_data, p)
            cert, _ = lp(certs, 0)
            if cert in seen:
                continue
            seen.add(cert)
            print('SHA-1:  ', fmt(hashlib.sha1(cert).hexdigest()))
            print('SHA-256:', fmt(hashlib.sha256(cert).hexdigest()))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
