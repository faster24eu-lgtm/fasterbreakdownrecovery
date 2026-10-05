#!/usr/bin/perl
# One-time importer: turns the hand-written HTML pages into _build/pages/*.page
# source files (meta + extra head + <main> body). After this, edit the .page
# files and run build.pl; never edit the generated HTML directly.
use strict;
use warnings;
use File::Find;
use File::Path qw(make_path);
use File::Basename qw(dirname);

my $root = dirname(dirname(__FILE__));
chdir $root or die;
my @files;
find(sub { push @files, $File::Find::name if /\.html$/ }, '.');
@files = grep { !m{^\./(_build|\.git|\.claude)/} } @files;

for my $f (sort @files) {
  (my $path = $f) =~ s{^\./}{};
  open my $fh, '<:raw', $f or die "$f: $!";
  local $/; my $h = <$fh>; close $fh;
  $h =~ s/\r\n/\n/g;

  my %m;
  ($m{title}) = $h =~ m{<title>(.*?)</title>}s;
  ($m{description}) = $h =~ m{<meta name="description" content="(.*?)">}s;
  ($m{og_title}) = $h =~ m{<meta property="og:title" content="(.*?)">}s;
  ($m{og_description}) = $h =~ m{<meta property="og:description" content="(.*?)">}s;
  ($m{robots}) = $h =~ m{<meta name="robots" content="(.*?)">}s;

  # breadcrumbs: every <li> before the aria-current one
  my @crumbs;
  if ($h =~ m{<nav class="breadcrumbs".*?<ol>(.*?)</ol>}s) {
    my $ol = $1;
    while ($ol =~ m{<li><a href="([^"]+)">(.*?)</a></li>}g) {
      my ($href, $label) = ($1, $2);
      next if $label eq 'Home';
      push @crumbs, "$label|" . resolve($path, $href);
    }
    ($m{label}) = $ol =~ m{<li aria-current="page">(.*?)</li>}s;
  }
  $m{crumbs} = @crumbs ? join(' > ', @crumbs) : ($path eq 'index.html' || $path eq '404.html' ? 'none' : '');

  # extra head: every ld+json block except BreadcrumbList
  my @head;
  while ($h =~ m{(  <script type="application/ld\+json">.*?</script>)}sg) {
    my $b = $1;
    next if $b =~ /"BreadcrumbList"/;
    push @head, $b;
  }

  my ($main) = $h =~ m{<main id="main">\n?(.*?)\n?\s*</main>}s;
  die "no main in $path" unless defined $main;

  my $nav = $path =~ m{^(services|areas|routes|guides)/} ? $1
          : $path =~ m{^(about|contact)\.html$} ? $1
          : $path eq 'index.html' ? 'home' : '';

  my $out = "_build/pages/$path";
  $out =~ s/\.html$/.page/;
  make_path(dirname($out));
  open my $o, '>:raw', $out or die;
  for my $k (qw(title description og_title og_description label crumbs robots)) {
    next unless defined $m{$k} && length $m{$k};
    print $o "$k: $m{$k}\n";
  }
  print $o "nav: $nav\n" if $nav;
  print $o "sitemap: no\n" if ($m{robots} // '') =~ /noindex/;
  print $o "===HEAD===\n", join("\n", @head), "\n" if @head;
  print $o "===MAIN===\n$main\n";
  close $o;
  print "imported $path\n";
}

# make an href found in $page relative to the site root
sub resolve {
  my ($page, $href) = @_;
  my @dir = split m{/}, $page; pop @dir;
  for my $seg (split m{/}, $href, -1) {
    if ($seg eq '..') { pop @dir } elsif ($seg ne '.') { push @dir, $seg }
  }
  my $r = join '/', @dir;
  $r .= 'index.html' if $r eq '' || $r =~ m{/$};
  return $r;
}
