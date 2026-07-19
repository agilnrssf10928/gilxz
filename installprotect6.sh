#!/bin/bash

BRAND_NAME="${BRAND_NAME:-My_GilXz}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Anti Akses Settings..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Settings;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Settings\BaseSettingsFormRequest;

class IndexController extends Controller
{
    use AvailableLanguages;

    /**
     * IndexController constructor.
     */
    public function __construct(
        private AlertsMessageBag $alert,
        private Kernel $kernel,
        private SettingsRepositoryInterface $settings,
        private SoftwareVersionService $versionService,
        private ViewFactory $view
    ) {
    }

    /**
     * Render the UI for basic Panel settings.
     */
    public function index(): View
    {
        // 🔒 Anti akses menu Settings selain user ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'My_GilXz Protect - Akses ditolak❌');
        }

        return $this->view->make('admin.settings.index', [
            'version' => $this->versionService,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Handle settings update.
     *
     * @throws \Pterodactyl\Exceptions\Model\DataValidationException
     * @throws \Pterodactyl\Exceptions\Repository\RecordNotFoundException
     */
    public function update(BaseSettingsFormRequest $request): RedirectResponse
    {
        // 🔒 Anti akses update settings selain user ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'My_GilXz Protect t.me/My_GilXz - Akses ditolak');
        }

        foreach ($request->normalize() as $key => $value) {
            $this->settings->set('settings::' . $key, $value);
        }

        $this->kernel->call('queue:restart');
        $this->alert->success(
            'Panel settings have been updated successfully and the queue worker was restarted to apply these changes.'
        )->flash();

        return redirect()->route('admin.settings');
    }
}
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|My_GilXz Protect|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|My_GilXz|${BRAND_NAME}|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi Anti Akses Settings berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH (jika sebelumnya ada)"
echo "🔒 Hanya Admin (ID 1) yang bisa Akses Settings."

# === KUSTOMISASI PESAN AKSES DITOLAK (dari Protect Manager) ===
if [ -n "$DENY_MSG_ADMIN" ] && [ -f "$REMOTE_PATH" ]; then
  python3 - "$REMOTE_PATH" "$DENY_MSG_ADMIN" << 'PYABORT'
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
    print("✏️  Pesan akses ditolak dikustomisasi: " + msg)
PYABORT
fi
