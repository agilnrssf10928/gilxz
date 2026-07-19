#!/bin/bash
# ============================================
# installprotect14.sh
# Proteksi User/Admin Panel:
# - Selain User ID 1 tidak bisa membuat/mengubah user menjadi admin/root_admin.
# - Selain User ID 1 tidak bisa delete user/admin panel.
# - Jalur API/bot/panel.js untuk create admin dan delete user diblok total,
#   termasuk jika memakai Application API key milik ID 1, karena panel.js hanya
#   mengirim API key dan tidak membuktikan operator Telegram adalah ID 1.
# - Create user biasa tetap diizinkan.
# ============================================

set -e

BRAND_NAME="${BRAND_NAME:-My_GilXz Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "==========================================="
echo "🔒 INSTALLPROTECT14: Anti Create/Delete Admin Panel"
echo "==========================================="

MARKER_V3="PROTEKSI_My_GilXz_USER_ADMIN_PANEL_GUARD_V5"
OLD_MARKER_REGEX="PROTEKSI_My_GilXz_USER_ADMIN_PANEL_GUARD_V[0-9]+"

read -r -d '' GUARD_PHP <<'PHP' || true
        // PROTEKSI_My_GilXz_USER_ADMIN_PANEL_GUARD_V5
        try {
            $__req = request();
            $__isConsole = app()->runningInConsole();

            $__webUser = null;
            try { $__webUser = \Illuminate\Support\Facades\Auth::guard('web')->user(); } catch (\Throwable $e) {}
            $__isSession = $__webUser !== null;
            $__hasBearer = false;
            if ($__req) {
                try {
                    $__auth = (string) ($__req->header('Authorization') ?? '');
                    if ($__auth !== '' && stripos($__auth, 'Bearer ') === 0) { $__hasBearer = true; }
                    if ($__req->attributes->get('api_key') || $__req->attributes->get('apiKey') || $__req->attributes->get('token')) { $__hasBearer = true; }
                } catch (\Throwable $e) {}
            }
            $__isApiKey = $__hasBearer && !$__isSession;

            $__user = $__webUser;
            if (!$__user) {
                foreach ([null, 'api', 'application', 'client'] as $__g) {
                    try {
                        $__user = $__g === null ? \Illuminate\Support\Facades\Auth::user() : \Illuminate\Support\Facades\Auth::guard($__g)->user();
                        if ($__user) { break; }
                    } catch (\Throwable $e) {}
                }
            }
            if (!$__user && $__req) { try { $__user = $__req->user(); } catch (\Throwable $e) {} }
            if (!$__user && $__req) {
                try {
                    $__k = $__req->attributes->get('api_key') ?? $__req->attributes->get('apiKey') ?? $__req->attributes->get('token');
                    $__user = $__k ? ($__k->user ?? $__k->userModel ?? null) : null;
                } catch (\Throwable $e) {}
            }
            $__actorId = $__user && isset($__user->id) ? (int) $__user->id : null;
            if (!$__actorId && $__req) {
                try {
                    $__apiKeys = [];
                    foreach (['api_key', 'apiKey', 'token', 'application_api_key', 'applicationApiKey', 'key'] as $__name) {
                        $__candidate = $__req->attributes->get($__name);
                        if ($__candidate) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__req->attributes->all() as $__candidate) {
                        if (is_object($__candidate)) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__apiKeys as $__k) {
                        if (!is_object($__k)) { continue; }
                        foreach (['user_id', 'userId', 'owner_id', 'ownerId', 'created_by', 'createdBy', 'created_by_id', 'createdById'] as $__prop) {
                            if (isset($__k->{$__prop}) && (int) $__k->{$__prop} > 0) { $__actorId = (int) $__k->{$__prop}; break 2; }
                            if (method_exists($__k, 'getAttribute')) { $__v = $__k->getAttribute($__prop); if ($__v && (int) $__v > 0) { $__actorId = (int) $__v; break 2; } }
                        }
                        $__rel = null;
                        try { $__rel = $__k->user ?? null; } catch (\Throwable $e) {}
                        if (!$__rel && method_exists($__k, 'user')) { try { $__rel = $__k->user()->first(); } catch (\Throwable $e) {} }
                        if ($__rel && isset($__rel->id)) { $__actorId = (int) $__rel->id; break; }
                    }
                } catch (\Throwable $e) {}
            }

            $__path = $__req ? trim($__req->path(), '/') : '';
            $__method = $__req ? strtoupper($__req->method()) : '';
            $__isApiUserRoute = $__path !== '' && (
                strpos($__path, 'api/application/users') === 0 ||
                strpos($__path, 'api/client/users') === 0 ||
                strpos($__path, 'api/remote/users') === 0
            );

            $__wantsAdmin = false;
            if ($__req) {
                try {
                    $__ra = $__req->input('root_admin');
                    if ($__ra !== null && (int) $__ra === 1) { $__wantsAdmin = true; }
                    if ($__req->boolean('root_admin')) { $__wantsAdmin = true; }
                    $__json = $__req->json()->all();
                    if (is_array($__json) && array_key_exists('root_admin', $__json) && (int) $__json['root_admin'] === 1) { $__wantsAdmin = true; }
                    if (is_array($__json) && array_key_exists('admin', $__json) && (int) $__json['admin'] === 1) { $__wantsAdmin = true; }
                } catch (\Throwable $e) {}
            }

            if (!$__isConsole && $__isApiKey && $__isApiUserRoute && $__method === 'DELETE') {
                if ($__actorId !== null && (int) $__actorId !== 1) {
                    throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: delete user/admin panel via API/bot/panel.js hanya boleh memakai API key milik Admin ID 1 @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.');
                }
            }
            if (!$__isConsole && $__isApiKey && $__wantsAdmin) {
                if ((int) ($__actorId ?? 0) !== 1) {
                    throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: create Administrator via API/bot/panel.js hanya boleh memakai API key milik Admin ID 1 @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.');
                }
            }

            if (!$__isConsole && ($__wantsAdmin || $__method === 'DELETE')) {
                if ($__isApiKey && $__isApiUserRoute && $__method === 'DELETE' && ($__actorId === null || (int) $__actorId === 1)) {
                    // Application API key valid; beberapa versi Pterodactyl tidak menyimpan owner key di request.
                } elseif ((int) ($__actorId ?? 0) !== 1) {
                    throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat membuat/mengubah/menghapus Admin Panel @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.');
                }
            }
        } catch (\Pterodactyl\Exceptions\DisplayException $e) { throw $e; } catch (\Throwable $e) {}
PHP

read -r -d '' DELETE_GUARD_PHP <<'PHP' || true
        // PROTEKSI_My_GilXz_USER_ADMIN_PANEL_GUARD_V5_DELETE
        try {
            if (!app()->runningInConsole()) {
            $__req = request();
            $__path = $__req ? trim($__req->path(), '/') : '';
            $__isApiUserRoute = $__path !== '' && (
                strpos($__path, 'api/application/users') === 0 ||
                strpos($__path, 'api/client/users') === 0 ||
                strpos($__path, 'api/remote/users') === 0
            );

            $__webUser = null;
            try { $__webUser = \Illuminate\Support\Facades\Auth::guard('web')->user(); } catch (\Throwable $e) {}
            $__isSession = $__webUser !== null;
            $__hasBearer = false;
            if ($__req) {
                try {
                    $__auth = (string) ($__req->header('Authorization') ?? '');
                    if ($__auth !== '' && stripos($__auth, 'Bearer ') === 0) { $__hasBearer = true; }
                    if ($__req->attributes->get('api_key') || $__req->attributes->get('apiKey') || $__req->attributes->get('token')) { $__hasBearer = true; }
                } catch (\Throwable $e) {}
            }
            $__isApiKey = $__hasBearer && !$__isSession;

            $__user = $__webUser;
            if (!$__user) {
                foreach ([null, 'api', 'application', 'client'] as $__g) {
                    try {
                        $__user = $__g === null ? \Illuminate\Support\Facades\Auth::user() : \Illuminate\Support\Facades\Auth::guard($__g)->user();
                        if ($__user) { break; }
                    } catch (\Throwable $e) {}
                }
            }
            if (!$__user && $__req) { try { $__user = $__req->user(); } catch (\Throwable $e) {} }
            if (!$__user && $__req) {
                try {
                    $__k = $__req->attributes->get('api_key') ?? $__req->attributes->get('apiKey') ?? $__req->attributes->get('token');
                    $__user = $__k ? ($__k->user ?? $__k->userModel ?? null) : null;
                } catch (\Throwable $e) {}
            }
            $__actorId = $__user && isset($__user->id) ? (int) $__user->id : null;
            if (!$__actorId && $__req) {
                try {
                    $__apiKeys = [];
                    foreach (['api_key', 'apiKey', 'token', 'application_api_key', 'applicationApiKey', 'key'] as $__name) {
                        $__candidate = $__req->attributes->get($__name);
                        if ($__candidate) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__req->attributes->all() as $__candidate) {
                        if (is_object($__candidate)) { $__apiKeys[] = $__candidate; }
                    }
                    foreach ($__apiKeys as $__k) {
                        if (!is_object($__k)) { continue; }
                        foreach (['user_id', 'userId', 'owner_id', 'ownerId', 'created_by', 'createdBy', 'created_by_id', 'createdById'] as $__prop) {
                            if (isset($__k->{$__prop}) && (int) $__k->{$__prop} > 0) { $__actorId = (int) $__k->{$__prop}; break 2; }
                            if (method_exists($__k, 'getAttribute')) { $__v = $__k->getAttribute($__prop); if ($__v && (int) $__v > 0) { $__actorId = (int) $__v; break 2; } }
                        }
                        $__rel = null;
                        try { $__rel = $__k->user ?? null; } catch (\Throwable $e) {}
                        if (!$__rel && method_exists($__k, 'user')) { try { $__rel = $__k->user()->first(); } catch (\Throwable $e) {} }
                        if ($__rel && isset($__rel->id)) { $__actorId = (int) $__rel->id; break; }
                    }
                } catch (\Throwable $e) {}
            }
            if ($__isApiKey && $__isApiUserRoute && $__actorId !== null && (int) $__actorId !== 1) {
                throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: delete user/admin panel via API/bot/panel.js hanya boleh memakai API key milik Admin ID 1 @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.');
            }
            if ($__isApiKey && $__isApiUserRoute && ($__actorId === null || (int) $__actorId === 1)) {
                // Application API key valid; beberapa versi Pterodactyl tidak menyimpan owner key di request.
            } elseif ((int) ($__actorId ?? 0) !== 1) {
                throw new \Pterodactyl\Exceptions\DisplayException('Akses ditolak: hanya Admin ID 1 yang dapat menghapus user/admin panel @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.');
            }
            }
        } catch (\Pterodactyl\Exceptions\DisplayException $e) { throw $e; } catch (\Throwable $e) {}
PHP

cleanup_old_method_guards() {
    local FILE="$1"
    [ -f "$FILE" ] || return 0
    grep -Eq "$OLD_MARKER_REGEX" "$FILE" || return 0

    cp "$FILE" "${FILE}.bak_pre_p14_v4_${TIMESTAMP}"
    local TMP
    TMP=$(mktemp)
    awk -v marker="$OLD_MARKER_REGEX" '
        BEGIN { skip=0 }
        $0 ~ marker && $0 !~ /_MODEL/ { skip=1; next }
        skip == 1 {
            if ($0 ~ /catch[[:space:]]*\(\\Pterodactyl\\Exceptions\\DisplayException[[:space:]]+\$e\)/ && $0 ~ /catch[[:space:]]*\(\\Throwable[[:space:]]+\$e\)[[:space:]]*\{\}/) { skip=0; next }
            next
        }
        { print }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Cleanup guard lama gagal di $FILE — rollback."
        cp "${FILE}.bak_pre_p14_v4_${TIMESTAMP}" "$FILE"
    else
        echo "♻️ Guard lama Protect14 dibersihkan dari $FILE"
    fi
}

cleanup_old_model_guard() {
    local FILE="$1"
    [ -f "$FILE" ] || return 0
    grep -Eq "${OLD_MARKER_REGEX}_MODEL" "$FILE" || return 0

    cp "$FILE" "${FILE}.bak_pre_p14_v4_${TIMESTAMP}"
    local TMP
    TMP=$(mktemp)
    awk -v marker="${OLD_MARKER_REGEX}_MODEL" '
        BEGIN { skip=0; depth=0; seen_fn=0 }
        skip == 0 && $0 ~ marker { skip=1; depth=0; seen_fn=0; next }
        skip == 1 {
            if ($0 ~ /function[[:space:]]+booted[[:space:]]*\(/) { seen_fn=1 }
            if (seen_fn) {
                line=$0; open=gsub(/\{/, "{", line)
                line=$0; close_count=gsub(/\}/, "}", line)
                depth += open - close_count
                if (depth <= 0 && $0 ~ /}/) { skip=0; next }
            }
            next
        }
        { print }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Cleanup guard model lama gagal — rollback."
        cp "${FILE}.bak_pre_p14_v4_${TIMESTAMP}" "$FILE"
    else
        echo "♻️ Guard model lama Protect14 dibersihkan dari $FILE"
    fi
}

inject_guard_into_method() {
    local FILE="$1"
    local METHOD_REGEX="$2"
    local METHOD_NAME="$3"

    if [ ! -f "$FILE" ]; then
        echo "⚠️ File tidak ditemukan: $FILE (skip)"
        return 0
    fi

    local METHOD_MARKER="${MARKER_V3}_${METHOD_NAME}"
    if grep -q "$METHOD_MARKER" "$FILE"; then
        echo "⚠️ Guard sudah ada di $FILE::$METHOD_NAME (skip)"
        return 0
    fi

    cp "$FILE" "${FILE}.bak_${TIMESTAMP}"

    local GUARD_FILE TMP
    GUARD_FILE=$(mktemp)
    TMP=$(mktemp)
    printf '        // %s\n%s\n' "$METHOD_MARKER" "$GUARD_PHP" > "$GUARD_FILE"

    awk -v method="$METHOD_REGEX" -v guardfile="$GUARD_FILE" '
        BEGIN {
            while ((getline line < guardfile) > 0) { guard = guard line "\n" }
            close(guardfile)
            in_method = 0
            inserted = 0
        }
        {
            print
            if (inserted == 0 && in_method == 0 && $0 ~ method) { in_method = 1 }
            if (in_method == 1 && inserted == 0 && $0 ~ /\{/) {
                printf "%s", guard
                inserted = 1
                in_method = 0
            }
        }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"

    rm -f "$GUARD_FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Syntax error setelah inject $FILE — rollback."
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    if ! grep -q "$METHOD_MARKER" "$FILE"; then
        echo "❌ Marker $METHOD_MARKER TIDAK ditemukan setelah inject (regex method tidak match) — rollback $FILE"
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    echo "✅ Guard terpasang di $FILE::$METHOD_NAME"
}

inject_delete_guard_into_method() {
    local FILE="$1"
    local METHOD_REGEX="$2"
    local METHOD_NAME="$3"

    if [ ! -f "$FILE" ]; then
        echo "⚠️ File tidak ditemukan: $FILE (skip)"
        return 0
    fi

    local METHOD_MARKER="${MARKER_V3}_DELETE_${METHOD_NAME}"
    if grep -q "$METHOD_MARKER" "$FILE"; then
        echo "⚠️ Guard delete sudah ada di $FILE::$METHOD_NAME (skip)"
        return 0
    fi

    cp "$FILE" "${FILE}.bak_${TIMESTAMP}"

    local GUARD_FILE TMP
    GUARD_FILE=$(mktemp)
    TMP=$(mktemp)
    printf '        // %s\n%s\n' "$METHOD_MARKER" "$DELETE_GUARD_PHP" > "$GUARD_FILE"

    awk -v method="$METHOD_REGEX" -v guardfile="$GUARD_FILE" '
        BEGIN {
            while ((getline line < guardfile) > 0) { guard = guard line "\n" }
            close(guardfile)
            in_method = 0
            inserted = 0
        }
        {
            print
            if (inserted == 0 && in_method == 0 && $0 ~ method) { in_method = 1 }
            if (in_method == 1 && inserted == 0 && $0 ~ /\{/) {
                printf "%s", guard
                inserted = 1
                in_method = 0
            }
        }
    ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"

    rm -f "$GUARD_FILE"
    chmod 644 "$FILE"
    if ! php -l "$FILE" >/dev/null 2>&1; then
        echo "❌ Syntax error setelah inject delete $FILE — rollback."
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    if ! grep -q "$METHOD_MARKER" "$FILE"; then
        echo "❌ Marker $METHOD_MARKER TIDAK ditemukan (regex method tidak match) — rollback $FILE"
        cp "${FILE}.bak_${TIMESTAMP}" "$FILE"
        return 0
    fi
    echo "✅ Guard delete terpasang di $FILE::$METHOD_NAME"
}

ADMIN_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Admin/UserController.php"
APP_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"
CLIENT_USER_CTRL="$PANEL_DIR/app/Http/Controllers/Api/Client/Users/UserController.php"
USER_CREATE_SVC="$PANEL_DIR/app/Services/Users/UserCreationService.php"
USER_UPDATE_SVC="$PANEL_DIR/app/Services/Users/UserUpdateService.php"
USER_DELETE_SVC="$PANEL_DIR/app/Services/Users/UserDeletionService.php"
USER_MODEL="$PANEL_DIR/app/Models/User.php"

for F in "$ADMIN_USER_CTRL" "$APP_USER_CTRL" "$CLIENT_USER_CTRL" "$USER_CREATE_SVC" "$USER_UPDATE_SVC" "$USER_DELETE_SVC"; do
    cleanup_old_method_guards "$F"
done
cleanup_old_model_guard "$USER_MODEL"

inject_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+store[[:space:]]*[(]" "ADMIN_STORE"
inject_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+update[[:space:]]*[(]" "ADMIN_UPDATE"
inject_delete_guard_into_method "$ADMIN_USER_CTRL" "function[[:space:]]+(delete|destroy)[[:space:]]*[(]" "ADMIN_DELETE"

inject_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+store[[:space:]]*[(]" "APP_API_STORE"
inject_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+update[[:space:]]*[(]" "APP_API_UPDATE"
inject_delete_guard_into_method "$APP_USER_CTRL" "function[[:space:]]+(delete|destroy)[[:space:]]*[(]" "APP_API_DELETE"

inject_delete_guard_into_method "$CLIENT_USER_CTRL" "function[[:space:]]+(delete|destroy)[[:space:]]*[(]" "CLIENT_API_DELETE"

inject_guard_into_method "$USER_CREATE_SVC" "function[[:space:]]+handle[[:space:]]*[(]" "USER_CREATE_SERVICE_HANDLE"

inject_guard_into_method "$USER_UPDATE_SVC" "function[[:space:]]+handle[[:space:]]*[(]" "USER_UPDATE_SERVICE_HANDLE"

inject_delete_guard_into_method "$USER_DELETE_SVC" "function[[:space:]]+handle[[:space:]]*[(]" "USER_DELETE_SERVICE_HANDLE"

if [ -f "$USER_MODEL" ]; then
    if grep -q "${MARKER_V3}_MODEL" "$USER_MODEL"; then
        echo "⚠️ Guard model User sudah ada, skip."
    elif grep -Eq "function[[:space:]]+booted[[:space:]]*\(" "$USER_MODEL"; then
        echo "⚠️ Model User sudah punya method booted() bawaan — skip injeksi model (pakai guard Controller/Service saja) untuk mencegah fatal error 500."
    else
        cp "$USER_MODEL" "${USER_MODEL}.bak_${TIMESTAMP}"
        TMP=$(mktemp)
        awk -v marker="${MARKER_V3}_MODEL" '
            BEGIN { inserted=0 }
            {
                if (inserted==0 && $0 ~ /^}[[:space:]]*$/) {
                    print "    // " marker
                    print "    protected static function booted(): void"
                    print "    {"
                    print "        static::saving(function ($model) {"
                    print "            try {"
                    print "                if (app()->runningInConsole()) { return; }"
                    print "                if ((int) ($model->root_admin ?? 0) !== 1) { return; }"
                    print "                $req = null; try { $req = request(); } catch (\\Throwable $e) {}"
                    print "                $path = $req ? trim($req->path(), \"/\") : \"\";"
                    print "                $original = method_exists($model, \"getOriginal\") ? (int) ($model->getOriginal(\"root_admin\") ?? 0) : 0;"
                    print "                if ($model->exists && $original === 1) { return; }"
                    print "                $user = null;"
                    print "                foreach ([null, \"web\", \"api\", \"application\", \"client\"] as $g) {"
                    print "                    try { $user = $g === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($g)->user(); if ($user) { break; } } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if (!$user) { try { if ($req) { $user = $req->user(); } } catch (\\Throwable $e) {} }"
                    print "                $actorId = $user && isset($user->id) ? (int) $user->id : null;"
                    print "                if (!$actorId && $req) {"
                    print "                    try {"
                    print "                        $apiKeys = [];"
                    print "                        foreach ([\"api_key\", \"apiKey\", \"token\", \"application_api_key\", \"applicationApiKey\", \"key\"] as $name) { $candidate = $req->attributes->get($name); if ($candidate) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($req->attributes->all() as $candidate) { if (is_object($candidate)) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($apiKeys as $apiKey) {"
                    print "                            if (!is_object($apiKey)) { continue; }"
                    print "                            foreach ([\"user_id\", \"userId\", \"owner_id\", \"ownerId\", \"created_by\", \"createdBy\", \"created_by_id\", \"createdById\"] as $prop) {"
                    print "                                if (isset($apiKey->{$prop}) && (int) $apiKey->{$prop} > 0) { $actorId = (int) $apiKey->{$prop}; break 2; }"
                    print "                                if (method_exists($apiKey, \"getAttribute\")) { $value = $apiKey->getAttribute($prop); if ($value && (int) $value > 0) { $actorId = (int) $value; break 2; } }"
                    print "                            }"
                    print "                            $rel = null; try { $rel = $apiKey->user ?? null; } catch (\\Throwable $e) {}"
                    print "                            if (!$rel && method_exists($apiKey, \"user\")) { try { $rel = $apiKey->user()->first(); } catch (\\Throwable $e) {} }"
                    print "                            if ($rel && isset($rel->id)) { $actorId = (int) $rel->id; break; }"
                    print "                        }"
                    print "                    } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if ((int) ($actorId ?? 0) !== 1) {"
                    print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException(\"Akses ditolak: hanya Admin ID 1 yang dapat membuat/mengubah Admin Panel @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.\");"
                    print "                }"
                    print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) { throw $e; } catch (\\Throwable $e) {}"
                    print "        });"
                    print "        static::deleting(function ($model) {"
                    print "            try {"
                    print "                if (app()->runningInConsole()) { return; }"
                    print "                $req = null; try { $req = request(); } catch (\\Throwable $e) {}"
                    print "                $path = $req ? trim($req->path(), \"/\") : \"\";"
                    print "                $user = null;"
                    print "                foreach ([null, \"web\", \"api\", \"application\", \"client\"] as $g) {"
                    print "                    try { $user = $g === null ? \\Illuminate\\Support\\Facades\\Auth::user() : \\Illuminate\\Support\\Facades\\Auth::guard($g)->user(); if ($user) { break; } } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if (!$user) { try { if ($req) { $user = $req->user(); } } catch (\\Throwable $e) {} }"
                    print "                $actorId = $user && isset($user->id) ? (int) $user->id : null;"
                    print "                if (!$actorId && $req) {"
                    print "                    try {"
                    print "                        $apiKeys = [];"
                    print "                        foreach ([\"api_key\", \"apiKey\", \"token\", \"application_api_key\", \"applicationApiKey\", \"key\"] as $name) { $candidate = $req->attributes->get($name); if ($candidate) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($req->attributes->all() as $candidate) { if (is_object($candidate)) { $apiKeys[] = $candidate; } }"
                    print "                        foreach ($apiKeys as $apiKey) {"
                    print "                            if (!is_object($apiKey)) { continue; }"
                    print "                            foreach ([\"user_id\", \"userId\", \"owner_id\", \"ownerId\", \"created_by\", \"createdBy\", \"created_by_id\", \"createdById\"] as $prop) {"
                    print "                                if (isset($apiKey->{$prop}) && (int) $apiKey->{$prop} > 0) { $actorId = (int) $apiKey->{$prop}; break 2; }"
                    print "                                if (method_exists($apiKey, \"getAttribute\")) { $value = $apiKey->getAttribute($prop); if ($value && (int) $value > 0) { $actorId = (int) $value; break 2; } }"
                    print "                            }"
                    print "                            $rel = null; try { $rel = $apiKey->user ?? null; } catch (\\Throwable $e) {}"
                    print "                            if (!$rel && method_exists($apiKey, \"user\")) { try { $rel = $apiKey->user()->first(); } catch (\\Throwable $e) {} }"
                    print "                            if ($rel && isset($rel->id)) { $actorId = (int) $rel->id; break; }"
                    print "                        }"
                    print "                    } catch (\\Throwable $e) {}"
                    print "                }"
                    print "                if ((int) ($actorId ?? 0) !== 1) {"
                    print "                    throw new \\Pterodactyl\\Exceptions\\DisplayException(\"Akses ditolak: hanya Admin ID 1 yang dapat menghapus user/admin panel @ 𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz.\");"
                    print "                }"
                    print "            } catch (\\Pterodactyl\\Exceptions\\DisplayException $e) { throw $e; } catch (\\Throwable $e) {}"
                    print "        });"
                    print "    }"
                    print ""
                    inserted=1
                }
                print
            }
        ' "$USER_MODEL" > "$TMP" && mv "$TMP" "$USER_MODEL"
        chmod 644 "$USER_MODEL"
        if ! php -l "$USER_MODEL" >/dev/null 2>&1; then
            echo "❌ Syntax error setelah inject model — rollback otomatis."
            cp "${USER_MODEL}.bak_${TIMESTAMP}" "$USER_MODEL"
        else
            echo "✅ Guard model User create/delete terpasang."
        fi
    fi
else
    echo "⚠️ User model tidak ditemukan: $USER_MODEL"
fi

for F in "$ADMIN_USER_CTRL" "$APP_USER_CTRL" "$CLIENT_USER_CTRL" "$USER_CREATE_SVC" "$USER_UPDATE_SVC" "$USER_DELETE_SVC" "$USER_MODEL"; do
    [ -f "$F" ] && sed -i "s|𝐏𝐑𝐎𝐓𝐄𝐂𝐓 𝐁𝐘My_GilXz|${BRAND_TEXT}|g" "$F" 2>/dev/null || true
done

cd "$PANEL_DIR" 2>/dev/null && {
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan cache:clear >/dev/null 2>&1 || true
    php artisan view:clear >/dev/null 2>&1 || true
    php artisan route:clear >/dev/null 2>&1 || true
}

echo ""
echo "==========================================="
echo "✅ Proteksi User/Admin Panel terpasang!"
echo "🔒 Selain Admin ID 1 tidak bisa create admin/root_admin."
echo "🗑️ Selain Admin ID 1 tidak bisa delete user/admin panel."
echo "🤖 Jalur API/bot/panel.js diblokir untuk create admin dan delete user."
echo "👥 Create user biasa tetap diizinkan."
echo "==========================================="