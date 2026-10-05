#!/usr/bin/perl
# Site builder for fasterbreakdownrecovery.co.uk
#
#   perl _build/build.pl
#
# Reads every _build/pages/**/*.page file and writes the matching .html file
# at the same path in the site root, wrapped in the shared head, header,
# navigation, breadcrumbs, footer and scripts. Also writes sitemap.xml.
#
# .page format: "key: value" lines, then "===HEAD===" (optional extra <head>
# markup, e.g. FAQ JSON-LD) and "===MAIN===" (everything inside <main>).
#   title, description, og_title, og_description  meta tags
#   label        breadcrumb label for this page
#   crumbs       "Label|path > Label|path" between Home and this page,
#                "none" for no breadcrumb bar (home, 404)
#   nav          top-level menu item to mark as current
#   kind         area | route | guide | service  (used by {{INDEX:...}})
#   region       e.g. "England > West Midlands" (grouping in hub lists)
#   card         one-line summary shown in hub lists
#   robots       optional robots meta; sitemap: no to leave out of sitemap
#
# Placeholders usable in HEAD and MAIN:
#   {{R}}            relative path back to the site root ("", "../", "/" on 404)
#   {{PHONE_HREF}} {{PHONE}} {{WA_HREF}}
#   {{INDEX:kind}}   grouped link list of every page of that kind
use strict;
use warnings;
use utf8;
use File::Find;
use File::Path qw(make_path);
use File::Basename qw(dirname);

my $BASE   = 'https://fasterbreakdownrecovery.co.uk';
my $NAME   = 'Faster Breakdown Recovery';
my $PHONE_HREF = 'tel:+442080580013';
my $PHONE  = '+44 20 8058 0013';
my $WA_HREF = 'https://wa.me/447988974609?text=Hi%20Faster%20Breakdown%20Recovery%2C%20I%20need%20help%20with%20my%20vehicle.';
my $EMAIL  = 'info@fasterbreakdownrecovery.co.uk';

# ---------------------------------------------------------------- navigation
my @NAV = (
  ['services', 'Services', 'services/index.html', [
     ['Breakdown recovery',  'services/index.html#breakdown-recovery'],
     ['Car recovery',        'services/index.html#car-recovery'],
     ['Van recovery',        'services/index.html#van-recovery'],
     ['Accident recovery',   'services/index.html#accident-recovery'],
     ['Roadside assistance', 'services/index.html#roadside-assistance'],
     ['Car transport',       'services/index.html#car-transport'],
     ['All services',        'services/index.html'],
  ]],
  ['areas', 'Areas', 'areas/index.html', [
     ['London',      'areas/london.html'],
     ['Birmingham',  'areas/birmingham.html'],
     ['Manchester',  'areas/manchester.html'],
     ['Leeds',       'areas/leeds.html'],
     ['Glasgow',     'areas/glasgow.html'],
     ['Cardiff',     'areas/cardiff.html'],
     ['All areas',   'areas/index.html'],
  ]],
  ['routes', 'Motorways', 'routes/index.html', [
     ['M1',  'routes/m1.html'],
     ['M6',  'routes/m6.html'],
     ['M25', 'routes/m25.html'],
     ['M4',  'routes/m4.html'],
     ['M5',  'routes/m5.html'],
     ['M62', 'routes/m62.html'],
     ['All motorways &amp; roads', 'routes/index.html'],
  ]],
  ['guides', 'Guides', 'guides/index.html', undef],
  ['about', 'About', 'about.html', undef],
  ['contact', 'Contact', 'contact.html', undef],
);

my @FOOTER_AREAS  = (['London','areas/london.html'],['Birmingham','areas/birmingham.html'],['Manchester','areas/manchester.html'],['Leeds','areas/leeds.html'],['Glasgow','areas/glasgow.html'],['Edinburgh','areas/edinburgh.html'],['Cardiff','areas/cardiff.html'],['Aberdeen','areas/aberdeen.html'],['All areas','areas/index.html']);
my @FOOTER_ROUTES = (['M1','routes/m1.html'],['M6','routes/m6.html'],['M25','routes/m25.html'],['M4','routes/m4.html'],['M5','routes/m5.html'],['M62','routes/m62.html'],['M8','routes/m8.html'],['All motorways &amp; roads','routes/index.html']);
my @FOOTER_INFO   = (['Services','services/index.html'],['Guides','guides/index.html'],['About','about.html'],['Contact','contact.html'],['Get a quote','contact.html#quote']);

# ---------------------------------------------------------------- read pages
my $root = dirname(dirname(__FILE__));
chdir $root or die "chdir $root: $!";

my %P;   # path.html => { meta..., head, main }
find(sub {
  return unless /\.page$/;
  my $src = $File::Find::name;
  (my $path = $src) =~ s{^_build/pages/}{};
  $path =~ s/\.page$/.html/;
  open my $fh, '<:encoding(UTF-8)', $_ or die "$src: $!";
  local $/; my $t = <$fh>; close $fh;
  $t =~ s/\r\n/\n/g;
  my @parts = split /^===([A-Z]+)===\n/m, $t;
  my $meta = shift @parts;
  my %p = (path => $path, src => $src, head => '');
  for (split /\n/, $meta) { $p{$1} = $2 if /^(\w+):\s*(.*?)\s*$/ }
  while (@parts) { my ($k, $v) = splice @parts, 0, 2; $p{lc $k} = $v }
  if (($p{template} // '') eq 'standard') { standard(\%p) }
  die "$src: missing ===MAIN=== or ===BODY===\n" unless defined $p{main};
  for (qw(title description label)) { warn "$src: no $_\n" unless $p{$_} }
  $P{$path} = \%p;
}, '_build/pages');

# ---------------------------------------------------------------- build
my $n = 0;
for my $path (sort keys %P) {
  my $p = $P{$path};
  my $depth = () = $path =~ m{/}g;
  my $R = $path eq '404.html' ? '/' : '../' x $depth;
  my $html = page($p, $R);
  open my $o, '>:encoding(UTF-8)', $path or die "$path: $!";
  print $o $html; close $o; $n++;
}
write_sitemap();
check_links();
print "built $n pages\n";

# ================================================================ templates
sub canonical {
  my $path = shift;
  return "$BASE/" if $path eq 'index.html';
  (my $c = $path) =~ s{(^|/)index\.html$}{$1};
  return "$BASE/$c";
}

sub fill {
  my ($s, $R) = @_;
  $s =~ s/\{\{INDEX:(\w+)\}\}/index_list($1, $R)/ge;
  $s =~ s/\{\{R\}\}/$R/g;
  $s =~ s/\{\{PHONE_HREF\}\}/$PHONE_HREF/g;
  $s =~ s/\{\{PHONE\}\}/$PHONE/g;
  $s =~ s/\{\{WA_HREF\}\}/$WA_HREF/g;
  return $s;
}

sub page {
  my ($p, $R) = @_;
  my $path = $p->{path};
  my $canon = canonical($path);
  my $ogt = $p->{og_title} // $p->{label};
  my $ogd = $p->{og_description} // $p->{description};
  my $robots = $p->{robots} ? qq{\n  <meta name="robots" content="$p->{robots}">} : '';

  # breadcrumbs
  my ($crumbs_html, $crumbs_ld) = ('', '');
  if (($p->{crumbs} // '') ne 'none') {
    my @c = (['Home', 'index.html']);
    for (split /\s*>\s*/, $p->{crumbs} // '') { my ($l, $h) = split /\|/; push @c, [$l, $h] }
    my @li; my @ld; my $pos = 0;
    for my $c (@c) {
      push @li, qq{        <li><a href="$R$c->[1]">$c->[0]</a></li>}, qq{        <li aria-hidden="true">/</li>};
      $pos++;
      push @ld, sprintf(q{      { "@type": "ListItem", "position": %d, "name": "%s", "item": "%s" }}, $pos, ld($c->[0]), canonical($c->[1]));
    }
    push @li, qq{        <li aria-current="page">$p->{label}</li>};
    $pos++;
    push @ld, sprintf(q{      { "@type": "ListItem", "position": %d, "name": "%s", "item": "%s" }}, $pos, ld($p->{label}), $canon);
    $crumbs_html = qq{\n  <nav class="breadcrumbs" aria-label="Breadcrumb">\n    <div class="container">\n      <ol>\n} . join("\n", @li) . qq{\n      </ol>\n    </div>\n  </nav>\n};
    $crumbs_ld = qq{\n  <script type="application/ld+json">\n  {\n    "\@context": "https://schema.org",\n    "\@type": "BreadcrumbList",\n    "itemListElement": [\n} . join(",\n", @ld) . qq{\n    ]\n  }\n  </script>};
  }
  my $head = $p->{head} ? "\n" . fill($p->{head}, $R) : '';
  $head =~ s/\n+$//;
  my $main = fill($p->{main}, $R);
  $main =~ s/\n+$//;

  return <<"HTML";
<!DOCTYPE html>
<html lang="en-GB">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$p->{title}</title>
  <meta name="description" content="$p->{description}">$robots
  <link rel="canonical" href="$canon">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="$NAME">
  <meta property="og:title" content="$ogt">
  <meta property="og:description" content="$ogd">
  <meta property="og:url" content="$canon">
  <meta property="og:image" content="$BASE/assets/images/og/og-image-placeholder.svg">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="icon" type="image/svg+xml" href="${R}assets/images/icons/favicon.svg">
  <link rel="stylesheet" href="${R}assets/css/styles.css">$crumbs_ld$head
</head>
<body>
  <a class="skip-link" href="#main">Skip to main content</a>

@{[ header($p, $R) ]}
$crumbs_html
  <main id="main">
$main
  </main>

@{[ footer($R) ]}
</body>
</html>
HTML
}

sub ld { my $s = shift; $s =~ s/&amp;/&/g; $s =~ s/"/\\"/g; $s }

sub header {
  my ($p, $R) = @_;
  my $cur = $p->{nav} // '';
  my (@desk, @mob);
  for my $item (@NAV) {
    my ($key, $label, $href, $drop) = @$item;
    my $ac = $key eq $cur ? ' aria-current="page"' : '';
    if ($drop) {
      my $d = join "\n", map { qq{            <a href="$R$_->[1]">$_->[0]</a>} } @$drop;
      push @desk, qq{        <div class="has-dropdown">\n          <a href="$R$href"$ac>$label</a>\n          <div class="dropdown">\n$d\n          </div>\n        </div>};
      push @mob, qq{        <li class="mobile-nav__group-label">$label</li>}, map { qq{        <li><a href="$R$_->[1]">$_->[0]</a></li>} } @$drop;
    } else {
      push @desk, qq{        <a href="$R$href"$ac>$label</a>};
      push @mob, qq{        <li><a href="$R$href">$label</a></li>};
    }
  }
  my $desk = join "\n", @desk;
  my $mob = join "\n", @mob;
  return <<"H";
  <header class="site-header">
    <div class="container header-inner">
      <a class="brand" href="${R}index.html"><span class="brand__logo-wrap"><img class="brand__logo" src="${R}assets/images/branding/faster-breakdown-recovery-logo.png" width="900" height="433" alt="$NAME"></span><span class="brand__text-sub">24/7 recovery across the UK</span></a>
      <nav class="main-nav" aria-label="Primary">
$desk
      </nav>
      <div class="header-cta">
        <a class="header-call" href="$PHONE_HREF" data-contact="phone-href" aria-label="Call us">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
          <span data-contact="phone-display">$PHONE</span>
        </a>
        <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="mobile-nav" aria-label="Open menu">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>
        </button>
      </div>
    </div>
    <div class="mobile-nav" id="mobile-nav">
      <ul class="mobile-nav__list">
        <li><a href="${R}index.html">Home</a></li>
$mob
      </ul>
    </div>
  </header>
H
}

sub footer {
  my $R = shift;
  my $col = sub {
    my ($title, $list) = @_;
    my $li = join "\n", map { qq{            <li><a href="$R$_->[1]">$_->[0]</a></li>} } @$list;
    return qq{        <div class="footer-col">\n          <h2>$title</h2>\n          <ul>\n$li\n          </ul>\n        </div>};
  };
  my $areas  = $col->('Areas', \@FOOTER_AREAS);
  my $routes = $col->('Motorways', \@FOOTER_ROUTES);
  my $info   = $col->('Information', \@FOOTER_INFO);
  return <<"F";
  <footer class="site-footer">
    <div class="container">
      <div class="footer-grid footer-grid--5">
        <div class="footer-brand">
          <a class="brand" href="${R}index.html" style="margin-bottom: 1rem;"><img class="brand__logo brand__logo--footer" src="${R}assets/images/branding/faster-breakdown-recovery-logo.png" width="900" height="433" alt="$NAME"></a>
          <p>24/7 breakdown and vehicle recovery across England, Scotland, Wales and Northern Ireland.</p>
          <p><a href="$PHONE_HREF" data-contact="phone-href">Call: <span data-contact="phone-display">$PHONE</span></a><br><a href="#" data-contact="email-href"><span data-contact="email-display">$EMAIL</span></a></p>
        </div>
$areas
$routes
$info
      </div>
      <div class="footer-bottom">
        <p>&copy; <span id="current-year">2026</span> $NAME. All rights reserved.</p>
        <div class="footer-bottom__legal">
          <a href="${R}legal/privacy-policy.html">Privacy Policy</a>
          <a href="${R}legal/terms-and-conditions.html">Terms &amp; Conditions</a>
          <a href="${R}legal/cookie-policy.html">Cookie Policy</a>
        </div>
      </div>
      <p class="footer-disclaimer">$NAME arranges breakdown and vehicle recovery across the UK. We don't run a public office or depot: when you call, we send a local recovery operator directly to where your vehicle is.</p>
    </div>
  </footer>

  <div class="mobile-call-bar">
    <a href="$PHONE_HREF" data-contact="phone-href">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
      Call Now — 24/7 Recovery
    </a>
  </div>
  <div class="page-bottom-spacer"></div>

  <script src="${R}assets/js/site-config.js"></script>
  <script src="${R}assets/js/main.js"></script>
F
}

# "template: standard" pages: build <main> from h1/lede/BODY/FAQ fields
#   eyebrow, h1, lede, side_title, cta_title   text fields
#   side_links / related   "Label|path ; Label|path" (paths from site root)
#   ===BODY=== prose HTML   ===FAQ=== "Q: ..." / "A: ..." pairs
sub standard {
  my $p = shift;
  my $links = sub {
    my ($spec, $ind) = @_;
    return '' unless $spec;
    return join "\n", map { my ($l, $h) = split /\|/; qq{$ind<li><a href="{{R}}$h">$l</a></li>} } split /\s*;\s*/, $spec;
  };
  my $btns = sub {
    my ($cls, $ind) = @_;
    return qq{$ind<a class="btn btn--primary $cls" href="{{PHONE_HREF}}" data-contact="phone-href">Call Now</a>\n}
         . qq{$ind<a class="btn btn--whatsapp $cls" href="{{WA_HREF}}" data-contact="whatsapp-href" target="_blank" rel="noopener">WhatsApp Us</a>};
  };
  my $eyebrow = $p->{eyebrow} // 'Breakdown recovery';
  my $h1 = $p->{h1} // $p->{label};
  my $body = $p->{body} // ''; $body =~ s/\n+$//;
  my $side = $links->($p->{side_links}, '            ');
  my $side_title = $p->{side_title} // 'Need recovery now?';
  my $cta = $p->{cta_title} // 'Broken Down Right Now?';
  my $m = <<"M";
    <section class="page-hero">
      <div class="container">
        <span class="eyebrow">$eyebrow</span>
        <h1>$h1</h1>
        <p class="page-hero__lede">$p->{lede}</p>
        <div class="hero__actions" style="margin-top:1.5rem;">
@{[ $btns->('btn--lg', '          ') ]}
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container two-col">
        <div class="prose">
$body
        </div>

        <aside class="side-panel">
          <h2>$side_title</h2>
@{[ $btns->('btn--block', '          ') ]}
          <a class="btn btn--outline btn--block" href="{{R}}contact.html#quote">Request a Quote</a>
          <ul>
$side
          </ul>
        </aside>
      </div>
    </section>
M
  # FAQ: visible <details> list + FAQPage JSON-LD from the same source
  if (my $faq = $p->{faq}) {
    my @qa;
    for my $block (split /^Q:\s*/m, $faq) {
      next unless $block =~ /\S/;
      my ($q, $a) = $block =~ /^(.*?)\s*\nA:\s*(.*?)\s*$/s or die "$p->{src}: bad FAQ block\n";
      $a =~ s/\s*\n\s*/ /g;
      push @qa, [$q, $a];
    }
    my $plus = q{<span class="icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg></span>};
    my $items = join "\n", map { qq{          <details class="faq-item">\n            <summary>$_->[0]$plus</summary>\n            <p>$_->[1]</p>\n          </details>} } @qa;
    my $faq_title = $p->{faq_title} // 'Frequently Asked Questions';
    $m .= <<"M";

    <section class="section section--alt">
      <div class="container">
        <div class="section-head section-head--center">
          <span class="eyebrow">Questions</span>
          <h2>$faq_title</h2>
        </div>
        <div class="faq-list">
$items
        </div>
      </div>
    </section>
M
    my $strip = sub { my $s = shift; $s =~ s/<[^>]+>//g; ld($s) };
    my $ents = join ",\n", map { sprintf qq{      {\n        "\@type": "Question",\n        "name": "%s",\n        "acceptedAnswer": { "\@type": "Answer", "text": "%s" }\n      }}, $strip->($_->[0]), $strip->($_->[1]) } @qa;
    $p->{head} .= qq{  <script type="application/ld+json">\n  {\n    "\@context": "https://schema.org",\n    "\@type": "FAQPage",\n    "mainEntity": [\n$ents\n    ]\n  }\n  </script>\n};
  }
  if (my $rel = $links->($p->{related}, '          ')) {
    $m .= <<"M";

    <section class="section">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Related</span>
          <h2>@{[ $p->{related_title} // 'Related Pages' ]}</h2>
        </div>
        <ul class="related-services">
$rel
        </ul>
      </div>
    </section>
M
  }
  $m .= <<"M";

    <section class="cta-band section">
      <div class="container">
        <h2>$cta</h2>
        <p>@{[ $p->{cta_text} // 'Call or WhatsApp us with your location and we&rsquo;ll arrange recovery to you.' ]}</p>
        <div class="cta-band__actions">
@{[ $btns->('btn--lg', '          ') ]}
          <a class="btn btn--outline btn--lg" href="{{R}}contact.html#quote">Get a Quote</a>
        </div>
      </div>
    </section>
M
  $p->{main} = $m;
}

# grouped list of every page of one kind, by region
sub index_list {
  my ($kind, $R) = @_;
  my %g;
  for my $p (values %P) {
    next unless ($p->{kind} // '') eq $kind;
    push @{ $g{ $p->{region} // 'Other' } }, $p;
  }
  my $out = '';
  my $last_nation = '';
  for my $region (sort { order($a) cmp order($b) } keys %g) {
    my @items = sort { ($a->{sort} // $a->{label}) cmp ($b->{sort} // $b->{label}) } @{ $g{$region} };
    (my $id = lc $region) =~ s/&amp;/and/g; $id =~ s/[^a-z0-9]+/-/g; $id =~ s/^-|-$//g;
    my ($nation, $sub) = split /\s*>\s*/, $region, 2;
    if ($sub) {
      if ($nation ne $last_nation) {
        (my $nid = lc $nation) =~ s/[^a-z0-9]+/-/g;
        $out .= qq{        <h2 class="index-nation" id="$nid">$nation</h2>\n};
        $last_nation = $nation;
      }
      $out .= qq{        <div class="index-group" id="$id">\n          <h3>$sub</h3>\n          <ul class="index-list">\n};
    } else {
      $last_nation = '';
      $out .= qq{        <div class="index-group" id="$id">\n          <h2>$region</h2>\n          <ul class="index-list">\n};
    }
    for my $p (@items) {
      my $card = $p->{card} // $p->{og_description} // '';
      my $name = $p->{short} // $p->{label};
      $out .= qq{            <li><a href="$R$p->{path}">$name</a>} . ($card ? qq{<span>$card</span>} : '') . qq{</li>\n};
    }
    $out .= qq{          </ul>\n        </div>\n};
  }
  $out =~ s/\n$//;
  return $out;
}

# England first, then Scotland, Wales, Northern Ireland, then the rest
sub order {
  my $r = shift;
  my $i = $r =~ /^Motorways/ ? 0 : $r =~ /^England/ ? 1 : $r =~ /^Scotland/ ? 2 : $r =~ /^Wales/ ? 3 : $r =~ /^Northern Ireland/ ? 4 : 5;
  return "$i $r";
}

sub write_sitemap {
  my @urls;
  for my $path (sort keys %P) {
    my $p = $P{$path};
    next if ($p->{sitemap} // 'yes') eq 'no';
    push @urls, "  <url><loc>" . canonical($path) . "</loc></url>";
  }
  open my $o, '>:encoding(UTF-8)', 'sitemap.xml' or die;
  print $o qq{<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n}, join("\n", @urls), "\n</urlset>\n";
  close $o;
}

# every relative href/src in the output must point at a file that exists
sub check_links {
  my $bad = 0;
  for my $path (sort keys %P) {
    next if $path eq '404.html';
    open my $fh, '<:encoding(UTF-8)', $path or die; local $/; my $h = <$fh>; close $fh;
    my @dir = split m{/}, $path; pop @dir;
    while ($h =~ /(?:href|src)="([^"#?]+)/g) {
      my $u = $1;
      next if $u =~ m{^(https?:|tel:|mailto:|//|data:)};
      my @d = @dir;
      for my $seg (split m{/}, $u, -1) { if ($seg eq '..') { pop @d } elsif ($seg ne '.') { push @d, $seg } }
      my $t = join '/', @d;
      $t .= 'index.html' if $t eq '' || $t =~ m{/$};
      unless (-e $t) { warn "broken link in $path: $u\n"; $bad++ }
    }
  }
  print "broken links: $bad\n";
}
