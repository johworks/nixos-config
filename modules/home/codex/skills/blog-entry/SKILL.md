---
name: blog-entry
description: Write and publish a concise Markdown blog entry about a completed feature or meaningful change in the NixOS repository to the NUC's static blog. Use for informal project write-ups; do not use for ordinary technical documentation or release notes.
metadata:
  short-description: Publish a small write-up for completed repo work
---

# Blog entries

Use this skill when a feature, fix, or experiment deserves a short, human-readable note on the personal blog.

## Source and renderer

The live blog is served at `https://blog.goobhub.org`. Its Markdown source is `/var/www/blog-src` on the NUC, and generated HTML is written to `/var/www/blog`. The NixOS module at `modules/nixos/blog-static.nix` watches the source directory and runs `cmark` for each `.md` file. The filename without `.md` becomes the page filename, the outer page title, and the label on the index. There is no front matter or metadata parser.

Write only the Markdown source. Do not edit generated HTML or CSS. Use a lowercase, hyphenated filename that is descriptive when shown in the index, and do not call a post `index.md` because that name is reserved by the builder. Put this visible Markdown field immediately below the title, using the model identifier supplied by the harness or the human author:

```markdown
**Author:** gpt-5.6-luna
```

Use the active model name for an entry written by an agent and the human's name for an entry written by the user. Keep the field as ordinary Markdown so the existing renderer displays it without any special build logic.

## Writing

First inspect the relevant diff, recent commits, or feature files so the entry reflects work that actually happened. Keep the voice personal, relaxed, and specific. A good entry usually contains:

- a clear first-level heading;
- the small problem or motivation;
- what was changed, with one or two concrete implementation details;
- the result or a next thing to try.

Aim for a few short paragraphs. Include a small code block only when it makes the idea easier to see. Explain acronyms or local configuration names when a reader would not know them. Do not invent metrics, user feedback, deployment results, or future plans. The post can be about the development process itself, including this agent-authored workflow.

## Publish and verify

Create or update `/var/www/blog-src/<slug>.md` with the normal file editing tool. The active `blog-static-build.path` unit should rebuild the site when the source directory changes. If an immediate check is useful, start `blog-static-build.service` and then inspect the result:

```sh
sudo systemctl is-active blog-static-build.path
sudo systemctl start blog-static-build.service
test -s /var/www/blog/<slug>.html
curl --fail --silent --show-error "https://blog.goobhub.org/<slug>.html" >/dev/null
```

Use the final URL and the source filename when reporting the completed entry. If the service cannot be started in the current session, verify the Markdown with `cmark` when available and report that the automatic path watcher will perform the build.
