#!/bin/sh
set -eu

B2="/root/venvs/b2/bin/b2"
BUCKET_DEFAULT="truenas-backup-mdemeczky"

trim() { echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
die() { echo "HIBA: $*" >&2; exit 1; }

# Auth check
$B2 account get >/dev/null 2>&1 || die "b2 nincs authorizálva. Futtasd: $B2 account authorize <KEY_ID> <APP_KEY>"

echo "=== Backblaze B2 menüs törlés (jail) ==="
echo

printf "Bucket név [%s]: " "$BUCKET_DEFAULT"
read BUCKET
BUCKET="$(trim "${BUCKET:-$BUCKET_DEFAULT}")"
[ -n "$BUCKET" ] || die "Bucket üres."

echo
echo "=== Bucket gyökér (top-level) ==="
TOP="$($B2 ls "b2://${BUCKET}/" | head -n 50 || true)"
echo "$TOP"

TOP_LIST="$(echo "$TOP" | sed '/^[[:space:]]*$/d')"
[ -n "$TOP_LIST" ] || die "Üres a bucket (nincs mit listázni)."

echo
echo "Melyiket listázzam?"
i=1
echo "$TOP_LIST" | while IFS= read -r line; do
  printf "  %d) %s\n" "$i" "$line"
  i=$((i+1))
done

printf "Választás (szám): "
read CH
CH="$(trim "$CH")"
case "$CH" in ''|*[!0-9]* ) die "Számot adj meg." ;; esac

BASE="$(echo "$TOP_LIST" | sed -n "${CH}p")"
[ -n "$BASE" ] || die "Nincs ilyen választás."
BASE="$(trim "$BASE")"
BASE="${BASE#/}"

echo
echo "Kiválasztva: $BASE"
printf "Adj meg ezen belül további prefixet (ENTER = teljes '%s'): " "$BASE"
read SUB
SUB="$(trim "$SUB")"
SUB="${SUB#/}"

PREFIX="$BASE"
if [ -n "$SUB" ]; then
  PREFIX="${BASE}${SUB}"
fi

case "$PREFIX" in */) : ;; *) PREFIX="${PREFIX}/" ;; esac
URI="b2://${BUCKET}/${PREFIX}"

echo
echo "Cél URI: $URI"
echo

echo "=== Minta listázás (első 50 találat) ==="
# Nem minden verzióban ugyanaz az ls output, de a file paths biztosan benne vannak.
$B2 ls --recursive "$URI" | head -n 50 || true

echo
echo "=== Darabszám becslés (első 1000 alapján) ==="
COUNT="$($B2 ls --recursive "$URI" | head -n 1000 | wc -l | tr -d ' ')"
echo "Találatok (max 1000-ig számolva): $COUNT"
if [ "$COUNT" -eq 0 ]; then
  echo "FIGYELEM: 0 találat a megadott prefixre. Lehet, hogy rossz a prefix."
fi

echo
printf "Biztos törlöd ezt a prefixet? (yes/no): "
read OK
OK="$(trim "$OK")"
[ "$OK" = "yes" ] || { echo "Megszakítva."; exit 0; }

echo
printf "Töröljem a verziókat is? (yes/no): "
read VERS
VERS="$(trim "$VERS")"

echo
echo ">>> TÖRLÉS INDUL <<<"
if [ "$VERS" = "yes" ]; then
  $B2 rm --versions --recursive "$URI"
else
  $B2 rm --recursive "$URI"
fi

echo "Kész."

