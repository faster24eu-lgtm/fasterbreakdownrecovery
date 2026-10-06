#!/usr/bin/perl
# Near-duplicate check for the built site (scaled-content / doorway risk).
#   perl _build/check_similarity.pl [threshold]   (default 0.35)
# Compares the visible <main> text of every page (header, footer, scripts
# and the generated "Nearby" block removed) using 5-word shingles and
# Jaccard similarity, and lists every pair at or above the threshold.
use strict;
use warnings;
use File::Find;
use File::Basename qw(dirname);

my $limit = shift // 0.35;
chdir dirname(dirname(__FILE__)) or die;
my %sh;   # path => { shingle => 1 }
my %words;
find(sub {
  return unless /\.html$/;
  my $f = $File::Find::name; $f =~ s{^\./}{};
  return if $f =~ m{^(_build|\.git)/} || $f =~ m{^(404|thank-you)\.html$} || $f =~ m{^legal/};
  open my $fh, '<:encoding(UTF-8)', $_ or die; local $/; my $h = <$fh>; close $fh;
  return if $h =~ /<meta name="robots" content="noindex/;   # Google ignores these
  my ($m) = $h =~ m{<main id="main">(.*?)</main>}s or return;
  $m =~ s{<section class="section section--alt nearby">.*?</section>}{}s;
  $m =~ s{<section class="cta-band.*?</section>}{}s;
  $m =~ s{<form.*?</form>}{}sg;
  $m =~ s{<aside class="side-panel">.*?</aside>}{}sg;
  $m =~ s/<[^>]+>/ /g; $m =~ s/&[a-z#0-9]+;/ /g;
  my @w = map { lc } $m =~ /(\w+)/g;
  $words{$f} = scalar @w;
  my %s; $s{join ' ', @w[$_ .. $_ + 4]} = 1 for 0 .. $#w - 4;
  $sh{$f} = \%s;
}, '.');

my @p = sort keys %sh;
my @hits;
for my $i (0 .. $#p) {
  for my $j ($i + 1 .. $#p) {
    my ($a, $b) = @sh{$p[$i], $p[$j]};
    my $inter = grep { $b->{$_} } keys %$a;
    my $union = keys(%$a) + keys(%$b) - $inter or next;
    my $jac = $inter / $union;
    push @hits, [$jac, $p[$i], $p[$j]] if $jac >= $limit;
  }
}
printf "%d pages checked, %d pairs >= %.2f\n", scalar @p, scalar @hits, $limit;
printf "  %.2f  %s  <->  %s\n", @$_ for sort { $b->[0] <=> $a->[0] } @hits;
my @thin = grep { $words{$_} < 350 } @p;
print "pages under 350 words of main text: ", (@thin ? join(', ', map { "$_ ($words{$_})" } @thin) : 'none'), "\n";
