# Lipwa documentation site

This directory is the source for the Lipwa documentation site. It uses Jekyll
with a custom layout and has no theme or plugin dependency.

From the repository root:

```bash
bundle install
bundle exec rake docs:build
```

The generated site is written to `_site/`. GitHub Pages can publish directly
from the `docs/` directory on the main branch; `baseurl` in `_config.yml` is
already set for the `/lipwa` project path.
