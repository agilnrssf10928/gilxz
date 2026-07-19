#!/bin/bash
# ============================================
# installprotect13.sh
# Menyembunyikan menu "Application API" dari sidebar
# dan memblokir akses controller Application API
# untuk semua admin KECUALI User ID 1
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-My_GilXz Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

echo "==========================================="
echo "🔒 INSTALLPROTECT13: Proteksi Application API"
echo "==========================================="

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 1: Sembunyikan menu Application API dari sidebar
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 1: Sembunyikan menu Application API di sidebar"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cari file sidebar ASLI, jangan pernah ambil backup .bak/.bak_pm.
SIDEBAR_FILE=""
for CANDIDATE in \
    "$PANEL_DIR/resources/views/layouts/admin.blade.php" \
    "$PANEL_DIR/resources/views/partials/admin/sidebar.blade.php"; do
    if [ -f "$CANDIDATE" ] && grep -Eq "Application API|admin\.api|api\.index|route\('admin\.api" "$CANDIDATE" 2>/dev/null; then
        SIDEBAR_FILE="$CANDIDATE"
        break
    fi
done

if [ -z "$SIDEBAR_FILE" ]; then
    SIDEBAR_FILE=$(grep -RIlE --include='*.blade.php' "Application API|admin\.api|api\.index|route\('admin\.api" "$PANEL_DIR/resources/views/" 2>/dev/null \
        | grep -vE '\.bak($|_)|\.bak_|bak_pm|/storage/framework/' \
        | head -1)
fi

if [ -z "$SIDEBAR_FILE" ]; then
    echo "⚠️ Tidak menemukan menu Application API di file blade asli, mencoba layout admin default..."
    SIDEBAR_FILE="$PANEL_DIR/resources/views/layouts/admin.blade.php"
fi

if [ ! -f "$SIDEBAR_FILE" ]; then
    echo "❌ File tidak ditemukan: $SIDEBAR_FILE"
    echo "⏭️ Skip bagian 1"
else
    echo "📂 File ditemukan: $SIDEBAR_FILE"
    cp "$SIDEBAR_FILE" "${SIDEBAR_FILE}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${SIDEBAR_FILE}.bak_${TIMESTAMP}"

    export APPAPI_SIDEBAR="$SIDEBAR_FILE"
    python3 << 'PYEOF_APPAPI'
import os, re

sidebar = os.environ["APPAPI_SIDEBAR"]
with open(sidebar, "r") as f:
    content = f.read()

# ── Bersihkan blok marker lama (baik format V1 hide-only maupun V2 gembok) ──
if "PROTEKSI_My_GilXz_APPAPI_MENU" in content:
    lines_all = content.split("\n")
    cleaned = []
    skip = False
    saw_end_marker = False
    depth = 0
    for ln in lines_all:
        if not skip and "PROTEKSI_My_GilXz_APPAPI_MENU" in ln and "END" not in ln:
            skip = True
            saw_end_marker = False
            depth = 0
            continue
        if skip:
            if "END PROTEKSI_My_GilXz_APPAPI_MENU" in ln:
                skip = False
                saw_end_marker = True
                continue
            # fallback: format lama tanpa END marker → strip sampai @endif seimbang
            if "@if" in ln:
                depth += ln.count("@if")
            if "@endif" in ln:
                depth -= ln.count("@endif")
                if depth <= 0 and not saw_end_marker:
                    skip = False
                    continue
            continue
        cleaned.append(ln)
    content = "\n".join(cleaned)
    with open(sidebar, "w") as f:
        f.write(content)
    print("♻️ Blok marker lama dibersihkan, akan inject ulang")


def lock_transform(block_text):
    def repl(m):
        attrs = m.group(1)
        attrs = re.sub(r'href\s*=\s*"[^"]*"', 'href="#" onclick="return false;"', attrs, count=1)
        if re.search(r'style\s*=\s*"', attrs):
            attrs = re.sub(r'style\s*=\s*"([^"]*)"', r'style="\1;opacity:0.55;pointer-events:none;cursor:not-allowed;filter:grayscale(1);"', attrs, count=1)
        else:
            attrs = attrs.rstrip() + ' style="opacity:0.55;pointer-events:none;cursor:not-allowed;filter:grayscale(1);"'
        return '<a ' + attrs + '><i class="fa fa-lock" style="margin-right:6px;"></i>'
    return re.sub(r'<a\s+([^>]*)>', repl, block_text, count=1)

lines = content.split("\n")
target = -1
patterns = ("Application API", "admin.api", "api.index", "route('admin.api", 'route("admin.api')
for idx, ln in enumerate(lines):
    if any(p in ln for p in patterns):
        target = idx
        break

if target < 0:
    print("⚠️ Menu Application API tidak ditemukan di file asli")
    raise SystemExit(0)

# find <li open going up
li_start = target
for j in range(target, max(-1, target - 15), -1):
    if "<li" in lines[j]:
        li_start = j
        break

# find </li> close going down
li_end = target
for j in range(target, min(len(lines), target + 15)):
    if "</li>" in lines[j]:
        li_end = j
        break

block = lines[li_start:li_end + 1]
locked = lock_transform("\n".join(block))

new_lines = lines[:li_start]
new_lines.append("{{-- PROTEKSI_My_GilXz_APPAPI_MENU: gembok untuk non-ID 1 --}}")
new_lines.append("@if(Auth::user() && (int) Auth::user()->id === 1)")
new_lines.extend(block)
new_lines.append("@else")
new_lines.append(locked)
new_lines.append("@endif")
new_lines.append("{{-- END PROTEKSI_My_GilXz_APPAPI_MENU --}}")
new_lines.extend(lines[li_end + 1:])

with open(sidebar, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Menu Application API dikunci (gembok) untuk non-ID 1")
PYEOF_APPAPI
fi


echo "✅ BAGIAN 1 SELESAI"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 2: Block akses ke Application API Controller
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 2: Block akses Application API Controller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

API_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Admin/ApiController.php"

if [ ! -f "$API_CONTROLLER" ]; then
    echo "❌ ApiController tidak ditemukan: $API_CONTROLLER"
else
    cp "$API_CONTROLLER" "${API_CONTROLLER}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${API_CONTROLLER}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_My_GilXz_APPAPI_BLOCK" "$API_CONTROLLER"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Cari baris "public function index" dan inject proteksi setelahnya
        INDEX_LINE=$(grep -n "public function index" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        
        if [ -n "$INDEX_LINE" ]; then
            # Cari baris { setelah function declaration
            BRACE_LINE=$INDEX_LINE
            for i in $(seq "$INDEX_LINE" $((INDEX_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done

            # Inject setelah opening brace
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_My_GilXz_APPAPI_BLOCK: Block akses untuk non-ID 1" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"

            echo "✅ Proteksi index() diinjeksi"
        fi

        # Juga proteksi method store (buat key)
        STORE_LINE=$(grep -n "public function store" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$STORE_LINE" ]; then
            BRACE_LINE=$STORE_LINE
            for i in $(seq "$STORE_LINE" $((STORE_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_My_GilXz_APPAPI_BLOCK" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"
            echo "✅ Proteksi store() diinjeksi"
        fi

        # Proteksi method delete
        DELETE_LINE=$(grep -n "public function delete\|public function destroy" "$API_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$DELETE_LINE" ]; then
            BRACE_LINE=$DELETE_LINE
            for i in $(seq "$DELETE_LINE" $((DELETE_LINE + 3))); do
                if sed -n "${i}p" "$API_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_My_GilXz_APPAPI_BLOCK" "$API_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if (\\\\Auth::user()->id !== 1) { abort(403, 'Akses Application API tidak diizinkan.'); }" "$API_CONTROLLER"
            echo "✅ Proteksi delete() diinjeksi"
        fi
    fi
fi

echo "✅ BAGIAN 2 SELESAI"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BAGIAN 3: Proteksi Application API endpoint /api/application/users
# Mencegah non-ID 1 mengubah root_admin via REST API
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Proteksi API /api/application/users (root_admin)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cari Application API UserController
API_USER_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"

if [ ! -f "$API_USER_CONTROLLER" ]; then
    echo "⚠️ API UserController tidak ditemukan: $API_USER_CONTROLLER"
    echo "   Mencoba path alternatif..."
    API_USER_CONTROLLER=$(find "$PANEL_DIR/app/Http/Controllers/Api" -name "UserController.php" -path "*/Application/*" 2>/dev/null | head -1)
fi

if [ -z "$API_USER_CONTROLLER" ] || [ ! -f "$API_USER_CONTROLLER" ]; then
    echo "❌ API UserController tidak ditemukan, skip bagian 3"
else
    echo "📂 File ditemukan: $API_USER_CONTROLLER"
    cp "$API_USER_CONTROLLER" "${API_USER_CONTROLLER}.bak_${TIMESTAMP}"
    echo "💾 Backup: ${API_USER_CONTROLLER}.bak_${TIMESTAMP}"

    if grep -q "PROTEKSI_My_GilXz_API_ROOTADMIN" "$API_USER_CONTROLLER"; then
        TMP=$(mktemp)
        awk '
            BEGIN { skip_next=0 }
            /PROTEKSI_My_GilXz_API_ROOTADMIN/ { skip_next=1; next }
            skip_next == 1 { skip_next=0; next }
            { print }
        ' "$API_USER_CONTROLLER" > "$TMP" && mv "$TMP" "$API_USER_CONTROLLER"
        chmod 644 "$API_USER_CONTROLLER"
        echo "♻️ Guard API users lama dari protect13 dibersihkan; proteksi API users ditangani protect14 V5"
    fi

    if true; then
        echo "ℹ️ Skip injeksi API /api/application/users di protect13; create/delete user API ditangani protect14 V5 agar API key Admin ID 1 tetap bisa."
    elif grep -q "PROTEKSI_My_GilXz_API_ROOTADMIN" "$API_USER_CONTROLLER"; then
        echo "⚠️ Proteksi sudah ada, skip..."
    else
        # Proteksi method store (create user via API)
        STORE_LINE=$(grep -n "public function store" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$STORE_LINE" ]; then
            BRACE_LINE=$STORE_LINE
            for i in $(seq "$STORE_LINE" $((STORE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_My_GilXz_API_ROOTADMIN: Block non-ID 1 dari set root_admin via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1 && \\\$request->has('root_admin') && \\\$request->input('root_admin')) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan mengubah status admin via API'], 403); }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi store() API diinjeksi"
        fi

        # Proteksi method update (update user via API)
        UPDATE_LINE=$(grep -n "public function update" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$UPDATE_LINE" ]; then
            BRACE_LINE=$UPDATE_LINE
            for i in $(seq "$UPDATE_LINE" $((UPDATE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_My_GilXz_API_ROOTADMIN: Block non-ID 1 dari ubah root_admin via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1 && \\\$request->has('root_admin')) { \\\$user = \\\$this->repository->find(\\\$request->route('user')); if ((bool) \\\$request->input('root_admin') !== (bool) \\\$user->root_admin) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan mengubah status admin via API'], 403); } }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi update() API diinjeksi"
        fi

        # Proteksi method delete (hapus user via API)
        DELETE_LINE=$(grep -n "public function delete\|public function destroy" "$API_USER_CONTROLLER" | head -1 | cut -d: -f1)
        if [ -n "$DELETE_LINE" ]; then
            BRACE_LINE=$DELETE_LINE
            for i in $(seq "$DELETE_LINE" $((DELETE_LINE + 5))); do
                if sed -n "${i}p" "$API_USER_CONTROLLER" | grep -q "{"; then
                    BRACE_LINE=$i
                    break
                fi
            done
            sed -i "${BRACE_LINE}a\\        // PROTEKSI_My_GilXz_API_ROOTADMIN: Block non-ID 1 dari hapus user via API" "$API_USER_CONTROLLER"
            sed -i "$((BRACE_LINE + 1))a\\        if ((int) \\\$request->user()->id !== 1) { return response()->json(['error' => '${BRAND_TEXT} - Tidak diizinkan menghapus user via API'], 403); }" "$API_USER_CONTROLLER"
            echo "✅ Proteksi delete() API diinjeksi"
        fi
    fi
fi

echo "✅ BAGIAN 3 SELESAI"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BERSIHKAN CACHE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "🧹 Membersihkan cache..."

# Apply brand customization
if [ -f "$API_CONTROLLER" ]; then
  sed -i "s|Akses Application API tidak diizinkan|${BRAND_TEXT} - Akses ditolak|g" "$API_CONTROLLER" 2>/dev/null || true
fi

echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "==========================================="
echo "✅ INSTALLPROTECT13 SELESAI!"
echo "==========================================="
echo "🔒 Menu Application API disembunyikan (selain ID 1)"
echo "🔒 Akses controller Application API diblock (selain ID 1)"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
[ -f "${SIDEBAR_FILE}.bak_${TIMESTAMP}" ] && echo "   cp ${SIDEBAR_FILE}.bak_${TIMESTAMP} ${SIDEBAR_FILE}"
[ -f "${API_CONTROLLER}.bak_${TIMESTAMP}" ] && echo "   cp ${API_CONTROLLER}.bak_${TIMESTAMP} ${API_CONTROLLER}"
echo "   cd $PANEL_DIR && php artisan view:clear && php artisan route:clear"
