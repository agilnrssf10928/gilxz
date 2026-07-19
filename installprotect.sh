#!/bin/bash
# ============================================================
# INSTALL PROTECT MANAGER - PTERODACTYL PANEL
# Version: 2.1 (Fixed)
# ============================================================

set -e

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🛡️  INSTALL PROTECT MANAGER v2.1 (Fixed)    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Script harus dijalankan sebagai root!${NC}"
   exit 1
fi

# Cek folder panel
PANEL_PATH="/var/www/pterodactyl"
if [[ ! -d "$PANEL_PATH" ]]; then
    echo -e "${RED}❌ Folder panel tidak ditemukan di $PANEL_PATH${NC}"
    exit 1
fi

cd "$PANEL_PATH"

echo -e "${GREEN}✅ Panel ditemukan di $PANEL_PATH${NC}"

# ============================================================
# BAGIAN 1: BACKUP FILE
# ============================================================
echo -e "${YELLOW}📦 Membuat backup...${NC}"

BACKUP_DIR="/root/panel_backup_protect_$(date +%Y%m%d_%H%M%S)"

# FIX: mkdir dulu SEBELUM cp, bukan pakai || mkdir
mkdir -p "$BACKUP_DIR/views"

cp -r resources/views/admin/* "$BACKUP_DIR/views/" 2>/dev/null || true
cp routes/admin.php "$BACKUP_DIR/admin.php.bak" 2>/dev/null || true
cp resources/views/layouts/admin.blade.php "$BACKUP_DIR/admin.blade.php.bak" 2>/dev/null || true

echo -e "${GREEN}✅ Backup disimpan di: $BACKUP_DIR${NC}"

# ============================================================
# BAGIAN 2: BUAT VIEW PROTECT MANAGER
# ============================================================
echo -e "${YELLOW}📄 Membuat Blade View...${NC}"

cat > resources/views/admin/protect-manager.blade.php << 'EOF'
@extends('layouts.admin')

@section('title', 'Protect Manager')

@section('content')
<div class="container">
    <div class="row">
        <div class="col-12">
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">🛡️ Protect Manager</h3>
                </div>
                <div class="card-body">
                    <div class="alert alert-info">
                        <i class="fas fa-shield-alt"></i>
                        <b>Protect Manager aktif!</b> Panel ini hanya bisa diakses oleh Root Admin.
                    </div>

                    <div class="row mt-4">
                        <div class="col-md-6">
                            <div class="card">
                                <div class="card-body">
                                    <h5><i class="fas fa-server"></i> Server Protection</h5>
                                    <p>Kelola proteksi server secara bulk</p>
                                    <button class="btn btn-success btn-sm">Install Protect</button>
                                    <button class="btn btn-danger btn-sm">Uninstall Protect</button>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="card">
                                <div class="card-body">
                                    <h5><i class="fas fa-cog"></i> Settings</h5>
                                    <p>Kustomisasi proteksi & branding</p>
                                    <button class="btn btn-primary btn-sm">Edit Settings</button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="mt-4">
                        <div class="alert alert-warning">
                            <i class="fas fa-exclamation-triangle"></i>
                            <b>Info:</b> Fitur ini diinstall oleh Protect Manager
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection
EOF

echo -e "${GREEN}✅ View dibuat: resources/views/admin/protect-manager.blade.php${NC}"

# ============================================================
# BAGIAN 3: TAMBAH ROUTE
# ============================================================
echo -e "${YELLOW}🛣️ Menambahkan Route...${NC}"

if grep -q "protect-manager" routes/admin.php; then
    echo -e "${YELLOW}⚠️ Route sudah ada, skip...${NC}"
else
    # FIX: APPEND ke akhir file — BUKAN insert di baris 1 (yang merusak <?php)
    cat >> routes/admin.php << 'ROUTE_EOF'

/*
|--------------------------------------------------------------------------
| Protect Manager Route
|--------------------------------------------------------------------------
*/
Route::get('/protect-manager', function () {
    // FIX: pakai root_admin bukan hardcode id=1, lebih aman
    if (!auth()->user()->root_admin) {
        abort(403, 'Hanya Root Admin yang bisa akses halaman ini!');
    }
    return view('admin.protect-manager');
})->name('admin.protect.manager');
ROUTE_EOF

    echo -e "${GREEN}✅ Route ditambahkan ke routes/admin.php${NC}"
fi

# ============================================================
# BAGIAN 4: TAMBAH SIDEBAR MENU
# ============================================================
echo -e "${YELLOW}📌 Menambahkan Sidebar Menu...${NC}"

LAYOUT_FILE="resources/views/layouts/admin.blade.php"

if grep -q "protect-manager" "$LAYOUT_FILE"; then
    echo -e "${YELLOW}⚠️ Sidebar sudah ada, skip...${NC}"
else
    # FIX: Pakai Python3 untuk insert multiline yang akurat
    # Cari marker unik di sidebar Pterodactyl, insert menu SETELAH nav-item itu
    # Target: nav-item yang berisi link ke /admin/settings atau /admin/users

    python3 - "$LAYOUT_FILE" << 'PYEOF'
import sys

filepath = sys.argv[1]

with open(filepath, 'r') as f:
    content = f.read()

# Menu item yang mau disisipkan
menu_item = """
                <li class="nav-item">
                    <a href="{{ route('admin.protect.manager') }}" class="nav-link {{ Request::is('admin/protect-manager') ? 'active' : '' }}">
                        <i class="fas fa-shield-alt nav-icon"></i>
                        <p>Protect Manager</p>
                    </a>
                </li>"""

# Coba cari marker yang ada di sidebar Pterodactyl (urutan prioritas)
markers = ['admin/settings', 'admin/users', 'admin/nests', 'admin/nodes']
found = False

for marker in markers:
    idx = content.find(marker)
    if idx == -1:
        continue
    # Cari penutup </li> terdekat setelah marker ini
    close_li = content.find('</li>', idx)
    if close_li == -1:
        continue
    insert_pos = close_li + len('</li>')
    content = content[:insert_pos] + menu_item + content[insert_pos:]
    found = True
    print(f"OK: menu disisipkan setelah marker '{marker}'")
    break

if not found:
    print("FAIL: tidak ada marker yang cocok di layout file")
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(content)
PYEOF

    # Verifikasi hasil
    if grep -q "protect-manager" "$LAYOUT_FILE"; then
        echo -e "${GREEN}✅ Sidebar menu ditambahkan${NC}"
    else
        echo -e "${RED}❌ Gagal tambah sidebar otomatis${NC}"
        echo -e "${YELLOW}⚠️ Tambah manual ke $LAYOUT_FILE:${NC}"
        cat << 'MANUAL'
<li class="nav-item">
    <a href="{{ route('admin.protect.manager') }}" class="nav-link">
        <i class="fas fa-shield-alt nav-icon"></i>
        <p>Protect Manager</p>
    </a>
</li>
MANUAL
    fi
fi

# ============================================================
# BAGIAN 5: CLEAR CACHE
# ============================================================
echo -e "${YELLOW}🧹 Membersihkan cache...${NC}"

php artisan view:clear
php artisan route:clear
php artisan config:clear
php artisan cache:clear

echo -e "${GREEN}✅ Cache dibersihkan${NC}"

# ============================================================
# BAGIAN 6: SET PERMISSION
# ============================================================
echo -e "${YELLOW}🔧 Setting permission...${NC}"

chown -R www-data:www-data storage/* bootstrap/cache
chmod -R 755 storage/* bootstrap/cache

echo -e "${GREEN}✅ Permission diset${NC}"

# ============================================================
# SELESAI
# ============================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ INSTALL PROTECT MANAGER SELESAI!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📍 Akses: Panel Admin → Sidebar → Protect Manager${NC}"
echo -e "${BLUE}🔒 Hanya Root Admin yang bisa akses${NC}"
echo ""
echo -e "${YELLOW}📁 Backup disimpan di: $BACKUP_DIR${NC}"
echo -e "${YELLOW}⚠️ Kalau mau restore manual:${NC}"
echo -e "${YELLOW}   cp $BACKUP_DIR/admin.php.bak /var/www/pterodactyl/routes/admin.php${NC}"
echo -e "${YELLOW}   cp $BACKUP_DIR/admin.blade.php.bak /var/www/pterodactyl/resources/views/layouts/admin.blade.php${NC}"
