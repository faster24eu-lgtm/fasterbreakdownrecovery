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
my $FORM_TO = 'faster24eu@gmail.com';   # formsubmit.co recipient (same as takeldienstfaster.be)

# ---------------------------------------------------------------- languages
# Pages under fr/, nl/, pl/ and ro/ get that language; everything else is en.
# Pages that are translations of each other share a "tgroup" value, which
# drives the hreflang links and the language switcher.
my @LANGS = qw(en fr nl pl ro);
my %LANGNAME = (en => 'English', fr => 'Français', nl => 'Nederlands', pl => 'Polski', ro => 'Română');
my %LOCALE = (en => 'en_GB', fr => 'fr_FR', nl => 'nl_NL', pl => 'pl_PL', ro => 'ro_RO');
my %HOME = (en => 'index.html', fr => 'fr/index.html', nl => 'nl/index.html', pl => 'pl/index.html', ro => 'ro/index.html');
my %L = (
  en => { call => 'Call Now', wa => 'WhatsApp Us', quote => 'Request a Quote', getquote => 'Get a Quote', home => 'Home',
          sub => '24/7 recovery', fab => 'Call now — fast help', badge => 'price-badge-125-gbp.svg', badge_alt => 'From £125',
          faq => 'Frequently Asked Questions', q => 'Questions', related => 'Related', related_title => 'Related Pages',
          side => 'Need recovery now?', cta => 'Broken Down Right Now?', cta_text => 'Call or WhatsApp us with your location and we&rsquo;ll arrange recovery to you.',
          tagline => '24/7 breakdown and vehicle recovery across England, Scotland, Wales and Northern Ireland.',
          disclaimer => 'Faster Breakdown Recovery arranges breakdown and vehicle recovery across the UK. We don&#39;t run a public office or depot: when you call, we send a local recovery operator directly to where your vehicle is.',
          privacy => 'Privacy Policy', terms => 'Terms &amp; Conditions', cookies => 'Cookie Policy', pages => 'Pages', language => 'Language',
          wa_text => 'Hi%20Faster%20Breakdown%20Recovery%2C%20I%20need%20help%20with%20my%20vehicle.' },
  fr => { call => 'Appeler', wa => 'WhatsApp', quote => 'Demander un devis', getquote => 'Demander un devis', home => 'Accueil',
          sub => 'Dépannage 24h/24 au Royaume-Uni', fab => 'Appelez — aide rapide', badge => 'price-badge-125-gbp-fr.svg', badge_alt => 'Dès 125 £',
          faq => 'Questions fréquentes', q => 'Questions', related => 'Voir aussi', related_title => 'Pages utiles',
          side => 'Besoin d&rsquo;un dépanneur ?', cta => 'En panne en ce moment ?', cta_text => 'Appelez-nous ou envoyez un WhatsApp avec votre position, nous organisons le dépannage. On parle français.',
          tagline => 'Dépannage et remorquage 24h/24 en Angleterre, en Écosse, au pays de Galles et en Irlande du Nord.',
          disclaimer => 'Faster Breakdown Recovery organise le dépannage et le remorquage partout au Royaume-Uni. Nous n&#39;avons pas de bureau ouvert au public : quand vous appelez, nous envoyons un dépanneur local directement à votre véhicule.',
          privacy => 'Confidentialité', terms => 'Conditions générales', cookies => 'Cookies', pages => 'Pages', language => 'Langue',
          wa_text => 'Bonjour%20Faster%2C%20j%27ai%20besoin%20d%27aide%20pour%20mon%20v%C3%A9hicule.' },
  nl => { call => 'Bel nu', wa => 'WhatsApp', quote => 'Vraag een prijs', getquote => 'Vraag een prijs', home => 'Home',
          sub => '24/7 pechhulp in het Verenigd Koninkrijk', fab => 'Bel nu — snelle hulp', badge => 'price-badge-125-gbp-nl.svg', badge_alt => 'Vanaf £125',
          faq => 'Veelgestelde vragen', q => 'Vragen', related => 'Zie ook', related_title => 'Handige pagina&#39;s',
          side => 'Nu hulp nodig?', cta => 'Staat u nu stil?', cta_text => 'Bel of WhatsApp ons met uw locatie en wij regelen de takeldienst. Wij spreken Nederlands.',
          tagline => '24/7 pechhulp en takeldienst in Engeland, Schotland, Wales en Noord-Ierland.',
          disclaimer => 'Faster Breakdown Recovery regelt pechhulp en takeldiensten in heel het Verenigd Koninkrijk. Wij hebben geen kantoor voor bezoekers: als u belt, sturen wij een lokale takelwagen rechtstreeks naar uw voertuig.',
          privacy => 'Privacy', terms => 'Voorwaarden', cookies => 'Cookies', pages => 'Pagina&#39;s', language => 'Taal',
          wa_text => 'Hallo%20Faster%2C%20ik%20heb%20hulp%20nodig%20met%20mijn%20voertuig.' },
  pl => { call => 'Zadzwoń', wa => 'WhatsApp', quote => 'Zapytaj o cenę', getquote => 'Zapytaj o cenę', home => 'Strona główna',
          sub => 'Pomoc drogowa 24/7 w Wielkiej Brytanii', fab => 'Zadzwoń — szybka pomoc', badge => 'price-badge-125-gbp-pl.svg', badge_alt => 'Od 125 £',
          faq => 'Najczęstsze pytania', q => 'Pytania', related => 'Zobacz też', related_title => 'Przydatne strony',
          side => 'Potrzebujesz pomocy?', cta => 'Masz awarię teraz?', cta_text => 'Napisz na WhatsApp – możesz pisać po polsku – albo zadzwoń i podaj swoją lokalizację. Zorganizujemy holowanie.',
          tagline => 'Pomoc drogowa i holowanie 24/7 w Anglii, Szkocji, Walii i Irlandii Północnej.',
          disclaimer => 'Faster Breakdown Recovery organizuje pomoc drogową i holowanie w całej Wielkiej Brytanii. Nie mamy biura dla klientów: po Twoim telefonie wysyłamy lokalną lawetę prosto do Twojego pojazdu.',
          privacy => 'Prywatność', terms => 'Regulamin', cookies => 'Cookies', pages => 'Strony', language => 'Język',
          wa_text => 'Dzie%C5%84%20dobry%2C%20potrzebuj%C4%99%20pomocy%20drogowej.' },
  ro => { call => 'Sună acum', wa => 'WhatsApp', quote => 'Cere o ofertă', getquote => 'Cere o ofertă', home => 'Acasă',
          sub => 'Tractări 24/7 în Regatul Unit', fab => 'Sună — ajutor rapid', badge => 'price-badge-125-gbp-ro.svg', badge_alt => 'De la 125 £',
          faq => 'Întrebări frecvente', q => 'Întrebări', related => 'Vezi și', related_title => 'Pagini utile',
          side => 'Ai nevoie de ajutor?', cta => 'Ai rămas în pană acum?', cta_text => 'Sună-ne sau scrie-ne pe WhatsApp cu locația ta și organizăm tractarea. Vorbim românește.',
          tagline => 'Asistență rutieră și tractări 24/7 în Anglia, Scoția, Țara Galilor și Irlanda de Nord.',
          disclaimer => 'Faster Breakdown Recovery organizează asistență rutieră și tractări în tot Regatul Unit. Nu avem birou pentru clienți: după apelul tău, trimitem o platformă locală direct la mașina ta.',
          privacy => 'Confidențialitate', terms => 'Termeni', cookies => 'Cookie-uri', pages => 'Pagini', language => 'Limba',
          wa_text => 'Bun%C4%83%20ziua%2C%20am%20nevoie%20de%20tractare.' },
);
# quote form labels per language
my %FORM = (
  en => ['Name*', 'Phone number*', 'Email', 'Vehicle make &amp; model', 'Where is the vehicle now? (postcode or location)*', 'Where does it need to go?', 'What&#39;s happened?*', 'Send Request', 'Your request is sent to us by email. For anything urgent, please call or WhatsApp us instead.'],
  fr => ['Nom*', 'Téléphone*', 'E-mail', 'Marque et modèle du véhicule', 'Où se trouve le véhicule ? (code postal ou lieu)*', 'Où doit-il être amené ?', 'Que s&#39;est-il passé ?*', 'Envoyer la demande', 'Votre demande nous est envoyée par e-mail. En cas d&#39;urgence, appelez-nous ou écrivez-nous sur WhatsApp.'],
  nl => ['Naam*', 'Telefoonnummer*', 'E-mail', 'Merk en model voertuig', 'Waar staat het voertuig nu? (postcode of locatie)*', 'Waar moet het naartoe?', 'Wat is er gebeurd?*', 'Verstuur aanvraag', 'Uw aanvraag wordt per e-mail naar ons verstuurd. Is het dringend? Bel of WhatsApp ons.'],
  pl => ['Imię i nazwisko*', 'Telefon*', 'E-mail', 'Marka i model pojazdu', 'Gdzie jest teraz pojazd? (kod pocztowy lub miejsce)*', 'Dokąd go zawieźć?', 'Co się stało?*', 'Wyślij zapytanie', 'Zapytanie trafi do nas e-mailem. W pilnej sprawie napisz na WhatsApp lub zadzwoń.'],
  ro => ['Nume*', 'Telefon*', 'E-mail', 'Marca și modelul mașinii', 'Unde se află mașina acum? (cod poștal sau locație)*', 'Unde trebuie dusă?', 'Ce s-a întâmplat?*', 'Trimite cererea', 'Cererea ajunge la noi pe e-mail. Dacă e urgent, scrie-ne pe WhatsApp sau sună-ne.'],
);

# simple top menu for the non-English sites: [label, path]
my %NAV_I18N = (
  fr => [['Accueil','fr/index.html'],['Douvres &amp; Eurotunnel','fr/douvres-folkestone-eurotunnel.html'],['M20','fr/m20.html'],['M25','fr/m25.html'],['Londres','fr/londres.html'],['En panne au R.-U. ?','fr/panne-au-royaume-uni.html']],
  nl => [['Home','nl/index.html'],['Dover &amp; Eurotunnel','nl/dover-folkestone-eurotunnel.html'],['M20','nl/m20.html'],['M25','nl/m25.html'],['Londen','nl/londen.html'],['Pech in Engeland?','nl/pech-in-engeland.html']],
  pl => [['Strona główna','pl/index.html'],['Londyn','pl/londyn.html'],['Birmingham','pl/birmingham.html'],['Awaria w UK – co robić?','pl/awaria-w-uk.html'],['Odbiór z Copart','pl/copart.html']],
  ro => [['Acasă','ro/index.html'],['Londra','ro/londra.html'],['Birmingham','ro/birmingham.html'],['Pană în UK – ce faci?','ro/pana-in-uk.html'],['Ridicare Copart','ro/copart.html']],
);

# ---------------------------------------------------------------- navigation
my @NAV = (
  ['services', 'Services', 'services/index.html', [
     ['Breakdown recovery',  'services/breakdown-recovery.html'],
     ['Car recovery',        'services/car-recovery.html'],
     ['Van recovery',        'services/van-recovery.html'],
     ['Accident recovery',   'services/accident-recovery.html'],
     ['Roadside assistance', 'services/roadside-assistance.html'],
     ['Car transport',       'services/car-transport.html'],
     ['Copart collection',   'services/copart-collection.html'],
     ['Repatriation to the UK', 'repatriation/index.html'],
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
my @FOOTER_INFO   = (['Services','services/index.html'],['Repatriation to the UK','repatriation/index.html'],['Guides','guides/index.html'],['About','about.html'],['Contact','contact.html'],['Get a quote','contact.html#quote']);

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
  $p{lang} //= $path =~ m{^(fr|nl|pl|ro)/} ? $1 : 'en';
  if (($p{template} // '') eq 'standard') { standard(\%p) }
  die "$src: missing ===MAIN=== or ===BODY===\n" unless defined $p{main};
  for (qw(title description label)) { warn "$src: no $_\n" unless $p{$_} }
  $P{$path} = \%p;
}, '_build/pages');

# ---------------------------------------------------------------- SEO pass
# English city, road and core service pages get a short title that fits in
# Google's results (~60 chars) and a description that leads with the offer.
# Set "seo: no" on a page to keep its own title/description.
my $SERVICE_RE = qr{^services/(breakdown-recovery|car-recovery|vehicle-recovery|24-hour-breakdown-recovery|roadside-assistance|van-recovery|accident-recovery)-};
for my $p (values %P) {
  next unless $p->{lang} eq 'en' && ($p->{seo} // 'yes') ne 'no';
  my $kind = $p->{kind} // '';
  my $offer = 'From £125, often with you in about 30 minutes.';
  if ($kind eq 'area') {
    $p->{title} = "Breakdown Recovery $p->{label} 24/7 | From £125 | Faster";
  } elsif ($kind eq 'route') {
    my $s = $p->{short} // $p->{label};
    $s = $1 if $s =~ /\(([A-Z0-9]+)\)$/;     # "Aberdeen Western Peripheral Route (AWPR)" -> AWPR
    $p->{title} = "$s Breakdown Recovery 24/7 | From £125 | Faster";
  } elsif ($p->{path} =~ $SERVICE_RE) {
    (my $first = $p->{title}) =~ s/\s*\|.*$//;
    $p->{title} = "$first | From £125 | Faster";
  } else {
    next;
  }
  $p->{description} = "$offer $p->{description}" unless $p->{description} =~ /125/;
  $p->{schema_area} = $kind eq 'route' ? ($p->{short} // $p->{label}) : $kind eq 'area' ? $p->{label} : undef;
}

# translation groups: tgroup => { lang => path }
my %TG;
for my $p (values %P) { $TG{$p->{tgroup}}{$p->{lang}} = $p->{path} if $p->{tgroup} }
for my $l (@LANGS) { $TG{"home"}{$l} = $HOME{$l} if $P{$HOME{$l}} }
$P{$HOME{$_}}{tgroup} //= 'home' for grep { $P{$HOME{$_}} } @LANGS;

# ---------------------------------------------------------------- build
my $n = 0;
for my $path (sort keys %P) {
  my $p = $P{$path};
  my $depth = () = $path =~ m{/}g;
  my $R = $path eq '404.html' ? '/' : '../' x $depth;
  my $html = page($p, $R);
  make_path(dirname($path)) if $path =~ m{/};
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

sub wa_href { "https://wa.me/447988974609?text=$L{$_[0] // 'en'}{wa_text}" }

sub fill {
  my ($s, $R, $lang) = @_;
  $lang //= 'en';
  $s =~ s/\{\{INDEX:(\w+)\}\}/index_list($1, $R)/ge;
  $s =~ s/\{\{QUOTE_FORM\}\}/quote_form($lang)/ge;
  $s =~ s/\{\{R\}\}/$R/g;
  $s =~ s/\{\{PHONE_HREF\}\}/$PHONE_HREF/g;
  $s =~ s/\{\{PHONE\}\}/$PHONE/g;
  my $wa = wa_href($lang);
  $s =~ s/\{\{WA_HREF\}\}/$wa/g;
  return $s;
}

sub page {
  my ($p, $R) = @_;
  my $path = $p->{path};
  my $canon = canonical($path);
  my $ogt = $p->{og_title} // $p->{label};
  my $ogd = $p->{og_description} // $p->{description};
  my $robots = $p->{robots} ? qq{\n  <meta name="robots" content="$p->{robots}">} : '';
  my $lang = $p->{lang};
  my $htmllang = $lang eq 'en' ? 'en-GB' : $lang;
  my $alts = '';
  if ($p->{tgroup} && keys %{ $TG{$p->{tgroup}} } > 1) {
    my $g = $TG{$p->{tgroup}};
    $alts = join '', map { qq{\n  <link rel="alternate" hreflang="} . ($_ eq 'en' ? 'en-GB' : $_) . qq{" href="} . canonical($g->{$_}) . qq{">} } grep { $g->{$_} } @LANGS;
    $alts .= qq{\n  <link rel="alternate" hreflang="x-default" href="} . canonical($g->{en}) . qq{">} if $g->{en};
  }

  # breadcrumbs
  my ($crumbs_html, $crumbs_ld) = ('', '');
  if (($p->{crumbs} // '') ne 'none') {
    my @c = ([$L{$lang}{home}, $HOME{$lang}]);
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
    $crumbs_ld = "\n  <script type=\"application/ld+json\">\n  {\n    \"\@context\": \"https://schema.org\",\n    \"\@type\": \"BreadcrumbList\",\n    \"itemListElement\": [\n" . join(",\n", @ld) . "\n    ]\n  }\n  </script>";
  }
  my $head = $p->{head} ? "\n" . fill($p->{head}, $R, $lang) : '';
  $head =~ s/\n+$//;
  my $main = fill($p->{main}, $R, $lang);
  $main = add_nearby($p, $main, $R) if $lang eq 'en' && ($p->{kind} // '') =~ /^(area|route)$/;
  if ($p->{schema_area}) {
    $head = schema_local($p, $canon) . $head;
    # structured data must match visible content: show the offer under the lede
    $main =~ s{(<p class="page-hero__lede">.*?</p>)}{$1\n        <p class="offer-line"><strong>From &pound;125</strong> &middot; 24/7 &middot; often with you in about 30 minutes (depends on location and traffic)</p>}s
      unless $main =~ /offer-line/;
  }
  $main =~ s/\n+$//;

  return <<"HTML";
<!DOCTYPE html>
<html lang="$htmllang">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$p->{title}</title>
  <meta name="description" content="$p->{description}">$robots
  <link rel="canonical" href="$canon">$alts
  <meta property="og:locale" content="$LOCALE{$lang}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="$NAME">
  <meta property="og:title" content="$ogt">
  <meta property="og:description" content="$ogd">
  <meta property="og:url" content="$canon">
  <meta property="og:image" content="$BASE/assets/images/og/og-faster-breakdown-recovery-1200x630.jpg">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:image" content="$BASE/assets/images/og/og-faster-breakdown-recovery-1200x630.jpg">
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

@{[ footer($R, $p) ]}
</body>
</html>
HTML
}

sub ld { my $s = shift; $s =~ s/&amp;/&/g; $s =~ s/"/\\"/g; $s }

sub header {
  my ($p, $R) = @_;
  my $lang = $p->{lang};
  my $S = $L{$lang};
  my $cur = $p->{nav} // '';
  my (@desk, @mob);
  # non-English sites: flat menu from %NAV_I18N (first entry = home, reached via the logo)
  my @nav = $lang eq 'en' ? @NAV : map { [$_->[1], $_->[0], $_->[1], undef] } @{ $NAV_I18N{$lang} }[1 .. $#{ $NAV_I18N{$lang} }];
  $cur = $p->{path} if $lang ne 'en';
  for my $item (@nav) {
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
  # language switcher: the same page in another language when it exists, else that language's home
  my $g = $p->{tgroup} ? $TG{$p->{tgroup}} : {};
  my @sw = map {
    my $t = $g->{$_} // $HOME{$_};
    my $c = $_ eq $lang ? ' aria-current="true"' : '';
    qq{<a href="$R$t" hreflang="$_" lang="$_"$c>$LANGNAME{$_}</a>}
  } @LANGS;
  push @desk, qq{        <div class="has-dropdown lang-switch">\n          <a href="$R$HOME{$lang}">} . uc($lang) . qq{ &#9662;</a>\n          <div class="dropdown">\n} . join("\n", map { "            $_" } @sw) . qq{\n          </div>\n        </div>};
  push @mob, qq{        <li class="mobile-nav__group-label">$S->{language}</li>}, map { "        <li>$_</li>" } @sw;
  my $desk = join "\n", @desk;
  my $mob = join "\n", @mob;
  return <<"H";
  <header class="site-header">
    <div class="container header-inner">
      <a class="brand" href="$R$HOME{$lang}"><span class="brand__logo-wrap"><img class="brand__logo" src="${R}assets/images/branding/faster-breakdown-recovery-logo-500w.png" width="500" height="241" alt="$NAME"></span><span class="brand__text-sub">$S->{sub}</span></a>
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
        <li><a href="$R$HOME{$lang}">$S->{home}</a></li>
$mob
      </ul>
    </div>
  </header>
H
}

sub footer {
  my ($R, $p) = @_;
  my $lang = $p->{lang};
  my $S = $L{$lang};
  my $col = sub {
    my ($title, $list) = @_;
    my $li = join "\n", map { qq{            <li><a href="$R$_->[1]">$_->[0]</a></li>} } @$list;
    return qq{        <div class="footer-col">\n          <h2>$title</h2>\n          <ul>\n$li\n          </ul>\n        </div>};
  };
  my $langs = [ map { [$LANGNAME{$_}, $HOME{$_}] } @LANGS ];
  my ($c1, $c2, $c3) = $lang eq 'en'
    ? ($col->('Areas', \@FOOTER_AREAS), $col->('Motorways', \@FOOTER_ROUTES), $col->('Information', \@FOOTER_INFO))
    : ($col->($S->{pages}, $NAV_I18N{$lang}), $col->($S->{language}, $langs), '');
  my $wa = wa_href($lang);
  return <<"F";
  <footer class="site-footer">
    <div class="container">
      <div class="footer-grid footer-grid--5">
        <div class="footer-brand">
          <a class="brand" href="$R$HOME{$lang}" style="margin-bottom: 1rem;"><img class="brand__logo brand__logo--footer" src="${R}assets/images/branding/faster-breakdown-recovery-logo-500w.png" width="500" height="241" alt="$NAME"></a>
          <p>$S->{tagline}</p>
          <p><a href="$PHONE_HREF" data-contact="phone-href">Call: <span data-contact="phone-display">$PHONE</span></a><br><a href="#" data-contact="email-href"><span data-contact="email-display">$EMAIL</span></a></p>
        </div>
$c1
$c2
$c3
      </div>
      <div class="footer-bottom">
        <p>&copy; <span id="current-year">2026</span> $NAME.</p>
        <div class="footer-bottom__legal">
          <a href="${R}legal/privacy-policy.html">$S->{privacy}</a>
          <a href="${R}legal/terms-and-conditions.html">$S->{terms}</a>
          <a href="${R}legal/cookie-policy.html">$S->{cookies}</a>
        </div>
      </div>
      <p class="footer-disclaimer">$S->{disclaimer}</p>
      <p class="footer-legal-line">Faster Breakdown Recovery &middot; <a href="$PHONE_HREF" data-contact="phone-href"><span data-contact="phone-display">$PHONE</span></a> &middot; <a href="#" data-contact="email-href"><span data-contact="email-display">$EMAIL</span></a>. Recovery is arranged with local operators. The price is agreed before anyone sets off. No public depot.</p>
    </div>
  </footer>

  <a class="call-fab" href="$PHONE_HREF" data-contact="phone-href"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg><span>$S->{fab}</span></a>
  <a class="price-badge" href="${R}$HOME{$lang}#quote" aria-label="$S->{badge_alt}"><img src="${R}assets/images/$S->{badge}" width="92" height="92" alt="$S->{badge_alt}" decoding="async"></a>
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
    return join "\n", map { my ($l, $h) = split /\|/; qq{$ind<li><a href="{{R}}$h">$l</a></li>} } split /\s+;\s+/, $spec;
  };
  my $S = $L{$p->{lang}};
  my $qhref = $p->{lang} eq 'en' ? 'contact.html#quote' : "$HOME{$p->{lang}}#quote";
  my $btns = sub {
    my ($cls, $ind) = @_;
    return qq{$ind<a class="btn btn--primary $cls" href="{{PHONE_HREF}}" data-contact="phone-href">$S->{call}</a>\n}
         . qq{$ind<a class="btn btn--whatsapp $cls" href="{{WA_HREF}}" data-contact="whatsapp-href" target="_blank" rel="noopener">$S->{wa}</a>};
  };
  my $eyebrow = $p->{eyebrow} // 'Breakdown recovery';
  my $h1 = $p->{h1} // $p->{label};
  my $body = $p->{body} // ''; $body =~ s/\n+$//;
  my $side = $links->($p->{side_links}, '            ');
  my $side_title = $p->{side_title} // $S->{side};
  my $cta = $p->{cta_title} // $S->{cta};
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
          <a class="btn btn--outline btn--block" href="{{R}}$qhref">$S->{quote}</a>
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
    my $faq_title = $p->{faq_title} // $S->{faq};
    $m .= <<"M";

    <section class="section section--alt">
      <div class="container">
        <div class="section-head section-head--center">
          <span class="eyebrow">$S->{q}</span>
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
          <span class="eyebrow">$S->{related}</span>
          <h2>@{[ $p->{related_title} // $S->{related_title} ]}</h2>
        </div>
        <ul class="related-services">
$rel
        </ul>
      </div>
    </section>
M
  }
  if ($p->{quote_form}) {
    $m .= <<"M";

    <section class="section" id="quote">
      <div class="container contact-grid">
        <div class="contact-card">
          <h2>$p->{quote_form}</h2>
          <p>$S->{cta_text}</p>
          <div class="hero__actions">
@{[ $btns->('btn--lg', '            ') ]}
          </div>
        </div>
{{QUOTE_FORM}}
      </div>
    </section>
M
  }
  $m .= <<"M";

    <section class="cta-band section">
      <div class="container">
        <h2>$cta</h2>
        <p>@{[ $p->{cta_text} // $S->{cta_text} ]}</p>
        <div class="cta-band__actions">
@{[ $btns->('btn--lg', '          ') ]}
          <a class="btn btn--outline btn--lg" href="{{R}}$qhref">$S->{getquote}</a>
        </div>
      </div>
    </section>
M
  $p->{main} = $m;
}

# quote request form, sent by email through formsubmit.co (same service as
# takeldienstfaster.be); the first submission triggers an activation email
sub quote_form {
  my $lang = shift // 'en';
  my @f = @{ $FORM{$lang} };
  my $form = <<"Q";
        <form class="contact-form" action="https://formsubmit.co/$FORM_TO" method="POST">
          <input type="hidden" name="_subject" value="New recovery request via fasterbreakdownrecovery.co.uk (@{[ uc $lang ]})">
          <input type="hidden" name="_template" value="table">
          <input type="hidden" name="_captcha" value="true">
          <input type="hidden" name="_next" value="$BASE/thank-you.html">
          <input type="text" name="_honey" style="display:none" tabindex="-1" autocomplete="off">
          <div class="form-row">
            <div class="form-field">
              <label for="q-name">$f[0]</label>
              <input type="text" id="q-name" name="Name" required autocomplete="name">
            </div>
            <div class="form-field">
              <label for="q-phone">$f[1]</label>
              <input type="tel" id="q-phone" name="Phone" required autocomplete="tel">
            </div>
          </div>
          <div class="form-row">
            <div class="form-field">
              <label for="q-email">$f[2]</label>
              <input type="email" id="q-email" name="Email" autocomplete="email">
            </div>
            <div class="form-field">
              <label for="q-vehicle">$f[3]</label>
              <input type="text" id="q-vehicle" name="Vehicle">
            </div>
          </div>
          <div class="form-field">
            <label for="q-from">$f[4]</label>
            <input type="text" id="q-from" name="Vehicle location" required>
          </div>
          <div class="form-field">
            <label for="q-to">$f[5]</label>
            <input type="text" id="q-to" name="Destination">
          </div>
          <div class="form-field">
            <label for="q-details">$f[6]</label>
            <textarea id="q-details" name="Details" rows="4" required></textarea>
          </div>
          <button class="btn btn--primary btn--block" type="submit">$f[7]</button>
          <p class="form-note">$f[8]</p>
        </form>
Q
  return $form;
}

# TowingService structured data for city / road pages
sub schema_local {
  my ($p, $canon) = @_;
  my $area = ld($p->{schema_area});
  $area .= ' motorway' if ($p->{kind} // '') eq 'route' && $area =~ /^M\d+$/;
  return qq{\n  <script type="application/ld+json">\n  {\n    "\@context": "https://schema.org",\n    "\@type": "TowingService",\n    "name": "$NAME",\n    "url": "$canon",\n    "telephone": "+442080580013",\n    "priceRange": "From £125",\n    "image": "$BASE/assets/images/og/og-faster-breakdown-recovery-1200x630.jpg",\n    "openingHours": "Mo-Su 00:00-23:59",\n    "areaServed": { "\@type": "Place", "name": "$area" },\n    "address": { "\@type": "PostalAddress", "addressCountry": "GB" }\n  }\n  </script>};
}

# "Nearby areas & roads" block for English city and road pages:
#   city  -> other cities in the same region (or nation) + roads that mention it
#   road  -> cities it mentions + a few other roads in the same group
sub add_nearby {
  my ($p, $main, $R) = @_;
  my $text = join ' ', map { $_ // '' } @{$p}{qw(card lede body main)};
  my @en = grep { $_->{lang} eq 'en' && $_->{path} ne $p->{path} && ($_->{robots} // '') !~ /noindex/ } values %P;
  my @areas  = sort { $a->{label} cmp $b->{label} } grep { ($_->{kind} // '') eq 'area' } @en;
  my @routes = sort { ($a->{sort} // $a->{label}) cmp ($b->{sort} // $b->{label}) } grep { ($_->{kind} // '') eq 'route' } @en;
  my $mentions = sub { my ($hay, $name) = @_; $hay =~ /\b\Q$name\E\b/ };
  my (@a, @r);
  if ($p->{kind} eq 'area') {
    my ($nation) = split /\s*>\s*/, $p->{region} // '';
    @a = grep { ($_->{region} // '') eq ($p->{region} // '') } @areas;
    # geographic neighbours for the big cities
    my %near = (
      London => [qw(Southampton Coventry Birmingham Bristol)],
      Birmingham => [qw(Coventry Leicester Nottingham Manchester)],
      Manchester => [qw(Liverpool Leeds Bradford Sheffield)],
      Leeds => [qw(Bradford Sheffield Hull Manchester)],
      Liverpool => [qw(Manchester Leeds Birmingham)],
      Bristol => [qw(Cardiff Plymouth Southampton Birmingham)],
      Glasgow => [qw(Edinburgh Aberdeen Belfast)],
      Edinburgh => [qw(Glasgow Aberdeen Newcastle)],
      Cardiff => [qw(Bristol Plymouth Birmingham)],
      Aberdeen => [qw(Edinburgh Glasgow)],
      Belfast => [qw(Glasgow Liverpool Edinburgh)],
      Newcastle => [qw(Leeds Edinburgh Hull)],
      Sheffield => [qw(Leeds Nottingham Manchester Bradford)],
      Nottingham => [qw(Leicester Sheffield Birmingham Coventry)],
      Leicester => [qw(Nottingham Coventry Birmingham)],
      Southampton => [qw(London Bristol Plymouth)],
      Coventry => [qw(Birmingham Leicester Nottingham)],
      Bradford => [qw(Leeds Manchester Sheffield)],
      Hull => [qw(Leeds Sheffield Newcastle)],
      Plymouth => [qw(Bristol Cardiff Southampton)],
    );
    my %by_label = map { $_->{label} => $_ } @areas;
    for my $n (@{ $near{$p->{label}} // [] }) { push @a, $by_label{$n} if $by_label{$n} && !grep { $_ == $by_label{$n} } @a }
    # still too few: add major cities, same nation first
    my %major = map { $_ => 1 } qw(London Birmingham Manchester Leeds Liverpool Bristol Glasgow Edinburgh Cardiff Aberdeen Belfast Newcastle Sheffield Nottingham Leicester Southampton Coventry Bradford Hull Plymouth);
    my @maj = grep { $major{$_->{label}} } @areas;
    my $add = sub { for my $x (@_) { push @a, $x unless grep { $_ == $x } @a } };
    $add->(grep { (split /\s*>\s*/, $_->{region} // '')[0] eq $nation } @maj) if @a < 3;
    $add->(@maj) if @a < 3;
    @r = grep { $mentions->(join(' ', map { $_ // '' } @{$_}{qw(card lede body main)}), $p->{label}) } @routes;
  } else {
    @a = grep { $mentions->($text, $_->{label}) } @areas;
    @r = grep { ($_->{region} // '') eq ($p->{region} // '') } @routes;
  }
  splice(@a, 8) if @a > 8;
  splice(@r, 6) if @r > 6;
  return $main unless @a || @r;
  my $links = join "\n", (map { qq{          <a href="$R$_->{path}">$_->{label}</a>} } @a),
                         (map { my $s = $_->{short} // $_->{label}; qq{          <a href="$R$_->{path}">$s</a>} } @r);
  my $block = <<"N";
    <section class="section section--alt nearby">
      <div class="container">
        <div class="section-head">
          <span class="eyebrow">Nearby</span>
          <h2>Nearby areas &amp; roads</h2>
        </div>
        <nav class="city-grid" aria-label="Nearby areas and roads">
$links
        </nav>
      </div>
    </section>

N
  $main =~ s/(    <section class="cta-band)/$block$1/ or $main .= "\n$block";
  return $main;
}

# grouped list of every page of one kind, by region
sub index_list {
  my ($kind, $R) = @_;
  my %g;
  for my $p (values %P) {
    next unless ($p->{kind} // '') eq $kind;
    next if ($p->{robots} // '') =~ /noindex/;
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
