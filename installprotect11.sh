#!/bin/bash

BRAND_NAME="${BRAND_NAME:-My_GilXz Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@My_GilXz}"
CONTACT_TELEGRAM_2="${CONTACT_TELEGRAM_2:-@My_GilXz}"
BRAND_LABEL="${BRAND_LABEL:-$BRAND_NAME}"

echo "🚀 Memasang proteksi Anti Tautan Server..."

INDEX_FILE="/var/www/pterodactyl/resources/views/admin/servers/index.blade.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

if [ -f "$INDEX_FILE" ]; then
  cp "$INDEX_FILE" "${INDEX_FILE}.bak_${TIMESTAMP}"
  echo "📦 Backup index file dibuat: ${INDEX_FILE}.bak_${TIMESTAMP}"
fi

cat > "$INDEX_FILE" << 'EOF'
@extends('layouts.admin')
@section('title')
    Servers
@endsection

@section('content-header')
    <h1>Servers<small>All servers available on the system.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Servers</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Server List</h3>
                <div class="box-tools search01">
                    <form action="{{ route('admin.servers') }}" method="GET">
                        <div class="input-group input-group-sm">
                            <input type="text" name="query" class="form-control pull-right" value="{{ request()->input('query') }}" placeholder="Search Servers">
                            <div class="input-group-btn">
                                <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                                <a href="{{ route('admin.servers.new') }}"><button type="button" class="btn btn-sm btn-primary" style="border-radius:0 3px 3px 0;margin-left:2px;">Create New</button></a>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
            <div class="box-body table-responsive no-padding">
                <table class="table table-hover">
                    <thead>
                        <tr>
                            <th>Server Name</th>
                            <th>UUID</th>
                            <th>Owner</th>
                            <th>Node</th>
                            <th>Connection</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($servers as $server)
                            <tr class="align-middle">
                                <td class="middle">
                                    <strong>{{ $server->name }}</strong>
                                    @if($server->id == 26)
                                    <br><small class="text-muted">Jhoanley Tech</small>
                                    @endif
                                </td>
                                <td class="middle"><code>{{ $server->uuidShort }}</code></td>
                                <td class="middle">
                                    <span class="label label-default">
                                        <i class="fa fa-user"></i> {{ $server->user->username }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <span class="label label-info">
                                        <i class="fa fa-server"></i> {{ $server->node->name }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <code>{{ $server->allocation->alias }}:{{ $server->allocation->port }}</code>
                                    @if($server->id == 26)
                                    <br><small><code>Jhoanley Tech:2007</code></small>
                                    @endif
                                </td>
                                <td class="text-center">
                                    @if((int) auth()->user()->id === 1)
                                        <a href="{{ route('admin.servers.view', $server->id) }}" class="btn btn-xs btn-primary">
                                            <i class="fa fa-wrench"></i> Manage
                                        </a>
                                    @else
                                        <span class="label label-warning" data-toggle="tooltip" title="Hanya Root Admin yang bisa mengakses">
                                            <i class="fa fa-shield"></i> Protected
                                        </span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if($servers->hasPages())
                <div class="box-footer with-border">
                    <div class="col-md-12 text-center">{!! $servers->appends(['query' => Request::input('query')])->render() !!}</div>
                </div>
            @endif
        </div>

        @if((int) auth()->user()->id !== 1)
        <div style="background:#0a0a0a;color:#fafafa;border:2px solid #dc2626;border-radius:0;padding:0;margin-top:20px;box-shadow:6px 6px 0 0 #dc2626;font-family:'JetBrains Mono','Courier New',monospace;overflow:hidden;">
            <div style="background:#dc2626;color:#0a0a0a;padding:6px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #0a0a0a;">
                <span style="font-size:11px;font-weight:900;letter-spacing:2px;text-transform:uppercase;">// ACCESS_CONTROL.SYS</span>
                <span style="font-size:10px;font-weight:900;letter-spacing:1.5px;background:#fbbf24;color:#0a0a0a;padding:2px 8px;border:1.5px solid #0a0a0a;">● RESTRICTED</span>
            </div>
            <div style="padding:18px 20px;display:flex;gap:16px;align-items:flex-start;">
                <div style="background:#dc2626;color:#fafafa;width:46px;height:46px;min-width:46px;display:flex;align-items:center;justify-content:center;border:2px solid #fbbf24;font-size:22px;">
                    <i class="fa fa-shield"></i>
                </div>
                <div style="flex:1;">
                    <h4 style="margin:0 0 8px 0;color:#fbbf24;font-size:18px;font-weight:900;text-transform:uppercase;letter-spacing:1.5px;font-family:'JetBrains Mono',monospace;">[ SERVER MANAGEMENT LOCKED ]</h4>
                    <p style="margin:0 0 6px 0;font-size:13px;color:#e5e5e5;line-height:1.6;font-family:'Segoe UI',sans-serif;">
                        Hanya <strong style="color:#dc2626;">ROOT ADMINISTRATOR (ID:1)</strong> yang dapat mengelola server existing.
                    </p>
                    <p style="margin:0 0 10px 0;font-size:12px;color:#a3a3a3;font-family:'JetBrains Mono',monospace;">
                        <span style="color:#10b981;">[+]</span> CREATE_NEW &rarr; <strong style="color:#fafafa;">ALL_ADMINS</strong> &nbsp;&nbsp;
                        <span style="color:#dc2626;">[-]</span> MANAGE_EXISTING &rarr; <strong style="color:#fafafa;">ROOT_ONLY</strong>
                    </p>
                    <div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;font-family:'JetBrains Mono',monospace;">
                        <span style="font-size:10px;color:#a3a3a3;text-transform:uppercase;letter-spacing:1px;font-weight:700;">&gt; PROTECTED_BY:</span>
                        <span style="background:#dc2626;color:#0a0a0a;border:1.5px solid #0a0a0a;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;">@My_GilXz</span>
                        <span style="background:#fafafa;color:#0a0a0a;border:1.5px solid #0a0a0a;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;">@My_GilXz</span>
                        <span style="background:#0a0a0a;color:#fbbf24;border:1.5px solid #fbbf24;padding:3px 9px;font-size:10px;font-weight:900;letter-spacing:1px;text-transform:uppercase;">__BRAND_LABEL__</span>
                    </div>
                </div>
            </div>
        </div>
        @else
        <div style="background:#0a0a0a;color:#fafafa;border:2px solid #fbbf24;border-radius:0;padding:0;margin-top:20px;box-shadow:6px 6px 0 0 #fbbf24;font-family:'JetBrains Mono','Courier New',monospace;overflow:hidden;">
            <div style="background:#fbbf24;color:#0a0a0a;padding:6px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #0a0a0a;">
                <span style="font-size:11px;font-weight:900;letter-spacing:2px;text-transform:uppercase;">// ROOT_ACCESS.SYS</span>
                <span style="font-size:10px;font-weight:900;letter-spacing:1.5px;background:#dc2626;color:#fafafa;padding:2px 8px;border:1.5px solid #0a0a0a;">● GRANTED</span>
            </div>
            <div style="padding:16px 20px;display:flex;gap:14px;align-items:center;">
                <div style="background:#fbbf24;color:#0a0a0a;width:42px;height:42px;min-width:42px;display:flex;align-items:center;justify-content:center;border:2px solid #dc2626;font-size:20px;">
                    <i class="fa fa-key"></i>
                </div>
                <div style="flex:1;">
                    <h4 style="margin:0 0 4px 0;color:#fbbf24;font-size:16px;font-weight:900;text-transform:uppercase;letter-spacing:1.5px;font-family:'JetBrains Mono',monospace;">[ ROOT ADMINISTRATOR ]</h4>
                    <p style="margin:0;font-size:13px;color:#e5e5e5;font-family:'Segoe UI',sans-serif;">
                        Full system access granted. Semua server dapat dikelola secara normal.
                    </p>
                </div>
            </div>
        </div>
        @endif
    </div>
</div>
@endsection

@section('footer-scripts')
    @parent
    <script>
        $(document).ready(function() {
            $('[data-toggle="tooltip"]').tooltip();

            @if((int) auth()->user()->id !== 1)
            $('a[href*="/admin/servers/view/"]').on('click', function(e) {
                e.preventDefault();
                alert('🚫 Access Denied: Hanya Root Administrator (ID: 1) yang dapat mengelola server existing.\n\n✅ Anda masih bisa membuat server baru dengan tombol "Create New"\n\nProtected by: @My_GilXzl');
            });
            @endif
        });
    </script>
@endsection
EOF

sed -i "s|__BRAND_LABEL__|${BRAND_LABEL}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@My_GilXz|${CONTACT_TELEGRAM_2}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|My_GilXz Tech|${BRAND_NAME}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@My_GilXz|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@My_GilXzl|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true

chmod 644 "$INDEX_FILE"

echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "🎉 PROTEKSI BERHASIL DIPASANG!"
echo "✅ Admin ID 1: Bisa akses semua (server list, view, dan management)"
echo "✅ Admin lain: Bisa Create New server, tapi tidak bisa manage existing"
echo "✅ View server asli tidak diubah agar tab tetap normal"
echo "🛡️ Security by: @My_GilXz"
