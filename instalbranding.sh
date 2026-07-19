#!/bin/bash

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🎨 Memasang branding My_GilXz Tech ke Pterodactyl Panel..."
echo ""

# === LANGKAH 1: Cari file layout utama ===
LAYOUT_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/master.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/auth.blade.php"
)

ADMIN_LAYOUT=""
MASTER_LAYOUT=""

for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    if [[ "$LF" == *"admin"* ]]; then
      ADMIN_LAYOUT="$LF"
    elif [[ "$LF" == *"master"* ]]; then
      MASTER_LAYOUT="$LF"
    fi
  fi
done

# Cari juga layout tambahan
if [ -z "$ADMIN_LAYOUT" ]; then
  ADMIN_LAYOUT=$(find /var/www/pterodactyl/resources/views/layouts/ -name "*.blade.php" -exec grep -l "admin" {} \; 2>/dev/null | head -1)
fi

if [ -z "$MASTER_LAYOUT" ]; then
  MASTER_LAYOUT=$(find /var/www/pterodactyl/resources/views/layouts/ -name "*.blade.php" 2>/dev/null | head -1)
fi

echo "📂 Admin layout: ${ADMIN_LAYOUT:-tidak ditemukan}"
echo "📂 Master layout: ${MASTER_LAYOUT:-tidak ditemukan}"
echo ""

# === LANGKAH 2: Inject CSS + Footer branding ===
inject_branding() {
  local FILE="$1"
  local LABEL="$2"

  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "⚠️ File $LABEL tidak ditemukan, skip."
    return
  fi

  if grep -q "BRANDING_My_GilXz" "$FILE"; then
    echo "⚠️ Branding sudah ada di $LABEL, skip."
    return
  fi

  cp "$FILE" "${FILE}.bak_${TIMESTAMP}"
  echo "📦 Backup: ${FILE}.bak_${TIMESTAMP}"

  python3 << PYEOF
layout = "$FILE"

with open(layout, "r") as f:
    content = f.read()

if "BRANDING_My_GilXz" in content:
    print("Sudah ada branding")
    exit(0)

# CSS branding
branding_css = """
<!-- BRANDING_My_GilXz: Custom Branding -->
<style>
  /* ===== My_GilXz Tech Branding - Cyber Red Neo-Brutalist ===== */
  .My_GilXz-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 9999;
    background: #0a0a0a;
    padding: 10px 18px;
    text-align: center;
    border-top: 3px solid #dc2626;
    box-shadow: 0 -4px 0 0 #fbbf24;
    font-family: 'JetBrains Mono', 'Courier New', monospace;
  }
  .My_GilXz-footer::before {
    content: "";
    position: absolute;
    top: -3px; left: 0; right: 0;
    height: 3px;
    background: repeating-linear-gradient(90deg, #dc2626 0 16px, #fbbf24 16px 32px, #0a0a0a 32px 48px);
  }
  .My_GilXz-footer .jt-inner {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    flex-wrap: wrap;
  }
  .My_GilXz-footer .jt-badge {
    background: #dc2626;
    color: #0a0a0a;
    padding: 4px 12px;
    border-radius: 0;
    border: 1.5px solid #0a0a0a;
    box-shadow: 2px 2px 0 0 #fbbf24;
    font-size: 11px;
    font-weight: 900;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    font-family: 'JetBrains Mono', monospace;
  }
  .My_GilXz-footer .jt-text {
    color: #e5e5e5;
    font-size: 13px;
    font-weight: 600;
    font-family: 'Segoe UI', system-ui, sans-serif;
  }
  .My_GilXz-footer .jt-text a {
    color: #fbbf24;
    text-decoration: none;
    font-weight: 900;
    border-bottom: 1.5px solid #dc2626;
    padding: 0 2px;
    transition: all 0.15s ease;
  }
  .My_GilXz-footer .jt-text a:hover {
    background: #dc2626;
    color: #fafafa;
    border-bottom-color: #fbbf24;
  }
  .My_GilXz-footer .jt-separator {
    color: #dc2626;
    font-weight: 900;
  }
  .My_GilXz-footer .jt-tg {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: #0a0a0a;
    border: 1.5px solid #fbbf24;
    padding: 3px 10px;
    border-radius: 0;
    color: #fbbf24;
    font-size: 11px;
    font-weight: 900;
    letter-spacing: 0.5px;
    text-decoration: none;
    font-family: 'JetBrains Mono', monospace;
    text-transform: uppercase;
    transition: all 0.15s ease;
  }
  .My_GilXz-footer .jt-tg:hover {
    background: #fbbf24;
    color: #0a0a0a;
    box-shadow: 2px 2px 0 0 #dc2626;
    transform: translate(-1px, -1px);
  }
  .My_GilXz-footer .jt-tg svg {
    width: 13px;
    height: 13px;
    fill: currentColor;
  }
  .My_GilXz-footer .jt-promo {
    color: #fafafa;
    font-size: 12px;
    font-weight: 700;
    font-family: 'Segoe UI', system-ui, sans-serif;
  }
  .My_GilXz-footer .jt-promo a {
    color: #0a0a0a;
    background: #fbbf24;
    text-decoration: none;
    font-weight: 900;
    padding: 1px 8px;
    border: 1.5px solid #0a0a0a;
    box-shadow: 2px 2px 0 0 #dc2626;
    font-family: 'JetBrains Mono', monospace;
    transition: all 0.15s ease;
    display: inline-block;
  }
  .My_GilXz-footer .jt-promo a:hover {
    background: #dc2626;
    color: #fafafa;
    box-shadow: 2px 2px 0 0 #fbbf24;
  }

  /* Beri ruang bawah agar footer tidak menutupi konten */
  body {
    padding-bottom: 56px !important;
  }

</style>
"""

# HTML footer
branding_html = """
<!-- BRANDING_My_GilXz: Footer -->
<div class="My_GilXz-footer">
  <div class="jt-inner">
    <span class="jt-badge">// PROTECTED</span>
    <span class="jt-text">PANEL BY <a href="https://t.me/My_GilXz" target="_blank">My_GilXz TECH</a></span>
    <span class="jt-separator">[/]</span>
    <a class="jt-tg" href="https://t.me/My_GilXz" target="_blank">
      <svg viewBox="0 0 24 24"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
      @My_GilXz
    </a>
    <span class="jt-separator">[/]</span>
    <span class="jt-promo">Butuh panel anti mokad? &rarr; <a href="https://t.me/upgradeuser_bot" target="_blank">@upgradeuser_bot</a></span>
  </div>
</div>

"""

# Inject sebelum </body>
if "</body>" in content:
    content = content.replace("</body>", branding_css + branding_html + "\n</body>")
    print("✅ Branding diinjeksi sebelum </body>")
elif "</html>" in content:
    content = content.replace("</html>", branding_css + branding_html + "\n</html>")
    print("✅ Branding diinjeksi sebelum </html>")
else:
    content += branding_css + branding_html
    print("✅ Branding ditambahkan di akhir file")

with open(layout, "w") as f:
    f.write(content)

PYEOF

  echo "✅ Branding dipasang di $LABEL"
}

# Inject ke semua layout yang ditemukan
for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    inject_branding "$LF" "$(basename $LF)"
  fi
done

# === LANGKAH 3: Ubah title panel ===
echo ""
echo "🔧 Mengubah judul panel..."

for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    if grep -q "<title>" "$LF" && ! grep -q "My_GilXz Tech" "$LF"; then
      sed -i 's/<title>.*<\/title>/<title>Pterodactyl - My_GilXz Tech<\/title>/g' "$LF" 2>/dev/null
      echo "✅ Title diubah di $(basename $LF)"
    fi
  fi
done

# === LANGKAH 4: Clear cache ===
cd /var/www/pterodactyl
php artisan view:clear 2>/dev/null
php artisan cache:clear 2>/dev/null
echo "✅ Cache dibersihkan"

echo ""
echo "==========================================="
echo "✅ Branding My_GilXz Tech terpasang!"
echo "==========================================="
echo "🎨 Footer keren dengan gradient ungu"
echo "🛡️ Badge 'Protected' + 'My_GilXz'"
echo "📱 Link Telegram @Ny_GilXz"
echo "🏷️ Tag panel di pojok kanan atas"
echo "📝 Title panel diubah"
echo "==========================================="
echo ""
echo "⚠️ Untuk hapus branding, restore backup:"
for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "${LF}.bak_${TIMESTAMP}" ]; then
    echo "   cp ${LF}.bak_${TIMESTAMP} $LF"
  fi
done
echo "   cd /var/www/pterodactyl && php artisan view:clear"