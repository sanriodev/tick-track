#!/bin/sh
# Druckt einen SHA-256-Signaturfingerprint in den beiden Kodierungen, die für
# Passkeys gebraucht werden:
#
#   Hex mit Doppelpunkten -> APP_ASSOCIATION_ANDROID_FINGERPRINTS (assetlinks)
#   base64url             -> WEBAUTHN_ORIGIN (android:apk-key-hash:...)
#
# Nutzung:
#   ./passkey-fingerprint.sh AA:BB:CC:...             bekannter Hex-Wert
#   ./passkey-fingerprint.sh <cert.der|cert.pem>      Zertifikat, z.B. das aus
#                                                     der Play Console
#   ./passkey-fingerprint.sh <keystore> [storepass]   PKCS#12-Keystore
#
# Braucht nur openssl, kein JDK. Keystores müssen PKCS#12 sein (heute der
# Standard, auch für ~/.android/debug.keystore); ein alter JKS-Keystore
# (magic feedfeed) geht nur mit keytool.

set -e

hex_to_base64url() {
    printf '%s' "$1" | tr -d ':' | tr 'a-f' 'A-F' | xxd -r -p \
        | openssl base64 | tr '/+' '_-' | tr -d '=\n'
}

print_both() {
    hex="$1"
    echo "Hex (assetlinks / APP_ASSOCIATION_ANDROID_FINGERPRINTS):"
    echo "  $hex"
    echo "base64url (WEBAUTHN_ORIGIN -> android:apk-key-hash:...):"
    echo "  $(hex_to_base64url "$hex")"
}

if [ -z "$1" ]; then
    echo "Nutzung: $0 <keystore|hex-fingerprint> [storepass] [alias]" >&2
    exit 1
fi

case "$1" in
*:*:*)
    print_both "$(printf '%s' "$1" | tr 'a-f' 'A-F')"
    exit 0
    ;;
esac

fingerprint_of_cert() {
    openssl x509 -in "$1" -inform "$2" -noout -fingerprint -sha256 2>/dev/null \
        | sed 's/.*=//'
}

# Ein einzelnes Zertifikat, wie es die Play Console zum Download anbietet
for form in DER PEM; do
    hex="$(fingerprint_of_cert "$1" "$form")"
    if [ -n "$hex" ]; then
        echo "Subject: $(openssl x509 -in "$1" -inform "$form" -noout -subject | sed 's/^subject=//')"
        print_both "$hex"
        exit 0
    fi
done

keystore="$1"
storepass="${2:-android}"

if [ ! -f "$keystore" ]; then
    echo "Keystore nicht gefunden: $keystore" >&2
    exit 1
fi

cert="$(mktemp)"
trap 'rm -f "$cert"' EXIT

# kein set -e-Abbruch: der Fehlerfall soll die Erklaerung unten erreichen
openssl pkcs12 -in "$keystore" -passin "pass:$storepass" -nokeys -clcerts \
    -out "$cert" 2>/dev/null || true

if [ ! -s "$cert" ]; then
    echo "Konnte kein Zertifikat lesen. Falsches Passwort, oder ein" >&2
    echo "JKS-Keystore - dafuer braucht es keytool aus einem JDK." >&2
    exit 1
fi

echo "Subject: $(openssl x509 -in "$cert" -noout -subject | sed 's/^subject=//')"
print_both "$(openssl x509 -in "$cert" -noout -fingerprint -sha256 | sed 's/.*=//')"
