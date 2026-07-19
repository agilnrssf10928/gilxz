#!/bin/bash

BRAND_NAME="${BRAND_NAME:-My_GilXz Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Modifikasi Server..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Arr;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Auth;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Traits\Services\ReturnsUpdatedModels;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class DetailsModificationService
{
    use ReturnsUpdatedModels;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $serverRepository
    ) {}

    /**
     * Update the details for a single server instance.
     *
     * @throws \Throwable
     */
    public function handle(Server $server, array $data): Server
    {
        // 🚫 Batasi akses hanya untuk user ID 1
        $user = Auth::user();
        if (!$user || (int) $user->id !== 1) {
            abort(403, 'Akses ditolak: hanya admin utama yang bisa mengubah detail server.');
        }

        return $this->connection->transaction(function () use ($data, $server) {
            $owner = $server->owner_id;

            $server->forceFill([
                'external_id' => Arr::get($data, 'external_id'),
                'owner_id' => Arr::get($data, 'owner_id'),
                'name' => Arr::get($data, 'name'),
                'description' => Arr::get($data, 'description') ?? '',
            ])->saveOrFail();

            // Jika owner berubah, revoke token lama
            if ($server->owner_id !== $owner) {
                try {
                    $this->serverRepository->setServer($server)->revokeUserJTI($owner);
                } catch (DaemonConnectionException $exception) {
                    // Abaikan error dari Wings offline
                }
            }

            return $server;
        });
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|Akses ditolak: hanya admin utama yang bisa mengubah detail server.|${BRAND_TEXT} - Akses ditolak.|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi Anti Modifikasi Server berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin (ID 1) yang bisa Modifikasi Server."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_MODIFY" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_MODIFY" << 'PYABORT'
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
    print("✏️  Pesan modifikasi server dikustomisasi: " + msg)
PYABORT
fi
