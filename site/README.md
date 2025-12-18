# Evidence Graph Documentation Site

This directory contains the documentation site for the bofig (Evidence Graph) project, built with [zigzag-ssg](https://github.com/hyperpolymath/zigzag-ssg).

## Structure

```
site/
├── build.zig         # Zig build configuration
├── build.zig.zon     # Zig package manifest
├── src/
│   └── main.zig      # Site generator source
├── content/          # Markdown content files
│   ├── index.md      # Homepage
│   ├── docs.md       # Documentation
│   └── api.md        # API reference
├── templates/        # HTML templates (future)
├── static/           # Static assets
│   └── style.css     # Site stylesheet
└── _site/            # Generated output (gitignored)
```

## Building

### Prerequisites

- Zig 0.11 or later

### Build Commands

```bash
cd site

# Build the site generator
zig build

# Generate the site
./zig-out/bin/bofig-site build

# Output will be in _site/
```

### Development

The site is automatically built and deployed via GitHub Actions when changes are pushed to the `main` branch.

To develop locally:

```bash
# Build and serve locally (requires a local server)
zig build
./zig-out/bin/bofig-site build
cd _site && python3 -m http.server 8000
```

Visit http://localhost:8000

## Content Format

Content files use Markdown with YAML frontmatter:

```markdown
---
title: Page Title
description: Page description for SEO
template: default
order: 1
---

# Content Here

Your markdown content...
```

## Styling

The site uses a minimal, responsive CSS design with:
- System font stack
- Dark mode support
- Mobile-first approach
- No JavaScript required

## License

AGPL-3.0-or-later
