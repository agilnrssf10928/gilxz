#!/bin/bash

BRAND_NAME="${BRAND_NAME:-My_GilXz Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "ðŸš€ Memasang proteksi Anti Akses Server Controller..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "ðŸ“¦ Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Server;
use Pterodactyl\Transformers\Api\Client\ServerTransformer;
use Pterodactyl\Services\Servers\GetUserPermissionsService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\GetServerRequest;

class ServerController extends ClientApiController
{
    /**
     * ServerController constructor.
     */
    public function __construct(private GetUserPermissionsService $permissionsService)
    {
        parent::__construct();
    }

    /**
     * Transform an individual server into a response that can be consumed by a
     * client using the API.
     */
    public function index(GetServerRequest $request, Server $server): array
    {
        // 🔒 Anti intip server orang lain (kecuali admin ID 1, owner, atau subuser)
        $authUser = Auth::user();

        $allowed = false;
        if ($authUser) {
            if ((int) $authUser->id === 1) {
                $allowed = true;
            } elseif ((int) $server->owner_id === (int) $authUser->id) {
                $allowed = true;
            } else {
                try {
                    if ($server->subusers()->where('user_id', $authUser->id)->exists()) {
                        $allowed = true;
                    }
                } catch (\Throwable $e) {
                    // fallback diam
                }
            }
        }

        if (!$allowed) {
            abort(403, '@𝙅𝙃𝙊𝙉𝘼𝙇𝙀𝙔 𝙏𝙀𝘾𝙃 • 𝗔𝗸𝘀𝗲𝘀 𝗗𝗶 𝗧𝗼𝗹𝗮𝗸❌. 𝗛𝗮𝗻𝘆𝗮 𝗕𝗶𝘀𝗮 𝗠𝗲𝗹𝗶𝗵𝗮𝘁 𝗦𝗲𝗿𝘃𝗲𝗿 𝗠𝗶𝗹𝗶𝗸 𝗦𝗲𝗻𝗱𝗶𝗿𝗶.');
        }

        return $this->fractal->item($server)
            ->transformWith($this->getTransformer(ServerTransformer::class))
            ->addMeta([
                'is_server_owner' => $request->user()->id === $server->owner_id,
                'user_permissions' => $this->permissionsService->handle($server, $request->user()),
            ])
            ->toArray();
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization - replace the unicode abort message
ABORT_LINE=$(grep -n "abort(403" "$REMOTE_PATH" | head -1 | cut -d: -f1)
if [ -n "$ABORT_LINE" ]; then
  sed -i "${ABORT_LINE}s|abort(403,.*|abort(403, '${BRAND_TEXT} - Akses Ditolak. Hanya Bisa Melihat Server Milik Sendiri.');|" "$REMOTE_PATH" 2>/dev/null || true
fi

echo "✅ Proteksi Anti Akses Server Controller berhasil dipasang!"
echo "ðŸ“‚ Lokasi file: $REMOTE_PATH"
echo "ðŸ—‚ï¸ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "ðŸ”’ Hanya Admin (ID 1) yang bisa Akses Server Controller."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_SERVER" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_SERVER" << 'PYABORT'
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
    print("✏️  Pesan akses server dikustomisasi: " + msg)
PYABORT
fi
