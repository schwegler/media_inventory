# Opt-in remembered sign-in

A successful email or OAuth sign-in can opt this browser into an absolute 30-day lifetime. Every checkbox starts unchecked. Normal sessions remain session cookies. A regular second window in the same browser profile and exact host already shares those cookies; this change does not establish or claim to fix the reported new-window problem. Private windows, other browser profiles, and other hosts remain separate.

## Credentials and session boundaries

- Each device has an independent `SecureRandom.urlsafe_base64(32)` bearer credential (256 random bits). The database stores SHA-256 digests, an absolute expiry, and a user session generation. These are high-entropy random secrets, not passwords; a slow password KDF is unnecessary.
- Rails encrypts and authenticates the browser cookie. It is host-only, path `/`, HttpOnly, SameSite=Lax, and Secure in production. Its expiry never slides forward. No global `expire_after` is added to the ordinary session cookie.
- Restoration is attempted only without an ordinary authenticated session. Restoration and explicit sign-in reset the ordinary session, including its ID. A revoked or stale ordinary session fails closed without falling back to another identity on that request.
- Both newly opted-in and restored sessions reference the device row. Every subsequent request checks its existence/absolute expiry as well as the user generation. Deleting a device therefore invalidates its restored sessions, including copied ordinary session cookies.
- Logout deletes this device and clears the browser cookies. A successful unchecked login also deletes the previously remembered device. An authenticated encrypted cookie lets revocation identify the device even if its bearer credential has been superseded. Another device remains independent.
- Password digest updates through the User model atomically advance the database session generation and delete all devices in the same save transaction. This also covers a future password-reset flow using normal model saves. Ordinary sessions from before this feature have implicit generation zero and are invalidated on the first password change. Account deletion deletes device rows; sessions also require an existing user. Direct SQL/callback-bypassing password updates must not be used for resets.
- OAuth intent is captured only at the CSRF-validated POST request phase and carried in the ordinary encrypted session. Linking an already authenticated account never creates persistence. Callback parameters cannot opt in. Both provider callbacks now use the shared session-rotation path when signing in. Provider access/refresh tokens are never used as remember credentials.
- Native Hotwire/Tauri `device_user_id` behavior is unchanged and is a separate authentication mechanism.

## Rotation and concurrent windows

The first restore rotates the bearer credential with an atomic compare-and-swap against the current digest and rotation timestamp. This works on SQLite (which does not provide row-level `SELECT FOR UPDATE`) and PostgreSQL. A competing request reloads the winner's record. Only the winner writes a replacement remember cookie, preventing the later response from overwriting it.

For 60 seconds, the previous credential can restore a session and the current credential is not rotated again. After that, the previous credential fails and the current credential can rotate again. There is only one previous digest, never a chain. Expiry is checked on every path. Tests exercise stale snapshots, two independent browser cookie jars, and actual competing SQLite connections.

This overlap deliberately permits replay of the immediately previous credential within that bounded window. A stolen *current* bearer credential is usable until rotation, revocation, or expiry; rotation is not a substitute for HTTPS, HttpOnly, and protecting endpoints against XSS. A lost winner response can leave a browser with the previous credential; after the overlap it must sign in again. Server revocation still applies immediately to subsequent requests; already executing requests cannot be recalled. No automatic whole-account revocation on an invalid token is introduced, because an attacker could use it to log users out.

## Logging and key assumptions

No token is logged or included in URLs. Parameter filtering includes `remembered_device` in addition to existing token/password filters. Tests use only synthetic local accounts, mock providers, temporary databases, and a known synthetic key for the separate-process restart test.

Remembered cookie decryption and ordinary sessions require consistent application cookie keys across restarts. The separate-process test proves this with an unchanged synthetic key and database. Production secret stability has **not** been independently established, and no production secret values were inspected or changed. The prior infrastructure inspection found one Fly machine and one SQLite volume; there is no evidence for a multi-replica diagnosis.

References: [Rails security guide](https://guides.rubyonrails.org/security.html), [Rails cookie API](https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html).

## Release gates

1. Review this draft's authentication changes, 60-second overlap, revocation semantics, and the exact PR head's unit/request, browser, lint, Brakeman, and dependency audit results. Keep the PR draft until all required checks pass. Validate the migration on a disposable database using the production adapter; CI also checks schema loading on PostgreSQL.
2. Obtain separate release authorization. This PR does not authorize merging, deployment, production migrations, live sign-in, real-account token creation, key changes, credentials/grants, or account/network settings changes.
3. Before an authorized release, establish stable existing cookie-key configuration through configuration provenance without exposing values. Verify backups and the migration/rollback plan. Apply the additive migration before enabling code that queries its columns/table; deploy coordinated code only after the schema is ready.
4. In an authorized isolated staging environment, verify HTTPS host-only Secure/HttpOnly/SameSite cookies, true browser exit/relaunch, regular same-profile second windows, OAuth sign-in versus linking, logout, password changes, revocation, and unchanged native flows. The local browser regressions cover same-context windows, responsive/reduced-motion controls, and an actual Chrome exit/relaunch after removing the ordinary session cookie (Chrome can otherwise restore session cookies itself); the independent-process regression covers app restart. No live provider authorization was performed here.
5. If the reported regular-new-window issue remains, investigate exact host, browser/profile/private-mode boundaries, cookie acceptance, and non-secret configuration provenance separately. Do not attribute it to this persistence feature or to an unproven infrastructure cause.
6. Rollback: revert application code before considering schema removal, and expire/delete the remember cookie in a follow-up if necessary. Keep the additive schema until rollback traffic is drained. A rollback to pre-generation code cannot enforce generation-based revocation; do not use that rollback while relying on password-change revocations without a separate approved session invalidation plan. Expired rows may be purged later with a reviewed maintenance task; they cannot authenticate.
