# Public email obfuscation

This deters basic raw-source scrapers; it does not prevent spam or hide the address from HTML-aware crawlers, browser automation, source-repository readers, or visitors. Previously published copies may remain indexed.

Audit of latest main found no public creator contact/mailto link or public address in application views/helpers. No contact link was added. User account emails and mailer/authentication behavior must remain unchanged. The regression check scans public templates/helpers for accidental plaintext introduction; coordinate any future contact link in the separate Trove redesign with native entity encoding. This audit does not validate that separate unmerged PR.

No account, DNS, routing, or authentication settings change. Run `python3 scripts/check_public_email.py` for the source regression check. Manual release check: Tab to Contact, activate it, copy its destination; where address text is visible, copy it and inspect print preview, with JavaScript disabled as well as enabled.
