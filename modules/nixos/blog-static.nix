{ config, pkgs, ... }:

let
  domain = "blog.goobhub.org";
  zoneName = "goobhub.org";
  blogSrc = "/var/www/blog-src";
  blogOut = "/var/www/blog";

  blogCss = pkgs.writeText "blog-style.css" ''
    :root {
      --bg: #f6f2ea;
      --text: #1f1b16;
      --muted: #6b5e51;
      --accent: #0f6b5b;
      --maxw: 700px;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: "ETBembo", "Palatino Linotype", "Book Antiqua", Palatino, serif;
      line-height: 1.6;
    }
    header, main, footer {
      max-width: var(--maxw);
      margin: 0 auto;
      padding: 24px;
    }
    header {
      padding-top: 32px;
      border-bottom: 1px solid #e1d8cc;
    }
    h1, h2, h3 { line-height: 1.2; }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    footer {
      color: var(--muted);
      border-top: 1px solid #e1d8cc;
      padding-bottom: 40px;
      font-size: 0.9rem;
    }
    pre, code {
      font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
      background: #efe7db;
      padding: 2px 4px;
      border-radius: 3px;
    }
    blockquote {
      margin: 0;
      padding: 12px 16px;
      border-left: 3px solid var(--accent);
      background: #efe7db;
    }
  '';

  blogTemplate = pkgs.writeText "blog-template.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{{title}}</title>
        <link rel="stylesheet" href="/style.css" />
      </head>
      <body>
        <header>
          <h1>{{title}}</h1>
        </header>
        <main>
          {{content}}
        </main>
        <footer>
          <div>Updated: {{updated}}</div>
        </footer>
      </body>
    </html>
  '';

  buildScript = pkgs.writeShellScript "build-blog" ''
    set -euo pipefail

    src="${blogSrc}"
    out="${blogOut}"
    tmpl="${blogTemplate}"
    css="${blogCss}"

    mkdir -p "$out"
    cp "$css" "$out/style.css"

    shopt -s nullglob
    found=0
    index_tmp="$(mktemp)"
    for md in "$src"/*.md; do
      base="$(basename "$md" .md)"
      if [ "$base" = "index" ]; then
        continue
      fi
      found=1
      title="$base"
      html_tmp="$out/$base.body.html"

      ${pkgs.cmark}/bin/cmark "$md" > "$html_tmp"

      updated="$(date -r "$md" "+%Y-%m-%d %H:%M")"
      sed \
        -e "s|{{title}}|$title|g" \
        -e "s|{{updated}}|$updated|g" \
        -e "/{{content}}/{
            r $html_tmp
            d
          }" \
        "$tmpl" > "$out/$base.html"

      printf "<li><a href=\"/%s.html\">%s</a> <span>(%s)</span></li>\n" \
        "$base" "$title" "$updated" >> "$index_tmp"

      rm -f "$html_tmp"
    done

    if [ "$found" -eq 0 ]; then
      cat > "$out/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Blog</title>
    <link rel="stylesheet" href="/style.css" />
  </head>
  <body>
    <header>
      <h1>Blog</h1>
    </header>
    <main>
      <p>No posts yet. Add a <code>.md</code> file in <code>${blogSrc}</code> and it will render here.</p>
    </main>
  </body>
</html>
EOF
    else
      cat > "$out/index.html" <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Blog</title>
    <link rel="stylesheet" href="/style.css" />
  </head>
  <body>
    <header>
      <h1>Blog</h1>
    </header>
    <main>
      <ul>
$(cat "$index_tmp")
      </ul>
    </main>
  </body>
</html>
EOF
    fi
    rm -f "$index_tmp"
  '';
in
{
  #####################################################################
  # Ensure the directory exists on boot
  #####################################################################
  systemd.tmpfiles.rules = [
    "d ${blogOut} 0755 root root - -"
    "d ${blogSrc} 0755 john users - -"
  ];

  #####################################################################
  # Nginx static blog
  #####################################################################
  services.nginx.virtualHosts."blog.goobhub.org" = {
    forceSSL = true;
    enableACME = true;
    root = blogOut;
    extraConfig = ''
      index index.html;
    '';
  };

  services.ddns.cloudflare.records = [
    {
      name = "blog";
      inherit zoneName;
      recordName = domain;
    }
  ];

  #####################################################################
  # Markdown -> HTML build
  #####################################################################
  systemd.services.blog-static-build = {
    description = "Build static blog from Markdown";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${buildScript}";
    };
  };

  systemd.paths.blog-static-build = {
    description = "Watch blog source for changes";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathModified = blogSrc;
      Unit = "blog-static-build.service";
    };
  };
}
