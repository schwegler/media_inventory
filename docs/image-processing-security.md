# Artwork processing security

Trove's custom artwork decoder invokes ImageMagick directly. The presence of
libvips in the image does not select it as this decoder's backend. Every call to
the custom decoder now identifies JPEG, PNG, GIF, or WebP from bytes before
starting ImageMagick and explicitly selects that raster coder. Filename and
declared MIME metadata are not accepted as evidence of a raster image.

This boundary also covers older stored covers and generic catalog attachments
that did not pass the remote downloader's type checks. Unsupported originals
remain stored, while their rendition job fails through the existing error path.
This change does not introduce new avatar/header attachment restrictions.

## Document policy

`config/imagemagick/document-policy.xml` denies external delegates and the
PostScript/PDF/XPS document coders, including their aliases.
`scripts/install_imagemagick_policy.rb` installs the rules during the base-image
build. It discovers and checks the normal Debian ImageMagick 6/7 configuration,
preserves the distribution's resource/path rules, and appends a marked Trove
block after existing rules. Repeated installation replaces the marked block.
An unexpected configuration fails the build instead of silently using the wrong
policy file. The installer writes configuration and is not a runtime diagnostic.

The PostgreSQL and SQLite CI jobs install the same policy before testing.
The final-image smoke test checks both effective policy and actual conversions:
an unavailable Ghostscript executable or a delegate error alone does not pass
the document-coder checks.

## Ghostscript package gate

The build and final-image CI run `ruby scripts/check_ghostscript.rb` without
booting Rails. It reads installed packages by their **source package**, so
Ghostscript libraries/data are checked even if the `gs` command is absent.
It also looks for named `gs`/`libgs` artifacts on PATH and in system/application
library locations, and rejects copies that cannot be tied to the inspected
Ghostscript packages. It does not install or execute Ghostscript.

For CVE-2026-125396, the verified Debian source-version floors are:

| Suite | Minimum source package version |
| --- | --- |
| Bookworm | `10.0.0~dfsg-11+deb12u9` |
| Trixie | `10.05.1~dfsg-1+deb13u2` |

Comparison uses `dpkg --compare-versions`; an older upstream `gs --version`
number alone cannot determine backport status. Unknown distribution/package
provenance, broken installation state, or unmanaged artifacts require review.
The inspected locations are reported by the script's source; this is not a
general detector for arbitrarily renamed binaries or every future vulnerability.

When the gate fails, inspect its package evidence. If Ghostscript is unnecessary,
review the package removal plan and remove its unused components in a new image.
If retained, update the installed Ghostscript binary/library/data packages from
the current distribution's security repository. Do not add Ghostscript to an
image where it is absent merely to satisfy a version check. Rebuild and rerun the
gate. No package mutation is performed automatically by these checks.

Primary references, verified 2026-11-26:

- [Render Upload2Shell advisory](https://render.com/docs/advisory-upload2shell)
- [Ghostscript vendor CVE index](https://ghostscript.com/releases/cve/index.html)
- [Debian CVE-2026-125396 tracker](https://security-tracker.debian.org/tracker/CVE-2026-125396)
- [ImageMagick security policy](https://imagemagick.org/security-policy/)

## Read-only deployed inventory

The repository does not establish which hosting provider or image digest is
currently deployed. Check every distinct web/worker image in the actual hosting
environment. For Docker, from a checkout containing the check script:

```sh
TROVE_CONTAINER='<actual-running-container>'
docker inspect --format '{{.Image}}' "$TROVE_CONTAINER"
docker exec -i "$TROVE_CONTAINER" ruby < scripts/check_ghostscript.rb
docker exec "$TROVE_CONTAINER" convert -version
docker exec "$TROVE_CONTAINER" convert -list policy
docker exec "$TROVE_CONTAINER" convert -list delegate
```

`docker exec` runs these commands without rerunning the image entrypoint. Do not
replace them with production `rails runner` or `rails console`: Trove's
application initialization runs database migrations, and its normal entrypoint
can run `db:prepare`. A newly built candidate is not evidence of the deployed
image's current package state.

## Isolated candidate-image validation

```sh
docker build --pull --no-cache --tag trove-image-security-check .
docker run --rm --network none --read-only \
  --entrypoint ruby trove-image-security-check scripts/check_ghostscript.rb
docker run --rm --network none --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=320m \
  --entrypoint bundle trove-image-security-check \
  exec ruby scripts/check_image_processing.rb
```

The smoke script creates harmless synthetic raster/document fixtures in a
temporary directory. It loads the decoder and its error class without booting
Rails, uses no application database or network, and checks supported raster
output, transparency, aspect ratio, first-frame GIF selection, predecode
rejection, document-coder denial, and a blanket delegate denial.

Run the focused decoder and rendition RSpec files in the separately configured
test environment, using the README's explicitly disposable database commands.
`RAILS_ENV=test` alone does not isolate a reused `DATABASE_URL`. The production
image excludes test gems, so its standalone smoke does not replace Rails specs.

Record the successful candidate image digest and verify the deployed digest
after a separately authorized rollout. Preserve normal JPEG/PNG/GIF/WebP artwork
behavior and investigate unexpected processing failures before replacing the
running service.
