# Bluesky identity import

## Defect and repair

`omniauth-atproto` 0.1.4's `info` block supplies `did` and `pds_host`; it does
not supply `name`, `nickname`, or `handle`. The callback previously assumed those
fields existed, using the DID for both display name and username generation.
Existing tests mocked a nickname that the installed strategy never returns.
The synthetic DID-only request regression fails on master with the DID as name.

The callback now fetches `app.bsky.actor.getProfile` from the public Bluesky
AppView using the authenticated DID. It accepts metadata only when the returned
DID matches. No OAuth credentials are sent. HTTP failures, redirects, invalid
JSON, malformed fields, DNS/TLS/connection failures, and timeouts leave login
available through existing fallbacks. Connection and read timeouts are bounded.
There is no local profile cache. AppView itself can lag upstream changes.

New accounts use the public display name (limited to Trove's 50-character
validation) and normalized handle-derived username. The username remains a
Trove identifier: dots and punctuation are normalized, it is limited to 25 base
characters, and collisions receive a suffix. It is not a verbatim Bluesky handle.
An absent display name falls back to the handle, then the DID.

Repeated sign-in refreshes the connected handle by DID but preserves the Trove
name and username, including legacy DID-generated values. This avoids guessing
whether a user deliberately chose a value and keeps public profile URLs stable.
On network failure the previous handle is retained only for the same DID. A
different DID is never inferred from a changed handle or merged with an account
by name. Existing explicit account-linking behavior is retained.

## Fields outside this repair

Avatar, banner, bio, birthday, followers, and following are not imported by the
existing OAuth callback. `BlueskyClient#profile` exists but is not called by
the callback or a background profile synchronization job. Public Bluesky counts
are separate from Trove relationships. Trove's generic landscape header and
generated about text are presentation fallbacks, not evidence of failed image
downloads. Public rendering alone cannot establish whether a member edited or
removed a field.

This repair does not download remote images or copy biography/banner content.
Tests include unavailable remote avatar URLs and preservation of a local avatar.
Those failures cannot break sign-in. A broader import should offer explicit
field selection and preview, preserve manual edits, and separately validate
remote artwork downloads. OAuth login consent is not evidence of consent to
copy every public field or enable social posting. No `profileprivacy` setting
was found in the current code; library visibility and social-posting preferences
remain independent and unchanged.

## Existing production records

There is no automatic backfill. This change will not repair an existing account's
display name, username, avatar, or bio on its next login. A safe correction would
require the owner to review the current public source and choose which fields
to copy, with current values protected against concurrent edits. Keep the
existing profile URL unless the owner explicitly requests a username change.
No production account writes, permission changes, merge, deployment, or backfill
are part of this patch.

## Validation

Request tests cover real-shaped initial OAuth data, repeated login, missing
fields, Unicode and long names, handle changes, DID changes, network failures,
manual text and avatar preservation, and unchanged posting preferences. Service
tests cover wrong response shapes, error status codes, redirects, and network
errors. Existing remembered-login, account-settings, Bluesky-client, and browser
OAuth tests are run alongside these regressions using synthetic users and an
isolated test database.
