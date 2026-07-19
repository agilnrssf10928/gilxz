#!/bin/bash
# ============================================================
# INSTALL PROTECT MANAGER - PTERODACTYL PANEL
# Version: 3.0 (Full Featured)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     🛡️  INSTALL PROTECT MANAGER v3.0 Full       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
}

section() {
    echo -e ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

banner

# Cek root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Harus dijalankan sebagai root!${NC}"
    exit 1
fi

PANEL_PATH="/var/www/pterodactyl"
if [[ ! -d "$PANEL_PATH" ]]; then
    echo -e "${RED}❌ Folder panel tidak ditemukan di $PANEL_PATH${NC}"
    exit 1
fi

cd "$PANEL_PATH"
echo -e "${GREEN}✅ Panel ditemukan di $PANEL_PATH${NC}"

# ============================================================
# BAGIAN 1: BACKUP
# ============================================================
section "📦 BAGIAN 1: Backup File"

TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/panel_backup_protect_$TS"
mkdir -p "$BACKUP_DIR/views"

cp -r resources/views/admin/* "$BACKUP_DIR/views/" 2>/dev/null || true
cp routes/admin.php "$BACKUP_DIR/admin.php.bak" 2>/dev/null || true
cp resources/views/layouts/admin.blade.php "$BACKUP_DIR/admin.blade.php.bak" 2>/dev/null || true

echo -e "${GREEN}✅ Backup disimpan di: $BACKUP_DIR${NC}"

# ============================================================
# BAGIAN 2: BUAT CONFIG JSON
# ============================================================
section "⚙️  BAGIAN 2: Buat Config JSON"

CONFIG_PATH="$PANEL_PATH/storage/app/protect-config.json"

if [[ ! -f "$CONFIG_PATH" ]]; then
    cat > "$CONFIG_PATH" << 'CONFIGEOF'
{
    "brand_name": "Protect Manager",
    "contact": "@admin",
    "panel_title": "Protected Panel",
    "denied_message": "Server ini dilindungi! Hubungi admin untuk info lebih lanjut.",
    "protection_types": [
        {"id": 1, "name": "Basic Protect", "description": "Proteksi dasar server"},
        {"id": 2, "name": "Premium Protect", "description": "Proteksi premium server"},
        {"id": 3, "name": "VIP Protect", "description": "Proteksi VIP eksklusif"}
    ],
    "protected_servers": {}
}
CONFIGEOF
    chown www-data:www-data "$CONFIG_PATH"
    echo -e "${GREEN}✅ Config JSON dibuat: $CONFIG_PATH${NC}"
else
    echo -e "${YELLOW}⚠️  Config JSON sudah ada, skip...${NC}"
fi

# ============================================================
# BAGIAN 3: BUAT BLADE VIEW
# ============================================================
section "🎨 BAGIAN 3: Buat Blade View"

cat > resources/views/admin/protect-manager.blade.php << 'BLADEEOF'
@extends('layouts.admin')

@section('title', 'Protect Manager')

@section('content-header')
    <h1>🛡️ Protect Manager <small>v3.0</small></h1>
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="{{ route('admin.index') }}"><i class="fas fa-tachometer-alt"></i> Admin</a></li>
        <li class="breadcrumb-item active">Protect Manager</li>
    </ol>
@endsection

@section('content')

@if(session('success'))
<div class="alert alert-success alert-dismissible">
    <button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>
    <i class="fas fa-check-circle"></i> {{ session('success') }}
</div>
@endif

@if(session('error'))
<div class="alert alert-danger alert-dismissible">
    <button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>
    <i class="fas fa-exclamation-circle"></i> {{ session('error') }}
</div>
@endif

<div class="card card-primary card-outline">
    <div class="card-header p-0 border-bottom-0">
        <ul class="nav nav-tabs" id="protectTabs" role="tablist">
            <li class="nav-item">
                <a class="nav-link active" data-toggle="tab" href="#tab-servers" role="tab">
                    🖥️ Server Protection
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" data-toggle="tab" href="#tab-settings" role="tab">
                    ⚙️ Brand Settings
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" data-toggle="tab" href="#tab-types" role="tab">
                    📋 Tipe Proteksi
                </a>
            </li>
        </ul>
    </div>

    <div class="card-body">
        <div class="tab-content" id="protectTabsContent">

            {{-- ===================== TAB 1: SERVER PROTECTION ===================== --}}
            <div class="tab-pane fade show active" id="tab-servers" role="tabpanel">

                <div class="alert alert-info">
                    <i class="fas fa-info-circle"></i>
                    Centang server yang mau diproteksi, pilih tipe proteksi, lalu klik tombol aksi.
                    Total server: <strong>{{ $servers->count() }}</strong> |
                    Terproteksi: <strong>{{ count($config['protected_servers'] ?? []) }}</strong>
                </div>

                <form action="{{ route('admin.protect.toggle') }}" method="POST" id="serverForm">
                    @csrf
                    <div class="row mb-3">
                        <div class="col-md-3">
                            <label class="font-weight-bold">Tipe Proteksi:</label>
                            <select name="type_id" class="form-control form-control-sm">
                                @foreach($config['protection_types'] ?? [] as $type)
                                <option value="{{ $type['id'] }}">{{ $type['name'] }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="col-md-9 d-flex align-items-end">
                            <button type="submit" name="action" value="install"
                                class="btn btn-success btn-sm mr-2">
                                <i class="fas fa-shield-alt"></i> Install Protect
                            </button>
                            <button type="submit" name="action" value="uninstall"
                                class="btn btn-danger btn-sm mr-2">
                                <i class="fas fa-times-circle"></i> Uninstall Protect
                            </button>
                            <span class="text-muted small ml-2" id="selectedCount">0 server dipilih</span>
                        </div>
                    </div>

                    <div class="table-responsive">
                        <table class="table table-hover table-sm table-bordered">
                            <thead class="thead-dark">
                                <tr>
                                    <th width="40">
                                        <input type="checkbox" id="checkAll" title="Pilih semua">
                                    </th>
                                    <th>Nama Server</th>
                                    <th>Owner</th>
                                    <th>UUID</th>
                                    <th>Node</th>
                                    <th>Status Proteksi</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($servers as $server)
                                @php
                                    $protectedServers = $config['protected_servers'] ?? [];
                                    $isProtected = isset($protectedServers[$server->uuid]);
                                    $protectTypeId = $isProtected ? $protectedServers[$server->uuid] : null;
                                    $typeName = '';
                                    foreach ($config['protection_types'] ?? [] as $t) {
                                        if ($t['id'] == $protectTypeId) {
                                            $typeName = $t['name'];
                                            break;
                                        }
                                    }
                                @endphp
                                <tr class="{{ $isProtected ? 'table-success' : '' }}">
                                    <td class="text-center">
                                        <input type="checkbox" name="servers[]"
                                            value="{{ $server->uuid }}"
                                            class="server-checkbox">
                                    </td>
                                    <td>
                                        <i class="fas fa-server text-muted mr-1"></i>
                                        <strong>{{ $server->name }}</strong>
                                    </td>
                                    <td>{{ $server->user->username ?? '-' }}</td>
                                    <td>
                                        <code class="text-muted" style="font-size:11px">
                                            {{ substr($server->uuid, 0, 8) }}...
                                        </code>
                                    </td>
                                    <td>{{ $server->node->name ?? '-' }}</td>
                                    <td>
                                        @if($isProtected)
                                            <span class="badge badge-success">
                                                <i class="fas fa-lock"></i> {{ $typeName }}
                                            </span>
                                        @else
                                            <span class="badge badge-secondary">
                                                <i class="fas fa-unlock"></i> Tidak Diproteksi
                                            </span>
                                        @endif
                                    </td>
                                </tr>
                                @empty
                                <tr>
                                    <td colspan="6" class="text-center text-muted py-4">
                                        <i class="fas fa-inbox fa-2x mb-2"></i><br>
                                        Tidak ada server di panel ini
                                    </td>
                                </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </form>
            </div>

            {{-- ===================== TAB 2: BRAND SETTINGS ===================== --}}
            <div class="tab-pane fade" id="tab-settings" role="tabpanel">

                <div class="alert alert-info">
                    <i class="fas fa-paint-brush"></i>
                    Kustomisasi nama brand, kontak, dan pesan yang ditampilkan ke user.
                </div>

                <form action="{{ route('admin.protect.settings') }}" method="POST">
                    @csrf
                    <div class="form-group row">
                        <label class="col-md-3 col-form-label font-weight-bold">
                            <i class="fas fa-tag text-primary"></i> Nama Brand
                        </label>
                        <div class="col-md-6">
                            <input type="text" name="brand_name" class="form-control"
                                value="{{ $config['brand_name'] ?? '' }}"
                                placeholder="cth: Panel Gua">
                            <small class="text-muted">Nama brand yang muncul di halaman proteksi</small>
                        </div>
                    </div>

                    <div class="form-group row">
                        <label class="col-md-3 col-form-label font-weight-bold">
                            <i class="fas fa-phone text-success"></i> Kontak Admin
                        </label>
                        <div class="col-md-6">
                            <input type="text" name="contact" class="form-control"
                                value="{{ $config['contact'] ?? '' }}"
                                placeholder="cth: @my_telegram atau WA: 08xx">
                            <small class="text-muted">Kontak yang ditampilkan ke user saat akses ditolak</small>
                        </div>
                    </div>

                    <div class="form-group row">
                        <label class="col-md-3 col-form-label font-weight-bold">
                            <i class="fas fa-heading text-warning"></i> Judul Panel
                        </label>
                        <div class="col-md-6">
                            <input type="text" name="panel_title" class="form-control"
                                value="{{ $config['panel_title'] ?? '' }}"
                                placeholder="cth: Protected Game Panel">
                            <small class="text-muted">Judul panel yang kustom</small>
                        </div>
                    </div>

                    <div class="form-group row">
                        <label class="col-md-3 col-form-label font-weight-bold">
                            <i class="fas fa-ban text-danger"></i> Pesan Akses Ditolak
                        </label>
                        <div class="col-md-6">
                            <textarea name="denied_message" class="form-control" rows="4"
                                placeholder="Pesan yang muncul saat user coba akses server yang dilindungi...">{{ $config['denied_message'] ?? '' }}</textarea>
                            <small class="text-muted">Pesan ini muncul saat user akses server yang diproteksi</small>
                        </div>
                    </div>

                    <div class="form-group row">
                        <div class="col-md-6 offset-md-3">
                            <button type="submit" class="btn btn-primary">
                                <i class="fas fa-save"></i> Simpan Settings
                            </button>
                        </div>
                    </div>
                </form>
            </div>

            {{-- ===================== TAB 3: TIPE PROTEKSI ===================== --}}
            <div class="tab-pane fade" id="tab-types" role="tabpanel">

                <div class="alert alert-info">
                    <i class="fas fa-list"></i>
                    Edit nama dan deskripsi setiap tipe proteksi.
                    Tipe ini yang muncul sebagai pilihan saat install proteksi ke server.
                </div>

                <form action="{{ route('admin.protect.types') }}" method="POST">
                    @csrf
                    <table class="table table-bordered">
                        <thead class="thead-dark">
                            <tr>
                                <th width="60">#</th>
                                <th>Nama Proteksi</th>
                                <th>Deskripsi</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach($config['protection_types'] ?? [] as $i => $type)
                            <tr>
                                <td class="text-center align-middle">
                                    <span class="badge badge-primary">{{ $type['id'] }}</span>
                                    <input type="hidden" name="type_id[]" value="{{ $type['id'] }}">
                                </td>
                                <td>
                                    <input type="text" name="type_name[]" class="form-control"
                                        value="{{ $type['name'] }}"
                                        placeholder="Nama tipe proteksi">
                                </td>
                                <td>
                                    <input type="text" name="type_desc[]" class="form-control"
                                        value="{{ $type['description'] }}"
                                        placeholder="Deskripsi singkat">
                                </td>
                            </tr>
                            @endforeach
                        </tbody>
                    </table>
                    <button type="submit" class="btn btn-primary">
                        <i class="fas fa-save"></i> Simpan Tipe Proteksi
                    </button>
                </form>
            </div>

        </div>
    </div>
</div>
@endsection

@section('footer-scripts')
@parent
<script>
    // Check all / uncheck all
    const checkAll = document.getElementById('checkAll');
    const checkboxes = document.querySelectorAll('.server-checkbox');
    const selectedCount = document.getElementById('selectedCount');

    function updateCount() {
        const checked = document.querySelectorAll('.server-checkbox:checked').length;
        selectedCount.textContent = checked + ' server dipilih';
    }

    if (checkAll) {
        checkAll.addEventListener('change', function () {
            checkboxes.forEach(cb => cb.checked = this.checked);
            updateCount();
        });
    }

    checkboxes.forEach(cb => cb.addEventListener('change', updateCount));

    // Konfirmasi sebelum uninstall
    document.getElementById('serverForm')?.addEventListener('submit', function (e) {
        const action = document.activeElement?.value;
        const checked = document.querySelectorAll('.server-checkbox:checked').length;

        if (checked === 0) {
            e.preventDefault();
            alert('⚠️ Pilih minimal 1 server dulu!');
            return;
        }

        if (action === 'uninstall') {
            if (!confirm('❗ Yakin mau uninstall proteksi dari ' + checked + ' server?')) {
                e.preventDefault();
            }
        }
    });

    // Aktifkan tab dari hash URL
    const hash = window.location.hash;
    if (hash) {
        const tab = document.querySelector('[href="' + hash + '"]');
        if (tab) tab.click();
    }
</script>
@endsection
BLADEEOF

echo -e "${GREEN}✅ View dibuat: resources/views/admin/protect-manager.blade.php${NC}"

# ============================================================
# BAGIAN 4: TAMBAH ROUTES
# ============================================================
section "🛣️  BAGIAN 4: Tambah Route"

ROUTE_FILE="routes/admin.php"

if grep -q "protect-manager" "$ROUTE_FILE"; then
    echo -e "${YELLOW}⚠️  Route sudah ada, skip...${NC}"
else
    cp "$ROUTE_FILE" "$BACKUP_DIR/admin.php.bak"

    cat >> "$ROUTE_FILE" << 'ROUTEEOF'

/*
|--------------------------------------------------------------------------
| Protect Manager Routes — hanya Root Admin
|--------------------------------------------------------------------------
*/
Route::group(['prefix' => 'protect-manager', 'middleware' => ['web', 'auth', 'admin']], function () {

    // GET: Halaman utama
    Route::get('/', function () {
        if (!auth()->user()->root_admin) {
            abort(403, 'Hanya Root Admin yang bisa akses Protect Manager!');
        }
        $configPath = storage_path('app/protect-config.json');
        $default = [
            'brand_name'       => 'Protect Manager',
            'contact'          => '@admin',
            'panel_title'      => 'Protected Panel',
            'denied_message'   => 'Server ini dilindungi! Hubungi admin.',
            'protection_types' => [
                ['id' => 1, 'name' => 'Basic Protect',   'description' => 'Proteksi dasar server'],
                ['id' => 2, 'name' => 'Premium Protect', 'description' => 'Proteksi premium server'],
                ['id' => 3, 'name' => 'VIP Protect',     'description' => 'Proteksi VIP eksklusif'],
            ],
            'protected_servers' => [],
        ];
        $config = file_exists($configPath)
            ? array_merge($default, json_decode(file_get_contents($configPath), true) ?? [])
            : $default;
        $servers = \Pterodactyl\Models\Server::with(['user', 'node'])->orderBy('name')->get();
        return view('admin.protect-manager', compact('config', 'servers'));
    })->name('admin.protect.manager');

    // POST: Install / Uninstall proteksi ke server
    Route::post('/toggle', function () {
        if (!auth()->user()->root_admin) abort(403);
        $configPath = storage_path('app/protect-config.json');
        $config = file_exists($configPath)
            ? json_decode(file_get_contents($configPath), true) ?? []
            : [];
        if (!isset($config['protected_servers'])) $config['protected_servers'] = [];

        $action    = request('action');
        $serverIds = request('servers', []);
        $typeId    = (int) request('type_id', 1);

        if (empty($serverIds)) {
            return redirect()->route('admin.protect.manager')
                ->with('error', 'Pilih minimal 1 server!');
        }

        foreach ($serverIds as $uuid) {
            if ($action === 'install') {
                $config['protected_servers'][$uuid] = $typeId;
            } else {
                unset($config['protected_servers'][$uuid]);
            }
        }

        file_put_contents($configPath, json_encode($config, JSON_PRETTY_PRINT));
        $msg = $action === 'install'
            ? '✅ Proteksi berhasil diinstall ke ' . count($serverIds) . ' server!'
            : '🗑️ Proteksi berhasil diuninstall dari ' . count($serverIds) . ' server!';
        return redirect()->route('admin.protect.manager')->with('success', $msg);
    })->name('admin.protect.toggle');

    // POST: Simpan brand settings
    Route::post('/settings', function () {
        if (!auth()->user()->root_admin) abort(403);
        $configPath = storage_path('app/protect-config.json');
        $config = file_exists($configPath)
            ? json_decode(file_get_contents($configPath), true) ?? []
            : [];

        $config['brand_name']     = request('brand_name');
        $config['contact']        = request('contact');
        $config['panel_title']    = request('panel_title');
        $config['denied_message'] = request('denied_message');

        file_put_contents($configPath, json_encode($config, JSON_PRETTY_PRINT));
        return redirect()->route('admin.protect.manager')
            ->with('success', '✅ Brand settings berhasil disimpan!')
            ->withFragment('tab-settings');
    })->name('admin.protect.settings');

    // POST: Simpan tipe proteksi
    Route::post('/types', function () {
        if (!auth()->user()->root_admin) abort(403);
        $configPath = storage_path('app/protect-config.json');
        $config = file_exists($configPath)
            ? json_decode(file_get_contents($configPath), true) ?? []
            : [];

        $names = request('type_name', []);
        $descs = request('type_desc', []);
        $ids   = request('type_id', []);
        $types = [];
        foreach ($names as $i => $name) {
            if (!empty(trim($name))) {
                $types[] = [
                    'id'          => isset($ids[$i]) ? (int)$ids[$i] : ($i + 1),
                    'name'        => trim($name),
                    'description' => trim($descs[$i] ?? ''),
                ];
            }
        }
        $config['protection_types'] = $types;

        file_put_contents($configPath, json_encode($config, JSON_PRETTY_PRINT));
        return redirect()->route('admin.protect.manager')
            ->with('success', '✅ Tipe proteksi berhasil disimpan!')
            ->withFragment('tab-types');
    })->name('admin.protect.types');

});
ROUTEEOF

    echo -e "${GREEN}✅ Routes ditambahkan ke $ROUTE_FILE${NC}"
fi

# ============================================================
# BAGIAN 5: TAMBAH SIDEBAR MENU
# ============================================================
section "📌 BAGIAN 5: Tambah Sidebar Menu"

LAYOUT_FILE="resources/views/layouts/admin.blade.php"

if grep -q "protect-manager" "$LAYOUT_FILE"; then
    echo -e "${YELLOW}⚠️  Sidebar sudah ada, skip...${NC}"
else
    cp "$LAYOUT_FILE" "$BACKUP_DIR/admin.blade.php.bak"

    python3 - "$LAYOUT_FILE" << 'PYEOF'
import sys, re

filepath = sys.argv[1]

with open(filepath, 'r') as f:
    content = f.read()

menu_item = """
                <li class="nav-item">
                    <a href="{{ route('admin.protect.manager') }}" class="nav-link {{ Request::is('admin/protect-manager*') ? 'active' : '' }}">
                        <i class="nav-icon fas fa-shield-alt" style="color:#28a745"></i>
                        <p>Protect Manager</p>
                    </a>
                </li>"""

# Marker yang pasti ada di layout Pterodactyl (urutan prioritas)
markers = [
    "admin/settings",
    "admin/users",
    "admin/nests",
    "admin/nodes",
    "admin/databases",
    "admin/locations",
]

found = False
for marker in markers:
    idx = content.find(marker)
    if idx == -1:
        continue
    close_li = content.find('</li>', idx)
    if close_li == -1:
        continue
    insert_pos = close_li + len('</li>')
    content = content[:insert_pos] + menu_item + content[insert_pos:]
    found = True
    print(f"OK: menu disisipkan setelah marker '{marker}' (baris ~{content[:insert_pos].count(chr(10))})")
    break

if not found:
    print("FAIL: tidak ada marker yang cocok")
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(content)
PYEOF

    if grep -q "protect-manager" "$LAYOUT_FILE"; then
        echo -e "${GREEN}✅ Sidebar menu berhasil ditambahkan${NC}"
    else
        echo -e "${RED}❌ Gagal otomatis. Tambah manual ke $LAYOUT_FILE:${NC}"
        echo -e "${YELLOW}<li class=\"nav-item\">
    <a href=\"{{ route('admin.protect.manager') }}\" class=\"nav-link\">
        <i class=\"nav-icon fas fa-shield-alt\"></i>
        <p>Protect Manager</p>
    </a>
</li>${NC}"
    fi
fi

# ============================================================
# BAGIAN 6: CLEAR CACHE
# ============================================================
section "🧹 BAGIAN 6: Clear Cache"

php artisan view:clear
php artisan route:clear
php artisan config:clear
php artisan cache:clear

echo -e "${GREEN}✅ Semua cache dibersihkan${NC}"

# ============================================================
# BAGIAN 7: SET PERMISSION
# ============================================================
section "🔧 BAGIAN 7: Set Permission"

chown -R www-data:www-data storage/* bootstrap/cache
chmod -R 755 storage/* bootstrap/cache

echo -e "${GREEN}✅ Permission diset${NC}"

# ============================================================
# SELESAI
# ============================================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       ✅ INSTALL PROTECT MANAGER SELESAI!         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🛡️  Fitur yang terinstall:${NC}"
echo -e "   • Sidebar menu 'Protect Manager' (hanya Root Admin)"
echo -e "   • Install/Uninstall proteksi via centang & klik"
echo -e "   • Edit nama brand, teks proteksi, kontak"
echo -e "   • Edit nama & deskripsi setiap proteksi"
echo -e "   • Kustomisasi pesan akses ditolak & judul panel"
echo -e "   • Bulk install (centang beberapa, terapkan sekaligus)"
echo ""
echo -e "${BLUE}📍 Akses: Panel Admin → Sidebar → Protect Manager${NC}"
echo -e "${BLUE}🔒 Hanya Root Admin yang bisa akses${NC}"
echo ""
echo -e "${YELLOW}📁 Backup: $BACKUP_DIR${NC}"
echo -e "${YELLOW}↩️  Restore route  : cp $BACKUP_DIR/admin.php.bak $PANEL_PATH/routes/admin.php${NC}"
echo -e "${YELLOW}↩️  Restore sidebar: cp $BACKUP_DIR/admin.blade.php.bak $PANEL_PATH/resources/views/layouts/admin.blade.php${NC}"
