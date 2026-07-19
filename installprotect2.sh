#!/bin/bash

BRAND_NAME="${BRAND_NAME:-My_GilXz}"
BRAND_TEXT="${BRAND_TEXT:-Protect By My_GilXz}"
BRAND_LABEL="${BRAND_LABEL:-$BRAND_NAME}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@My_GilXz}"
CONTACT_TELEGRAM_2="${CONTACT_TELEGRAM_2:-@My_GilXztesti3}"

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi UserController.php anti hapus dan anti ubah data user..."

# Backup file lama jika ada
if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Model;
use Illuminate\Support\Collection;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Spatie\QueryBuilder\QueryBuilder;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\Translation\Translator;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Http\Requests\Admin\NewUserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;
class UserController extends Controller
{
    use AvailableLanguages;

    /**
     * UserController constructor.
     */
    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected Translator $translator,
        protected UserUpdateService $updateService,
        protected UserRepositoryInterface $repository,
        protected ViewFactory $view
    ) {
    }

    /**
     * Display user index page.
     */
    public function index(Request $request): View
    {
        // 🔒 Jika bukan admin ID 1, tampilkan list kosong
        if ((int) $request->user()->id !== 1) {
            $users = User::query()->whereRaw('1 = 0')->paginate(50);
            return $this->view->make('admin.users.index', ['users' => $users]);
        }

        $users = QueryBuilder::for(
            User::query()->select('users.*')
                ->selectRaw('COUNT(DISTINCT(subusers.id)) as subuser_of_count')
                ->selectRaw('COUNT(DISTINCT(servers.id)) as servers_count')
                ->leftJoin('subusers', 'subusers.user_id', '=', 'users.id')
                ->leftJoin('servers', 'servers.owner_id', '=', 'users.id')
                ->groupBy('users.id')
        )
            ->allowedFilters(['username', 'email', 'uuid'])
            ->allowedSorts(['id', 'uuid'])
            ->paginate(50);

        return $this->view->make('admin.users.index', ['users' => $users]);
    }

    /**
     * Display new user page.
     */
    public function create(): View
    {
        return $this->view->make('admin.users.new', [
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Display user view page.
     */
    public function view(Request $request, User $user): View
    {
        // 🔒 Hanya admin ID 1 yang bisa akses halaman view user
        if ((int) $request->user()->id !== 1) {
            abort(403, '✖️ Akses ditolak - protect by My_GilXz');
        }

        return $this->view->make('admin.users.view', [
            'user' => $user,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Delete a user from the system.
     *
     * @throws Exception
     * @throws PterodactylExceptionsDisplayException
     */
    public function delete(Request $request, User $user): RedirectResponse
    {
        // === FITUR TAMBAHAN: Proteksi hapus user ===
        if ((int) $request->user()->id !== 1) {
            throw new DisplayException("❌ 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 𝗉𝗋𝗈𝗍𝖾𝖼𝗍 𝖻𝗒 My_GilXz");
        }
        // ============================================

        if ($request->user()->id === $user->id) {
            throw new DisplayException($this->translator->get('admin/user.exceptions.user_has_servers'));
        }

        $this->deletionService->handle($user);

        return redirect()->route('admin.users');
    }

    /**
     * Create a user.
     *
     * @throws Exception
     * @throws Throwable
     */
    public function store(NewUserFormRequest $request): RedirectResponse
    {
        $user = $this->creationService->handle($request->normalize());
        $this->alert->success($this->translator->get('admin/user.notices.account_created'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Update a user on the system.
     *
     * @throws PterodactylExceptionsModelDataValidationException
     * @throws PterodactylExceptionsRepositoryRecordNotFoundException
     */
    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        // === FITUR TAMBAHAN: Proteksi ubah data penting ===
        $restrictedFields = ['email', 'first_name', 'last_name', 'password'];

        foreach ($restrictedFields as $field) {
            if ($request->filled($field) && (int) $request->user()->id !== 1) {
                throw new DisplayException("⚠️ 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 𝗉𝗋𝗈𝗍𝖾𝖼𝗍 𝖻𝗒 My_GilXz");
            }
        }

        // Cegah turunkan level admin ke user biasa
        if ($user->root_admin && (int) $request->user()->id !== 1) {
            throw new DisplayException("🚫 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 𝗉𝗋𝗈𝗍𝖾𝖼𝗍 𝖻𝗒 My_GilXz");
        }

        // Cegah non-ID 1 mengubah status admin (promote/demote)
        if ((int) $request->user()->id !== 1) {
            $inputAdmin = $request->input('root_admin', null);
            // Block jika mencoba set root_admin berbeda dari status saat ini
            if ($inputAdmin !== null && (bool) $inputAdmin !== (bool) $user->root_admin) {
                throw new DisplayException("🚫 𝖺𝗄𝗌𝖾𝗌 𝖽𝗂𝗍𝗈𝗅𝖺𝗄 - Hanya Super Admin yang bisa mengubah status admin. Protect by My_GilXz");
            }
        }
        // ====================================================

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $request->normalize());

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Get a JSON response of users on the system.
     */
    public function json(Request $request): Model|Collection
    {
        $users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

        // Handle single user requests.
        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            $user->md5 = md5(strtolower($user->email));

            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));

            return $item;
        });
    }
}
?>
EOF

chmod 644 "$REMOTE_PATH"

# Apply brand customization
sed -i "s|protect by My_GilXz|${BRAND_TEXT}|g" "$REMOTE_PATH" 2>/dev/null || true
sed -i "s|My_GilXz|${BRAND_NAME}|g" "$REMOTE_PATH" 2>/dev/null || true

echo "✅ Proteksi UserController.php berhasil dipasang!"
echo "📂 Lokasi file: $REMOTE_PATH"
echo "🗂️ Backup file lama: $BACKUP_PATH"

# ============================================================================
# BAGIAN 2: Inject banner "User Disembunyikan - Protected By" ke users index
# ============================================================================
USERS_INDEX_BLADE="/var/www/pterodactyl/resources/views/admin/users/index.blade.php"

if [ -f "$USERS_INDEX_BLADE" ]; then
    echo ""
    echo "🎨 Memasang banner 'User Disembunyikan' di halaman Users..."

    BLADE_BACKUP="${USERS_INDEX_BLADE}.bak_${TIMESTAMP}"
    cp "$USERS_INDEX_BLADE" "$BLADE_BACKUP"
    echo "📦 Backup blade: $BLADE_BACKUP"

    export BRAND_LABEL CONTACT_TELEGRAM CONTACT_TELEGRAM_2 USERS_INDEX_BLADE

    python3 <<'PYEOF'
import os, re

path = os.environ['USERS_INDEX_BLADE']
brand_label = os.environ.get('BRAND_LABEL', 'My_GilXz')
tg1 = os.environ.get('CONTACT_TELEGRAM', '@My_GilXz')
tg2 = os.environ.get('CONTACT_TELEGRAM_2', '@My_GilXztesti3')

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

MARKER = 'PROTEKSI_My_GilXz_USER_BANNER'

# Remove previous banner block (between markers) so we can re-inject fresh
content = re.sub(
    r'\{\{--\s*' + MARKER + r'_START.*?' + MARKER + r'_END\s*--\}\}\s*',
    '',
    content,
    flags=re.DOTALL,
)

banner = (
    '{{-- ' + MARKER + '_START --}}\n'
    '@if((int) auth()->user()->id !== 1)\n'
    '<div class="alert" style="background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); '
    'color: #fff; border: none; border-radius: 6px; padding: 15px 20px; margin-bottom: 15px; '
    'box-shadow: 0 4px 12px rgba(0,0,0,0.25);">\n'
    '    <h4 style="margin: 0 0 6px 0; color: #fff;">\n'
    '        <i class="fa fa-user-secret"></i> User Disembunyikan\n'
    '    </h4>\n'
    '    <p style="margin: 0; font-size: 13px; color: #e0e7ff;">\n'
    '        Daftar user disembunyikan untuk admin selain Root Administrator (ID 1).<br>\n'
    '        <i class="fa fa-shield"></i> Protected by:\n'
    '        <span class="label label-primary">__BRAND_LABEL__</span>\n'
    '        <span class="label label-success">__CONTACT_TG1__</span>\n'
    '        <span class="label label-info">__CONTACT_TG2__</span>\n'
    '    </p>\n'
    '</div>\n'
    '@endif\n'
    '{{-- ' + MARKER + '_END --}}\n'
)

# Inject right after the first @section('content') opening line
pattern = re.compile(r"(@section\(\s*['\"]content['\"]\s*\)\s*\n)")
m = pattern.search(content)
if m:
    insert_at = m.end()
    new_content = content[:insert_at] + banner + content[insert_at:]
else:
    # Fallback: prepend
    new_content = banner + content

# Substitute placeholders
new_content = (new_content
    .replace('__BRAND_LABEL__', brand_label)
    .replace('__CONTACT_TG1__', tg1)
    .replace('__CONTACT_TG2__', tg2))

# Atomic write
tmp = path + '.tmp_My_GilXz'
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(new_content)
os.replace(tmp, path)
print("✅ Banner injected into:", path)
PYEOF

    chown www-data:www-data "$USERS_INDEX_BLADE" 2>/dev/null || true
    chmod 644 "$USERS_INDEX_BLADE"
    echo "✅ Banner 'User Disembunyikan' terpasang."
else
    echo "⚠️ Blade file tidak ditemukan: $USERS_INDEX_BLADE (skip banner)"
fi
