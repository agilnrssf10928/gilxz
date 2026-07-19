#!/bin/bash

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

BRAND_NAME="${BRAND_NAME:-My_GilXz Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@My_GilXz}"
BOT_LINK="${BOT_LINK:-@upgradeuser_bot}"
WELCOME_TITLE="${WELCOME_TITLE:-Welcome To Server $BRAND_NAME}"
WELCOME_MESSAGE="${WELCOME_MESSAGE:-Butuh panel legal yang anti mokad? langsung aja ke $BOT_LINK. Jika ada kendala dan ada yang ingin di tanyakan hubungi $CONTACT_TELEGRAM.}"

TELEGRAM_USERNAME="${CONTACT_TELEGRAM#@}"
BOT_USERNAME="${BOT_LINK#@}"

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

js_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

BRAND_NAME_HTML=$(html_escape "$BRAND_NAME")
BRAND_TEXT_HTML=$(html_escape "$BRAND_TEXT")
CONTACT_TELEGRAM_HTML=$(html_escape "$CONTACT_TELEGRAM")
BOT_LINK_HTML=$(html_escape "$BOT_LINK")
BRAND_NAME_JS=$(js_escape "$BRAND_NAME")
CONTACT_TELEGRAM_JS=$(js_escape "$CONTACT_TELEGRAM")
WELCOME_TITLE_JS=$(js_escape "$WELCOME_TITLE")
WELCOME_MESSAGE_JS=$(js_escape "$WELCOME_MESSAGE")
SAFE_TITLE=$(sed_escape "${PANEL_TITLE:-Pterodactyl - $BRAND_NAME}")

can_modify_file() {
  local file="$1"
  if [ -f "$file" ] && [ -w "$file" ]; then
    return 0
  fi

  local dir
  dir=$(dirname "$file")
  [ -w "$dir" ]
}

write_temp_to_target() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"

  if [ -f "$target_file" ]; then
    chmod u+w "$target_file" 2>/dev/null || true
    chown --reference="$target_file" "$temp_file" 2>/dev/null || true
    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
  fi

  if cat "$temp_file" > "$target_file" 2>/dev/null; then
    return 0
  fi

  if cp "$temp_file" "$target_file" 2>/dev/null; then
    return 0
  fi

  echo "⚠️ Tidak bisa menulis ke $label, skip. Cek permission file/folder target."
  return 1
}

remove_block_by_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip cleanup branding di $file karena tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v start="$start_marker" -v end="$end_marker" '
    index($0, start) { skip=1; next }
    skip && index($0, end) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

cleanup_old_branding() {
  local file="$1"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip branding cleanup di $file karena tidak writable"
    return 0
  fi

  remove_block_by_markers "$file" "<!-- BRANDING_My_GilXz_START -->" "<!-- BRANDING_My_GilXz_END -->"
  remove_block_by_markers "$file" "<!-- BRANDING_My_GilXz: Custom Branding -->" "</style>"

  tmp_file=$(mktemp)
  awk '
    BEGIN { skip=0; depth=0; seen_div=0 }
    /<!-- BRANDING_My_GilXz: Footer -->/ { skip=1; depth=0; seen_div=0; next }
    skip {
      line=$0
      opens=gsub(/<div[^>]*>/, "&", line)
      closes=gsub(/<\/div>/, "&", line)
      if (opens > 0) {
        depth += opens
        seen_div = 1
      }
      if (closes > 0) {
        depth -= closes
      }
      if (seen_div && depth <= 0) {
        skip=0
      }
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

inject_before_closing() {
  local file="$1"
  local snippet_file="$2"
  local label="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip inject ke $label karena file tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)

  if grep -q "</body>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/body>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </body> di $label"
  elif grep -q "</html>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/html>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </html> di $label"
  else
    cat "$snippet_file" > "$tmp_file"
    cat "$file" >> "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten ditambahkan di akhir $label"
  fi

  rm -f "$tmp_file"
}

echo "==========================================="
echo "🔒 INSTALLPROTECT5: Proteksi Nests + Branding + Welcome Banner"
echo "==========================================="
echo ""
echo "📦 Bagian 1: Proteksi Nests (Sembunyikan + Block Akses)"
echo "📦 Bagian 2: Branding Footer $BRAND_NAME"
echo "📦 Bagian 3: Welcome Banner Client Dashboard"
echo ""
echo "🚀 Memasang proteksi Nests (Sembunyikan + Block Akses)..."
echo ""

# === LANGKAH 1: Restore NestController dari backup asli ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 Controller di-restore dari backup paling awal: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

# === LANGKAH 2: Inject proteksi ke NestController ===
python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_My_GilXz" in content:
    print("⚠️ Proteksi sudah ada di NestController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)

    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])

        new_lines.append("        // PROTEKSI_My_GilXz: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by My_GilXz Tech');")
        new_lines.append("        }")

        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke NestController")
PYEOF

echo ""
echo "📋 Verifikasi NestController (cari PROTEKSI):"
grep -n "PROTEKSI_My_GilXz" "$CONTROLLER"
echo ""

# === LANGKAH 3: Proteksi juga EggController (halaman egg di dalam nest) ===
EGG_CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"
if [ -f "$EGG_CONTROLLER" ]; then
  if ! grep -q "PROTEKSI_My_GilXz" "$EGG_CONTROLLER"; then
    cp "$EGG_CONTROLLER" "${EGG_CONTROLLER}.bak_${TIMESTAMP}"

    python3 << 'PYEOF2'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_My_GilXz" in content:
    print("⚠️ Sudah ada proteksi di EggController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)

    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])

        new_lines.append("        // PROTEKSI_My_GilXz: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by My_GilXz Tech');")
        new_lines.append("        }")

        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ EggController juga diproteksi")
PYEOF2
  else
    echo "⚠️ EggController sudah diproteksi"
  fi
fi

# === LANGKAH 4: Sembunyikan menu Nests di sidebar ===
echo "🔧 Menyembunyikan menu Nests dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ] && grep -q "admin.nests" "$SF" 2>/dev/null; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"

  echo "📋 Baris terkait Nests di sidebar:"
  grep -n -i "nest" "$SIDEBAR_FOUND" | head -10
  echo ""

  if ! can_modify_file "$SIDEBAR_FOUND"; then
    echo "⚠️ Sidebar tidak writable, skip sembunyikan menu Nests."
  else
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" 2>/dev/null || true

    SIDEBAR_TEMP=$(mktemp)
    export SIDEBAR_FOUND SIDEBAR_TEMP
    python3 << 'PYEOF3'
import os

sidebar = os.environ["SIDEBAR_FOUND"]
sidebar_temp = os.environ["SIDEBAR_TEMP"]

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NESTS_SIDEBAR" in content:
    print("⚠️ Sidebar Nests sudah diproteksi")
    raise SystemExit(0)

import re

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
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.nests' in line or "route('admin.nests')" in line) and 'admin.nests.view' not in line and 'admin.nests.egg' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            li_open = new_lines[li_start:]
            new_lines = new_lines[:li_start]

            block = list(li_open)
            block.append(line)
            i += 1
            li_depth = 1 + sum(x.count('<li') - x.count('</li') for x in li_open)
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                block.append(curr)
                i += 1

            new_lines.append("{{-- PROTEKSI_NESTS_SIDEBAR --}}")
            new_lines.append("@if((int) Auth::user()->id === 1)")
            new_lines.extend(block)
            new_lines.append("@else")
            new_lines.append(lock_transform("\n".join(block)))
            new_lines.append("@endif")
            continue

    new_lines.append(line)
    i += 1

with open(sidebar_temp, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Temp sidebar berhasil dibuat")
PYEOF3

    if write_temp_to_target "$SIDEBAR_TEMP" "$SIDEBAR_FOUND" "$SIDEBAR_FOUND"; then
      echo "✅ Menu Nests disembunyikan dari sidebar"
    else
      echo "⚠️ Gagal menulis perubahan sidebar, skip langkah sembunyikan menu."
    fi

    rm -f "$SIDEBAR_TEMP"
  fi
else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === LANGKAH 5: Cache clear di-handle oleh controller ===
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller setelah install selesai"

echo ""
echo "==========================================="
echo "✅ Proteksi Nests LENGKAP selesai!"
echo "==========================================="
echo "🔒 Menu Nests disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/nests diblock (selain ID 1)"
echo "🔒 Akses /admin/nests/view/* diblock (selain ID 1)"
echo "🔒 EggController juga diproteksi"
echo "🚀 Panel tetap normal, server tetap jalan"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
echo "   cp ${CONTROLLER}.bak_${TIMESTAMP} $CONTROLLER"
if [ -n "$SIDEBAR_FOUND" ]; then
  echo "   cp ${SIDEBAR_FOUND}.bak_${TIMESTAMP} $SIDEBAR_FOUND"
fi
echo "   cd /var/www/pterodactyl && php artisan view:clear && php artisan route:clear"

# ============================================================
# === BRANDING: Inject footer brand ke layout panel ===
# ============================================================
echo ""
echo "🎨 Memasang branding $BRAND_NAME..."

LAYOUT_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

# Cleanup branding lama dari master.blade.php dan auth.blade.php jika ada
for CLEANUP_FILE in "/var/www/pterodactyl/resources/views/layouts/master.blade.php" "/var/www/pterodactyl/resources/views/layouts/auth.blade.php"; do
  if [ -f "$CLEANUP_FILE" ] && grep -q "BRANDING_My_GilXz" "$CLEANUP_FILE" 2>/dev/null; then
    cleanup_old_branding "$CLEANUP_FILE"
    echo "🧹 Branding lama dihapus dari $(basename "$CLEANUP_FILE")"
  fi
done

BRANDING_FOUND=0

inject_branding() {
  local FILE="$1"
  local LABEL="$2"

  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "⚠️ File $LABEL tidak ditemukan: $FILE"
    return
  fi

  BRANDING_FOUND=1

  if ! can_modify_file "$FILE"; then
    echo "⚠️ File $LABEL tidak writable, skip branding di file ini"
    return
  fi

  if [ ! -f "${FILE}.bak_${TIMESTAMP}" ]; then
    cp "$FILE" "${FILE}.bak_${TIMESTAMP}" 2>/dev/null || true
  fi

  cleanup_old_branding "$FILE"

  BRANDING_TMP="/tmp/branding_inject_${TIMESTAMP}_$(basename "$FILE").html"
  cat > "$BRANDING_TMP" << BRANDHTML
<!-- BRANDING_My_GilXz_START -->
<style>
  .My_GilXz-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 9999;
    background: #1f1f27;
    padding: 8px 18px;
    border-top: 1px solid #2c2c34;
    font-family: 'Source Sans Pro', 'Helvetica Neue', Helvetica, Arial, sans-serif;
    font-size: 12px;
    color: #9b9bb0;
    box-shadow: 0 -1px 0 rgba(0,0,0,0.25);
  }
  .My_GilXz-footer .jt-inner {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 14px;
    flex-wrap: wrap;
    line-height: 1.4;
  }
  .My_GilXz-footer .jt-brand {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    color: #c7c7d1;
    font-weight: 600;
    letter-spacing: 0.2px;
  }
  .My_GilXz-footer .jt-brand-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #0697e2;
    box-shadow: 0 0 6px rgba(6,151,226,0.6);
  }
  .My_GilXz-footer .jt-divider {
    width: 1px;
    height: 12px;
    background: #34343f;
  }
  .My_GilXz-footer a {
    color: #0697e2;
    text-decoration: none;
    font-weight: 600;
    transition: color 0.15s ease;
  }
  .My_GilXz-footer a:hover {
    color: #38b6ff;
    text-decoration: underline;
  }
  .My_GilXz-footer .jt-tg {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }
  .My_GilXz-footer .jt-tg svg {
    width: 12px;
    height: 12px;
    fill: currentColor;
    opacity: 0.85;
  }
  body { padding-bottom: 38px !important; }
  @media (max-width: 640px) {
    .My_GilXz-footer { font-size: 11px; padding: 7px 12px; }
    .My_GilXz-footer .jt-inner { gap: 10px; }
    .My_GilXz-footer .jt-divider { display: none; }
    body { padding-bottom: 56px !important; }
  }
</style>
<div class="My_GilXz-footer">
  <div class="jt-inner">
    <span class="jt-brand"><span class="jt-brand-dot"></span>$BRAND_TEXT_HTML</span>
    <span class="jt-divider"></span>
    <span>Powered by <a href="https://t.me/$TELEGRAM_USERNAME" target="_blank" rel="noopener">$BRAND_NAME_HTML</a></span>
    <span class="jt-divider"></span>
    <a class="jt-tg" href="https://t.me/$TELEGRAM_USERNAME" target="_blank" rel="noopener">
      <svg viewBox="0 0 24 24"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
      $CONTACT_TELEGRAM_HTML
    </a>
    <span class="jt-divider"></span>
    <span>Order panel via <a href="https://t.me/$BOT_USERNAME" target="_blank" rel="noopener">$BOT_LINK_HTML</a></span>
  </div>
</div>
<!-- BRANDING_My_GilXz_END -->
BRANDHTML

  inject_before_closing "$FILE" "$BRANDING_TMP" "$LABEL"
  rm -f "$BRANDING_TMP"
  echo "✅ Branding diperbarui di $LABEL"
}

BRANDING_APPLIED=0
for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    inject_branding "$LF" "$(basename "$LF")"
    if grep -q "BRANDING_My_GilXz" "$LF" 2>/dev/null; then
      BRANDING_APPLIED=1
    fi
  fi
done

if [ "$BRANDING_APPLIED" -eq 0 ]; then
  echo "❌ Branding admin gagal dipasang: layout admin tidak ditemukan atau tidak termodifikasi"
  exit 1
fi

for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ] && grep -q "<title>" "$LF"; then
    sed -i "s|<title>.*</title>|<title>$SAFE_TITLE</title>|g" "$LF" 2>/dev/null || true
    echo "✅ Title diubah di $(basename "$LF")"
  fi
done

echo "✅ Branding selesai!"

# ============================================================
# === BAGIAN 3: Welcome Banner di Client Dashboard ===
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Welcome Banner Client Dashboard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WRAPPER_FILE="/var/www/pterodactyl/resources/views/templates/wrapper.blade.php"
MASTER_FILE="/var/www/pterodactyl/resources/views/layouts/master.blade.php"

WELCOME_TARGET=""
if [ -f "$WRAPPER_FILE" ]; then
  WELCOME_TARGET="$WRAPPER_FILE"
elif [ -f "$MASTER_FILE" ]; then
  WELCOME_TARGET="$MASTER_FILE"
else
  WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/ -name "wrapper.blade.php" 2>/dev/null | head -1)
  if [ -z "$WELCOME_TARGET" ]; then
    WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/templates/ -name "*.blade.php" 2>/dev/null | head -1)
  fi
fi

if [ -z "$WELCOME_TARGET" ] || [ ! -f "$WELCOME_TARGET" ]; then
  echo "⚠️ File layout client tidak ditemukan, skip welcome banner."
else
  echo "📂 Target: $WELCOME_TARGET"

  cp "$WELCOME_TARGET" "${WELCOME_TARGET}.bak_${TIMESTAMP}" 2>/dev/null || true
  remove_block_by_markers "$WELCOME_TARGET" "<!-- WELCOME_My_GilXz: Welcome Banner -->" "<!-- /WELCOME_My_GilXz -->"
  # Bersihkan juga marker legacy dari versi sebelumnya
  remove_block_by_markers "$WELCOME_TARGET" "<!-- My_GilXz_WELCOME_START -->" "<!-- My_GilXz_WELCOME_END -->"
  remove_block_by_markers "$WELCOME_TARGET" "<!-- My_GilXz_WELCOME: Welcome Banner -->" "<!-- /My_GilXz_WELCOME -->"
  remove_block_by_markers "$WELCOME_TARGET" "<!-- WELCOME_My_GilXz_START -->" "<!-- WELCOME_My_GilXz_END -->"

  WELCOME_TEMP=$(mktemp)
  cat > "$WELCOME_TEMP" << WELCOME_EOF
<!-- WELCOME_My_GilXz: Welcome Banner -->
<style>
  .My_GilXz-welcome {
    background: #0a0a0a;
    border: 2px solid #dc2626;
    border-radius: 0;
    margin: 20px 24px 0 24px;
    font-family: 'JetBrains Mono', 'Courier New', monospace;
    color: #fafafa;
    box-shadow: 6px 6px 0 0 #dc2626;
    overflow: hidden;
    position: relative;
  }
  .My_GilXz-welcome::before {
    content: "";
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 3px;
    background: repeating-linear-gradient(90deg, #dc2626 0 12px, #fbbf24 12px 24px, #0a0a0a 24px 36px);
  }
  .My_GilXz-welcome .jw-header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 16px;
    background: #dc2626;
    border-bottom: 2px solid #0a0a0a;
  }
  .My_GilXz-welcome .jw-header .jw-dot {
    width: 10px;
    height: 10px;
    border-radius: 0;
    background: #fbbf24;
    border: 1.5px solid #0a0a0a;
  }
  .My_GilXz-welcome .jw-header .jw-title {
    color: #0a0a0a;
    font-size: 12px;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 2px;
    margin: 0;
    flex: 1;
    font-family: 'JetBrains Mono', monospace;
  }
  .My_GilXz-welcome .jw-header .jw-tag {
    font-size: 10px;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    color: #0a0a0a;
    border: 1.5px solid #0a0a0a;
    padding: 2px 8px;
    background: #fbbf24;
  }
  .My_GilXz-welcome .jw-body {
    display: flex;
    align-items: flex-start;
    gap: 16px;
    padding: 20px 22px;
    background: #0a0a0a;
  }
  .My_GilXz-welcome .jw-icon {
    width: 46px;
    height: 46px;
    min-width: 46px;
    border-radius: 0;
    background: #dc2626;
    color: #fafafa;
    border: 2px solid #fbbf24;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .My_GilXz-welcome .jw-icon svg { width: 22px; height: 22px; fill: currentColor; }
  .My_GilXz-welcome .jw-content { flex: 1; min-width: 0; }
  .My_GilXz-welcome .jw-content h3 {
    color: #fbbf24;
    font-size: 18px;
    font-weight: 900;
    margin: 0 0 6px 0;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    font-family: 'JetBrains Mono', monospace;
  }
  .My_GilXz-welcome .jw-content h3::before {
    content: "[ ";
    color: #dc2626;
  }
  .My_GilXz-welcome .jw-content h3::after {
    content: " ]";
    color: #dc2626;
  }
  .My_GilXz-welcome .jw-content p {
    color: #e5e5e5;
    font-size: 13px;
    margin: 0;
    line-height: 1.65;
    font-family: 'Segoe UI', system-ui, sans-serif;
  }
  .My_GilXz-welcome .jw-content a {
    color: #fbbf24;
    font-weight: 700;
    text-decoration: none;
    border-bottom: 1.5px solid #dc2626;
    padding: 0 2px;
    transition: all 0.15s ease;
  }
  .My_GilXz-welcome .jw-content a:hover {
    background: #dc2626;
    color: #fafafa;
    border-bottom-color: #fbbf24;
  }
  @media (max-width: 640px) {
    .My_GilXz-welcome { margin: 14px 12px 0 12px; box-shadow: 4px 4px 0 0 #dc2626; }
    .My_GilXz-welcome .jw-body { padding: 16px; gap: 12px; }
    .My_GilXz-welcome .jw-content h3 { font-size: 15px; letter-spacing: 1px; }
    .My_GilXz-welcome .jw-content p { font-size: 12px; }
    .My_GilXz-welcome .jw-header .jw-tag { display: none; }
  }
</style>
<script>
document.addEventListener("DOMContentLoaded", function() {
  var ICON_SVG = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>';
  function injectWelcome() {
    if (document.getElementById("My_GilXz-welcome-banner")) return;
    var containers = [
      document.querySelector("[class*=ContentContainer]"),
      document.querySelector("[class*=content-wrapper]"),
      document.querySelector("#app > div > div:last-child"),
      document.querySelector("main"),
      document.querySelector(".content-wrapper"),
      document.querySelector("#app")
    ];
    var target = null;
    for (var i = 0; i < containers.length; i++) {
      if (containers[i]) { target = containers[i]; break; }
    }
    if (!target) return;
    var banner = document.createElement("div");
    banner.id = "My_GilXz-welcome-banner";
    banner.className = "My_GilXz-welcome";
    banner.innerHTML = ''
      + '<div class="jw-header">'
      +   '<span class="jw-dot"></span>'
      +   '<h4 class="jw-title">// SYSTEM_NOTICE.SYS</h4>'
      +   '<span class="jw-tag">● VERIFIED</span>'
      + '</div>'
      + '<div class="jw-body">'
      +   '<div class="jw-icon">' + ICON_SVG + '</div>'
      +   '<div class="jw-content"><h3>$WELCOME_TITLE_JS</h3><p>$WELCOME_MESSAGE_JS</p></div>'
      + '</div>';
    if (target.firstChild) { target.insertBefore(banner, target.firstChild); }
    else { target.appendChild(banner); }
  }
  injectWelcome();
  var observer = new MutationObserver(function() {
    if (!document.getElementById("My_GilXz-welcome-banner")) injectWelcome();
  });
  var appEl = document.getElementById("app") || document.body;
  observer.observe(appEl, { childList: true, subtree: true });
});
</script>
<!-- /WELCOME_My_GilXz -->
WELCOME_EOF

  inject_before_closing "$WELCOME_TARGET" "$WELCOME_TEMP" "$(basename "$WELCOME_TARGET")"
  rm -f "$WELCOME_TEMP"
  echo "✅ Welcome banner diperbarui di $(basename "$WELCOME_TARGET")"
fi

# ===================================================================
# RE-INJECT SIDEBAR PROTECT MANAGER (jika hilang setelah modifikasi admin.blade.php)
# ===================================================================
ADMIN_LAYOUT=""
for CANDIDATE in \
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"; do
  if [ -f "$CANDIDATE" ]; then
    ADMIN_LAYOUT="$CANDIDATE"
    break
  fi
done

if [ -f "$ADMIN_LAYOUT" ] && ! grep -q "PROTEKSI_My_GilXz_MASTER_SIDEBAR" "$ADMIN_LAYOUT" 2>/dev/null; then
  echo "🔧 Re-inject sidebar Protect Manager..."

  SIDEBAR_SNIPPET=$(mktemp)
  cat > "$SIDEBAR_SNIPPET" << 'SIDEBAR_PM_EOF'
                {{-- PROTEKSI_My_GilXz_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_My_GilXz_MASTER_SIDEBAR --}}
SIDEBAR_PM_EOF

  INSERT_LINE=""
  SETTINGS_LINE=$(grep -n "admin.settings\|Configuration\|Settings\|settings" "$ADMIN_LAYOUT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$SETTINGS_LINE" ]; then
    INSERT_LINE=$((SETTINGS_LINE - 1))
    while [ "$INSERT_LINE" -gt 0 ]; do
      if sed -n "${INSERT_LINE}p" "$ADMIN_LAYOUT" | grep -q "<li"; then
        break
      fi
      INSERT_LINE=$((INSERT_LINE - 1))
    done
  fi

  if [ -z "$INSERT_LINE" ] || [ "$INSERT_LINE" -le 0 ]; then
    INSERT_LINE=$(grep -n "</ul>" "$ADMIN_LAYOUT" | tail -1 | cut -d: -f1)
    if [ -n "$INSERT_LINE" ]; then
      INSERT_LINE=$((INSERT_LINE - 1))
    fi
  fi

  if [ -n "$INSERT_LINE" ] && [ "$INSERT_LINE" -gt 0 ]; then
    TEMP_LAYOUT=$(mktemp)
    head -n "$INSERT_LINE" "$ADMIN_LAYOUT" > "$TEMP_LAYOUT"
    cat "$SIDEBAR_SNIPPET" >> "$TEMP_LAYOUT"
    tail -n +"$((INSERT_LINE + 1))" "$ADMIN_LAYOUT" >> "$TEMP_LAYOUT"
    if cat "$TEMP_LAYOUT" > "$ADMIN_LAYOUT" 2>/dev/null; then
      echo "✅ Sidebar Protect Manager berhasil di-re-inject"
    else
      echo "⚠️ Gagal re-inject sidebar, skip"
    fi
    rm -f "$TEMP_LAYOUT"
  else
    echo "⚠️ Tidak bisa menemukan posisi sidebar untuk re-inject"
  fi
  rm -f "$SIDEBAR_SNIPPET"
fi

# ===================================================================
# CLEAR CACHE - paksa clear di sini agar welcome banner langsung tampil
# ===================================================================
if [ -d /var/www/pterodactyl ]; then
  cd /var/www/pterodactyl
  php artisan view:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  rm -rf /var/www/pterodactyl/storage/framework/views/*.php 2>/dev/null || true
  echo "✅ View & compiled blade cache dibersihkan"
fi

echo ""
echo "==========================================="
echo "✅ INSTALLPROTECT5 SELESAI!"
echo "==========================================="
echo "🔒 Menu Nests disembunyikan (selain ID 1)"
echo "🔒 Akses NestController diblock (selain ID 1)"
echo "🎨 Branding footer $BRAND_NAME terpasang (hanya admin)"
echo "📝 Title panel diubah"
echo "📋 Welcome banner terpasang di client dashboard"
echo "📱 Kontak: $CONTACT_TELEGRAM"
echo "==========================================="
# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_ADMIN" ]; then
  for F in "$CONTROLLER" "$EGG_CONTROLLER"; do
    [ -f "$F" ] || continue
    python3 - "$F" "$DENY_MSG_ADMIN" << 'PYABORT'
import sys, re
path, msg = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r"abort\(\s*403\s*,\s*(['\"])(?:\\\1|(?!\1).)*\1\s*\)",
    "abort(403, " + repr(msg) + ")",
    content
)
if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✏️  Pesan akses ditolak dikustomisasi di " + path)
PYABORT
  done
fi
