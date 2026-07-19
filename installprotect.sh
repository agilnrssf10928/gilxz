#!/bin/bash

# Variabel Warna
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PANEL_PATH="/var/www/pterodactyl"
cd "$PANEL_PATH"

echo -e "${CYAN}>>> MEMULAI INSTALL PROTECT MANAGER (VERSI AMAN)${NC}"

# 1. Backup ulang
TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/panel_backup_protect_$TS"
mkdir -p "$BACKUP_DIR/views"
cp -r resources/views/admin/* "$BACKUP_DIR/views/" 2>/dev/null || true
cp resources/views/layouts/admin.blade.php "$BACKUP_DIR/admin.blade.php.bak" 2>/dev/null || true

# 2. Buat Config JSON
mkdir -p storage/app
cat > storage/app/protect-config.json << 'CONFIGEOF'
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
chown www-data:www-data storage/app/protect-config.json

# 3. Buat file Blade View
mkdir -p resources/views/admin
cat > resources/views/admin/protect-manager.blade.php << 'BLADEEOF'
@extends('layouts.admin')
@section('title', 'Protect Manager')
@section('content-header')
    <h1>🛡️ Protect Manager <small>v3.1</small></h1>
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="{{ route('admin.index') }}"><i class="fas fa-tachometer-alt"></i> Admin</a></li>
        <li class="breadcrumb-item active">Protect Manager</li>
    </ol>
@endsection
@section('content')
@if(session('success')) <div class="alert alert-success alert-dismissible"><button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button> {{ session('success') }}</div> @endif
@if(session('error')) <div class="alert alert-danger alert-dismissible"><button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button> {{ session('error') }}</div> @endif
<div class="card card-primary card-outline">
    <div class="card-header p-0 border-bottom-0">
        <ul class="nav nav-tabs" id="protectTabs" role="tablist">
            <li class="nav-item"><a class="nav-link active" data-toggle="tab" href="#tab-servers" role="tab">🖥️ Server Protection</a></li>
            <li class="nav-item"><a class="nav-link" data-toggle="tab" href="#tab-settings" role="tab">⚙️ Brand Settings</a></li>
            <li class="nav-item"><a class="nav-link" data-toggle="tab" href="#tab-types" role="tab">📋 Tipe Proteksi</a></li>
        </ul>
    </div>
    <div class="card-body">
        <div class="tab-content" id="protectTabsContent">
            <div class="tab-pane fade show active" id="tab-servers" role="tabpanel">
                <div class="alert alert-info">Centang server yang mau diproteksi. Total: <strong>{{ $servers->count() }}</strong> | Terproteksi: <strong>{{ count($config['protected_servers'] ?? []) }}</strong></div>
                <form action="{{ route('admin.protect.toggle') }}" method="POST" id="serverForm"> @csrf
                    <div class="row mb-3">
                        <div class="col-md-3"><label>Tipe Proteksi:</label><select name="type_id" class="form-control form-control-sm">@foreach($config['protection_types'] ?? [] as $type)<option value="{{ $type['id'] }}">{{ $type['name'] }}</option>@endforeach</select></div>
                        <div class="col-md-9 d-flex align-items-end">
                            <button type="submit" name="action" value="install" class="btn btn-success btn-sm mr-2"><i class="fas fa-shield-alt"></i> Install</button>
                            <button type="submit" name="action" value="uninstall" class="btn btn-danger btn-sm mr-2"><i class="fas fa-times-circle"></i> Uninstall</button>
                            <span class="text-muted small ml-2" id="selectedCount">0 server dipilih</span>
                        </div>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-hover table-sm table-bordered">
                            <thead class="thead-dark"><tr><th width="40"><input type="checkbox" id="checkAll"></th><th>Nama Server</th><th>Owner</th><th>UUID</th><th>Status</th></tr></thead>
                            <tbody> @forelse($servers as $server) @php $protectedServers = $config['protected_servers'] ?? []; $isProtected = isset($protectedServers[$server->uuid]); $typeName = ''; foreach ($config['protection_types'] ?? [] as $t) { if ($t['id'] == ($isProtected ? $protectedServers[$server->uuid] : null)) { $typeName = $t['name']; break; } } @endphp
                            <tr class="{{ $isProtected ? 'table-success' : '' }}"><td class="text-center"><input type="checkbox" name="servers[]" value="{{ $server->uuid }}" class="server-checkbox"></td>
                            <td><strong>{{ $server->name }}</strong></td><td>{{ $server->user->username ?? '-' }}</td><td><code style="font-size:11px">{{ substr($server->uuid, 0, 8) }}...</code></td>
                            <td>@if($isProtected) <span class="badge badge-success"><i class="fas fa-lock"></i> {{ $typeName }}</span> @else <span class="badge badge-secondary"><i class="fas fa-unlock"></i> Terbuka</span> @endif</td></tr>
                            @empty <tr><td colspan="5" class="text-center text-muted py-4"><i class="fas fa-inbox fa-2x mb-2"></i><br>Tidak ada server</td></tr> @endforelse </tbody>
                        </table>
                    </div>
                </form>
            </div>
            <div class="tab-pane fade" id="tab-settings" role="tabpanel">
                <form action="{{ route('admin.protect.settings') }}" method="POST"> @csrf
                    <div class="form-group row"><label class="col-md-3">Nama Brand</label><div class="col-md-6"><input type="text" name="brand_name" class="form-control" value="{{ $config['brand_name'] ?? '' }}"></div></div>
                    <div class="form-group row"><label class="col-md-3">Kontak Admin</label><div class="col-md-6"><input type="text" name="contact" class="form-control" value="{{ $config['contact'] ?? '' }}"></div></div>
                    <div class="form-group row"><label class="col-md-3">Judul Panel</label><div class="col-md-6"><input type="text" name="panel_title" class="form-control" value="{{ $config['panel_title'] ?? '' }}"></div></div>
                    <div class="form-group row"><label class="col-md-3">Pesan Ditolak</label><div class="col-md-6"><textarea name="denied_message" class="form-control" rows="3">{{ $config['denied_message'] ?? '' }}</textarea></div></div>
                    <button type="submit" class="btn btn-primary"><i class="fas fa-save"></i> Simpan Settings</button>
                </form>
            </div>
            <div class="tab-pane fade" id="tab-types" role="tabpanel">
                <form action="{{ route('admin.protect.types') }}" method="POST"> @csrf
                    <table class="table table-bordered"><thead class="thead-dark"><tr><th>#</th><th>Nama</th><th>Deskripsi</th></tr></thead><tbody>
                        @foreach($config['protection_types'] ?? [] as $i => $type)
                        <tr><td class="text-center"><span class="badge badge-primary">{{ $type['id'] }}</span><input type="hidden" name="type_id[]" value="{{ $type['id'] }}"></td>
                        <td><input type="text" name="type_name[]" class="form-control" value="{{ $type['name'] }}"></td>
                        <td><input type="text" name="type_desc[]" class="form-control" value="{{ $type['description'] }}"></td></tr>
                        @endforeach
                    </tbody></table>
                    <button type="submit" class="btn btn-primary"><i class="fas fa-save"></i> Simpan Tipe</button>
                </form>
            </div>
        </div>
    </div>
</div>
@endsection
@section('footer-scripts') @parent <script>const checkAll=document.getElementById('checkAll');const checkboxes=document.querySelectorAll('.server-checkbox');const selectedCount=document.getElementById('selectedCount');function updateCount(){const checked=document.querySelectorAll('.server-checkbox:checked').length;selectedCount.textContent=checked+' server dipilih';}if(checkAll){checkAll.addEventListener('change',function(){checkboxes.forEach(cb=>cb.checked=this.checked);updateCount();});}checkboxes.forEach(cb=>cb.addEventListener('change',updateCount));document.getElementById('serverForm')?.addEventListener('submit',function(e){const action=document.activeElement?.value;const checked=document.querySelectorAll('.server-checkbox:checked').length;if(checked===0){e.preventDefault();alert('⚠️ Pilih minimal 1 server dulu!');return;}if(action==='uninstall'){if(!confirm('❗ Yakin mau uninstall proteksi dari '+checked+' server?')){e.preventDefault();}}});</script> @endsection
BLADEEOF

# 4. Tambah Route dengan metode Bypass (Membuat file baru langsung)
echo -e "${CYAN}>>> Menambahkan Route...${NC}"
cat > routes/temp_route.php << 'ROUTEEOF'
<?php

/*
|--------------------------------------------------------------------------
| Protect Manager Routes
|--------------------------------------------------------------------------
*/
Route::group(['prefix' => 'protect-manager', 'middleware' => ['web', 'auth', 'admin']], function () {
    Route::get('/', function () {
        if (!auth()->user()->root_admin) abort(403, 'Hanya Root Admin!');
        $configPath = storage_path('app/protect-config.json');
        $default = ['brand_name'=>'Protect Manager','contact'=>'@admin','panel_title'=>'Protected Panel','denied_message'=>'Server dilindungi!','protection_types'=>[['id'=>1,'name'=>'Basic Protect','description'=>'Proteksi dasar'],['id'=>2,'name'=>'Premium Protect','description'=>'Proteksi premium'],['id'=>3,'name'=>'VIP Protect','description'=>'Proteksi VIP']],'protected_servers'=>[]];
        $config = file_exists($configPath) ? array_merge($default, json_decode(file_get_contents($configPath), true) ?? []) : $default;
        $servers = \Pterodactyl\Models\Server::with(['user', 'node'])->orderBy('name')->get();
        return view('admin.protect-manager', compact('config', 'servers'));
    })->name('admin.protect.manager');

    Route::post('/toggle', function () {
        if (!auth()->user()->root_admin) abort(403);
        $configPath = storage_path('app/protect-config.json');
        $config = file_exists($configPath) ? json_decode(file_get_contents($configPath), true) ?? [] : [];
        if (!isset($config['protected_servers'])) $config['protected_servers'] = [];
        $action = request('action'); $serverIds = request('servers', []); $typeId = (int) request('type_id', 1);
        if (empty($serverIds)) return redirect()->route('admin.protect.manager')->with('error', 'Pilih minimal 1 server!');
        foreach ($serverIds as $uuid) { if ($action === 'install') $config['protected_servers'][$uuid] = $typeId; else unset($config['protected_servers'][$uuid]); }
        file_put_contents($configPath, json_encode($config, JSON_PRETTY_PRINT));
        return redirect()->route('admin.protect.manager')->with('success', ($action === 'install' ? '✅ Install' : '🗑️ Uninstall') . ' berhasil di ' . count($serverIds) . ' server!');
    })->name('admin.protect.toggle');

    Route::post('/settings', function () {
        if (!auth()->user()->root_admin) abort(403);
        $configPath = storage_path('app/protect-config.json');
        $config = file_exists($configPath) ? json_decode(file_get_contents($configPath), true) ?? [] : [];
        $config['brand_name'] = request('brand_name'); $config['contact'] = request('contact'); $config['panel_title'] = request('panel_title'); $config['denied_message'] = request('denied_message');
        file_put_contents($configPath, json_encode($config, JSON_PRETTY_PRINT));
        return redirect()->route('admin.protect.manager')->with('success', '✅ Settings disimpan!')->withFragment('tab-settings');
    })->name('admin.protect.settings');

    Route::post('/types', function () {
        if (!auth()->user()->root_admin) abort(403);
        $configPath = storage_path('app/protect-config.json');
        $config = file_exists($configPath) ? json_decode(file_get_contents($configPath), true) ?? [] : [];
        $names = request('type_name', []); $descs = request('type_desc', []); $ids = request('type_id', []); $types = [];
        foreach ($names as $i => $name) { if (!empty(trim($name))) $types[] = ['id'=>isset($ids[$i])?(int)$ids[$i]:($i+1),'name'=>trim($name),'description'=>trim($descs[$i]??'')]; }
        $config['protection_types'] = $types;
        file_put_contents($configPath, json_encode($config, JSON_PRETTY_PRINT));
        return redirect()->route('admin.protect.manager')->with('success', '✅ Tipe proteksi disimpan!')->withFragment('tab-types');
    })->name('admin.protect.types');
});
ROUTEEOF

# Masukkan isi temp_route.php ke admin.php
cat routes/temp_route.php >> routes/admin.php
rm routes/temp_route.php
echo -e "${GREEN}✅ Route berhasil ditambahkan dengan metode bypass error.${NC}"

# 5. Sidebar menu
LAYOUT_FILE="resources/views/layouts/admin.blade.php"
if grep -q "protect-manager" "$LAYOUT_FILE"; then
    echo -e "${YELLOW}Sidebar sudah ada, skip.${NC}"
else
    cp "$LAYOUT_FILE" "$BACKUP_DIR/admin.blade.php.bak"
    cp "$LAYOUT_FILE" "$LAYOUT_FILE.tmp"
    awk '/admin.settings/ || /Settings/ {
        print "                <li class=\"nav-item\">"
        print "                    <a href=\"{{ route('\''admin.protect.manager'\'') }}\" class=\"nav-link {{ Request::is('\''admin/protect-manager*'\'') ? '\''active'\'' : '\'''\'') }}\">"
        print "                        <i class=\"nav-icon fas fa-shield-alt\" style=\"color:#28a745\"></i>"
        print "                        <p>Protect Manager</p>"
        print "                    </a>"
        print "                </li>"
    } { print }' "$LAYOUT_FILE.tmp" > "$LAYOUT_FILE"
    rm -f "$LAYOUT_FILE.tmp"
    echo -e "${GREEN}✅ Sidebar berhasil ditambahkan.${NC}"
fi

# 6. Clear cache final (Hapus error route caching)
php artisan route:clear
php artisan view:clear
php artisan cache:clear
chown -R www-data:www-data storage/* bootstrap/cache
chmod -R 755 storage/* bootstrap/cache

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║ ✅ INSTALL BERHASIL! PANEL SUDAH NORMAL & SIAP PAKAI ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
