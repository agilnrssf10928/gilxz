#!/bin/bash

BRAND_NAME="${BRAND_NAME:-My_GilXz Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"

PANEL_DIR="/var/www/pterodactyl"
REMOTE_PATH="$PANEL_DIR/app/Services/Servers/ServerDeletionService.php"
SERVER_MODEL="$PANEL_DIR/app/Models/Server.php"
APP_SERVER_CONTROLLER="$PANEL_DIR/app/Http/Controllers/Api/Application/Servers/ServerController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Delete Server..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    /**
     * ServerDeletionService constructor.
     */
    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {
    }

    /**
     * Set if the server should be forcibly deleted from the panel (ignoring daemon errors) or not.
     */
    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    /**
     * Delete a server from the panel and remove any associated databases from hosts.
     *
     * @throws \Throwable
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function handle(Server $server): void
    {
        $this->assertDeletionAllowed($server);

        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            // Abaikan error 404, tapi lempar error lain jika tidak mode force
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }

            Log::warning($exception);
        }

        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) {
                        throw $exception;
                    }

                    // Jika gagal delete database di host, tetap hapus dari panel
                    $database->delete();
                    Log::warning($exception);
                }
            }

            $server->delete();
        });
    }

    private function assertDeletionAllowed(Server $server): void
    {
        // PROTEKSI_My_GilXz_SERVER_DELETE_GUARD_V2
        // Mode ketat: delete server via panel/API/PLTA/PLTC hanya boleh oleh User ID 1.
        $actorId = $this->resolveActorId();

        if ($actorId === 1) {
            return;
        }

        // Request HTTP/API tanpa actor ID 1 tetap ditolak agar tidak bypass via token/bot.
        if ($this->isHttpRequest()) {
            throw new DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat menghapus server via panel/API/PLTA/PLTC @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.');
        }

        // CLI/background job bawaan panel tetap aman; bot/API tidak lewat CLI.
    }

    private function resolveActorId(): ?int
    {
        $request = null;
        try {
            $request = request();
        } catch (\Throwable $e) {}

        foreach ([null, 'web', 'api', 'application', 'client', 'sanctum'] as $guard) {
            try {
                $user = $guard === null ? Auth::user() : Auth::guard($guard)->user();
                $id = $this->extractUserId($user);
                if ($id !== null) {
                    return $id;
                }
            } catch (\Throwable $e) {}
        }

        try {
            $id = $this->extractUserId($request ? $request->user() : null);
            if ($id !== null) {
                return $id;
            }
        } catch (\Throwable $e) {}

        if ($request) {
            foreach (['api_key', 'apiKey', 'application_api_key', 'account_api_key', 'token', 'sanctum_token'] as $name) {
                try {
                    $id = $this->extractActorIdFromApiKey($request->attributes->get($name));
                    if ($id !== null) {
                        return $id;
                    }
                } catch (\Throwable $e) {}
            }
        }

        return null;
    }

    private function extractActorIdFromApiKey(mixed $apiKey): ?int
    {
        if (!$apiKey) {
            return null;
        }

        foreach (['user_id', 'owner_id', 'created_by'] as $field) {
            try {
                if (isset($apiKey->{$field}) && is_numeric($apiKey->{$field})) {
                    return (int) $apiKey->{$field};
                }
            } catch (\Throwable $e) {}
        }

        foreach (['user', 'tokenable', 'owner'] as $relation) {
            try {
                $related = $apiKey->{$relation} ?? null;
                if (!$related && method_exists($apiKey, $relation)) {
                    $related = $apiKey->{$relation}()->first();
                }
                $id = $this->extractUserId($related);
                if ($id !== null) {
                    return $id;
                }
            } catch (\Throwable $e) {}
        }

        return null;
    }

    private function extractUserId(mixed $user): ?int
    {
        try {
            if ($user && isset($user->id) && is_numeric($user->id)) {
                return (int) $user->id;
            }
        } catch (\Throwable $e) {}

        return null;
    }

    private function isHttpRequest(): bool
    {
        try {
            $request = request();
            return $request && app()->runningInConsole() === false;
        } catch (\Throwable $e) {
            return false;
        }
    }
}
EOF

chmod 644 "$REMOTE_PATH"

cleanup_marker_block() {
  local file="$1"
  local marker_regex="$2"
  [ -f "$file" ] || return 0
  if grep -Eq "$marker_regex" "$file"; then
    local tmp_file
    tmp_file=$(mktemp)
    awk -v marker="$marker_regex" '
      BEGIN { skip=0; skip_simple=0; depth=0 }
      skip_simple==1 {
        if ($0 ~ /throw new .*DisplayException/) { skip_simple=0; next }
        skip_simple=0
        print
        next
      }
      $0 ~ marker {
        if (marker ~ /BLOCK_APPLICATION_API_SERVER_DELETE/) {
          skip_simple=1
          next
        }
        skip=1
        depth=0
        open_count=gsub(/\{/, "{")
        close_count=gsub(/\}/, "}")
        depth += open_count - close_count
        next
      }
      skip==1 {
        open_count=gsub(/\{/, "{")
        close_count=gsub(/\}/, "}")
        depth += open_count - close_count
        if (depth <= 0 && $0 ~ /^[[:space:]]*}[);]?[[:space:]]*$/) {
          skip=0
        }
        next
      }
      { print }
    ' "$file" > "$tmp_file" && mv "$tmp_file" "$file"
  fi
}

# Bersihkan guard lama yang memblokir semua API/PLTA agar update tidak ke-skip.
for F in "$SERVER_MODEL" "$APP_SERVER_CONTROLLER"; do
  [ -f "$F" ] && cp "$F" "${F}.bak_${TIMESTAMP}_preclean" 2>/dev/null || true
done
cleanup_marker_block "$SERVER_MODEL" "PROTEKSI_My_GilXz_SERVER_MODEL_DELETE_GUARD"
cleanup_marker_block "$APP_SERVER_CONTROLLER" "PROTEKSI_My_GilXz_BLOCK_APPLICATION_API_SERVER_DELETE"

# Fallback tambahan: pasang guard di model Server agar jalur force/offline/API yang bypass ServerDeletionService tetap divalidasi.
if [ -f "$SERVER_MODEL" ]; then
  cp "$SERVER_MODEL" "${SERVER_MODEL}.bak_${TIMESTAMP}"
  if ! grep -q "PROTEKSI_My_GilXz_SERVER_MODEL_DELETE_GUARD_V2" "$SERVER_MODEL"; then
    TMP_FILE=$(mktemp)
    awk '
      BEGIN { inserted=0 }
      /^}[[:space:]]*$/ && inserted==0 {
        print ""
        print "    // PROTEKSI_My_GilXz_SERVER_MODEL_DELETE_GUARD_V2: fallback anti delete server, hanya actor User ID 1"
        print "    protected static function booted(): void"
        print "    {"
        print "        static::deleting(function ($server) {"
        print "            try {"
        print "                if (app()->runningInConsole()) { return; }"
        print "                $request = request();"
        print "                $actorId = null;"
        print "                foreach ([null, '\''web'\'', '\''api'\'', '\''application'\'', '\''client'\'', '\''sanctum'\''] as $guard) {"
        print "                    try {"
        print "                        $user = $guard === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($guard)->user();"
        print "                        if ($user && isset($user->id) && is_numeric($user->id)) { $actorId = (int) $user->id; break; }"
        print "                    } catch (\\Throwable $e) {}"
        print "                }"
        print "                if ($actorId === null && $request) {"
        print "                    try { $user = $request->user(); if ($user && isset($user->id) && is_numeric($user->id)) { $actorId = (int) $user->id; } } catch (\\Throwable $e) {}"
        print "                }"
        print "                if ($actorId === null && $request) {"
        print "                    foreach (['\''api_key'\'', '\''apiKey'\'', '\''application_api_key'\'', '\''account_api_key'\'', '\''token'\'', '\''sanctum_token'\''] as $name) {"
        print "                        try {"
        print "                            $apiKey = $request->attributes->get($name);"
        print "                            if (!$apiKey) { continue; }"
        print "                            foreach (['\''user_id'\'', '\''owner_id'\'', '\''created_by'\''] as $field) { if (isset($apiKey->{$field}) && is_numeric($apiKey->{$field})) { $actorId = (int) $apiKey->{$field}; break 2; } }"
        print "                            foreach (['\''user'\'', '\''tokenable'\'', '\''owner'\''] as $relation) {"
        print "                                $related = $apiKey->{$relation} ?? null;"
        print "                                if (!$related && method_exists($apiKey, $relation)) { $related = $apiKey->{$relation}()->first(); }"
        print "                                if ($related && isset($related->id) && is_numeric($related->id)) { $actorId = (int) $related->id; break 2; }"
        print "                            }"
        print "                        } catch (\\Throwable $e) {}"
        print "                    }"
        print "                }"
        print "                if ($actorId !== 1) {"
        print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException('\''Akses ditolak: hanya Admin ID 1 yang dapat menghapus server via panel/API/PLTA/PLTC @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.'\'');"
        print "                }"
        print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) {"
        print "                throw $e;"
        print "            } catch (\\Throwable $e) {"
        print "                throw new \\Pterodactyl\\Exceptions\\DisplayException('\''Akses ditolak: validasi hapus server gagal @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.'\'');"
        print "            }"
        print "        });"
        print "    }"
        inserted=1
      }
      { print }
    ' "$SERVER_MODEL" > "$TMP_FILE" && mv "$TMP_FILE" "$SERVER_MODEL"
    chmod 644 "$SERVER_MODEL"
    if php -l "$SERVER_MODEL" >/dev/null 2>&1; then
      echo "✅ Fallback guard Server model V2 terpasang."
    else
      echo "❌ Syntax error Server model setelah inject — rollback otomatis."
      cp "${SERVER_MODEL}.bak_${TIMESTAMP}" "$SERVER_MODEL"
    fi
  else
    echo "⚠️ Fallback guard Server model V2 sudah ada, skip."
  fi
else
  echo "⚠️ Server model tidak ditemukan, fallback guard dilewati: $SERVER_MODEL"
fi

# Fallback khusus PLTA/Application API: jangan blok total, validasi pemilik API key harus User ID 1.
if [ -f "$APP_SERVER_CONTROLLER" ]; then
  cp "$APP_SERVER_CONTROLLER" "${APP_SERVER_CONTROLLER}.bak_${TIMESTAMP}"
  if ! grep -q "PROTEKSI_My_GilXz_APPLICATION_API_SERVER_DELETE_V2" "$APP_SERVER_CONTROLLER"; then
    TMP_FILE=$(mktemp)
    awk '
      BEGIN { in_delete=0; inserted=0 }
      /function[[:space:]]+delete[[:space:]]*[(]/ { in_delete=1 }
      {
        print
        if (in_delete==1 && inserted==0 && $0 ~ /^[[:space:]]*\{[[:space:]]*$/) {
          print "        // PROTEKSI_My_GilXz_APPLICATION_API_SERVER_DELETE_V2: Application API delete hanya API key/Admin ID 1"
          print "        $__actorId = null;"
          print "        try {"
          print "            $__req = request();"
          print "            foreach ([null, '\''web'\'', '\''api'\'', '\''application'\'', '\''client'\'', '\''sanctum'\''] as $__guard) {"
          print "                try {"
          print "                    $__user = $__guard === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($__guard)->user();"
          print "                    if ($__user && isset($__user->id) && is_numeric($__user->id)) { $__actorId = (int) $__user->id; break; }"
          print "                } catch (\\Throwable $e) {}"
          print "            }"
          print "            if ($__actorId === null && $__req) { try { $__user = $__req->user(); if ($__user && isset($__user->id) && is_numeric($__user->id)) { $__actorId = (int) $__user->id; } } catch (\\Throwable $e) {} }"
          print "            if ($__actorId === null && $__req) {"
          print "                foreach (['\''api_key'\'', '\''apiKey'\'', '\''application_api_key'\'', '\''account_api_key'\'', '\''token'\'', '\''sanctum_token'\''] as $__name) {"
          print "                    try {"
          print "                        $__apiKey = $__req->attributes->get($__name);"
          print "                        if (!$__apiKey) { continue; }"
          print "                        foreach (['\''user_id'\'', '\''owner_id'\'', '\''created_by'\''] as $__field) { if (isset($__apiKey->{$__field}) && is_numeric($__apiKey->{$__field})) { $__actorId = (int) $__apiKey->{$__field}; break 2; } }"
          print "                        foreach (['\''user'\'', '\''tokenable'\'', '\''owner'\''] as $__rel) {"
          print "                            $__related = $__apiKey->{$__rel} ?? null;"
          print "                            if (!$__related && method_exists($__apiKey, $__rel)) { $__related = $__apiKey->{$__rel}()->first(); }"
          print "                            if ($__related && isset($__related->id) && is_numeric($__related->id)) { $__actorId = (int) $__related->id; break 2; }"
          print "                        }"
          print "                    } catch (\\Throwable $e) {}"
          print "                }"
          print "            }"
          print "        } catch (\\Throwable $e) {}"
          print "        if ($__actorId !== 1) {"
          print "            throw new \\Pterodactyl\\Exceptions\\DisplayException('\''Akses ditolak: hapus server via API/PLTA hanya boleh memakai API key/Admin ID 1 @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.'\'');"
          print "        }"
          inserted=1
          in_delete=0
        }
      }
    ' "$APP_SERVER_CONTROLLER" > "$TMP_FILE" && mv "$TMP_FILE" "$APP_SERVER_CONTROLLER"
    chmod 644 "$APP_SERVER_CONTROLLER"
    if php -l "$APP_SERVER_CONTROLLER" >/dev/null 2>&1; then
      echo "✅ Guard Application API delete server V2 terpasang."
    else
      echo "❌ Syntax error Application API server controller setelah inject — rollback otomatis."
      cp "${APP_SERVER_CONTROLLER}.bak_${TIMESTAMP}" "$APP_SERVER_CONTROLLER"
    fi
  else
    echo "⚠️ Guard Application API delete server V2 sudah ada, skip."
  fi
else
  echo "⚠️ Controller Application API server tidak ditemukan, guard PLTA dilewati: $APP_SERVER_CONTROLLER"
fi

# Apply brand customization
for F in "$REMOTE_PATH" "$SERVER_MODEL" "$APP_SERVER_CONTROLLER"; do
  if [ -f "$F" ]; then
    sed -i "s|Protect By My_GilXz|${BRAND_TEXT}|g" "$F" 2>/dev/null || true
    sed -i "s|My_GilXz Tech|${BRAND_NAME}|g" "$F" 2>/dev/null || true
    sed -i "s|𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz|${BRAND_TEXT}|g" "$F" 2>/dev/null || true
  fi
done

cd "$PANEL_DIR" 2>/dev/null && {
  php artisan config:clear >/dev/null 2>&1 || true
  php artisan cache:clear >/dev/null 2>&1 || true
  php artisan view:clear >/dev/null 2>&1 || true
  php artisan route:clear >/dev/null 2>&1 || true
}

echo "✅ Proteksi Anti Delete Server berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hapus server via panel/API/PLTA/PLTC hanya boleh actor/API key milik Admin ID 1."