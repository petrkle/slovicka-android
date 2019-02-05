#!/usr/bin/perl

use strict;
use warnings;

no warnings 'redefine';

use utf8;
use open ':std', ':encoding(UTF-8)';
use Template;
use File::Slurper 'read_lines';
use File::Basename qw(dirname fileparse);
use File::Copy;
use Cwd;
use TeX::Hyphen;

sub TeX::Hyphen::visualize {
        my ($self, $word, $separator) = (shift, shift, shift);
        my $number = 0;
        my $pos;

        for $pos ($self->hyphenate($word)) {
                substr($word, $pos + $number, 0) = $separator;
                $number = $number + length($separator);;
        }
        return $word;
}


my $IN = 'src';
my $appname = 'Anglická slovíčka';
my $appshortname = 'Slovíčka';
my $appdesc = 'Základní anglická slovíčka';

my $VERSION = `TERM=xterm-color gradle -q printVersionName 2>/dev/null`;

my $OUT = 'app/src/main/assets/www';

my @content = read_lines('3000.txt');

my $hypcz = new TeX::Hyphen 'file' => 'czhyph.tex',
        'style' => 'czech', leftmin => 2,
        rightmin => 2;

my $hypen = new TeX::Hyphen 'file' => 'ukhyphen.tex',
        'style' => 'czech', leftmin => 2,
        rightmin => 2;

my %abeceda;
my %pridat;
my %slovicka;

my $wbr = '&shy;';

foreach my $line (@content){
	my ($en, $cz) = split /:/, $line;
	my $fl = lc($en);
	$fl =~ s/^(.).*/$1/;
	if($abeceda{$fl}){
		$abeceda{$fl}++;
	}else{
		$abeceda{$fl} = 1;
	}
	$slovicka{$fl}{$hypen->visualize($en, $wbr)} = $hypcz->visualize($cz, $wbr);
	my $zbytek = $abeceda{$fl} % 6;
}

for my $pismeno (sort keys %abeceda) {
	my $zbytek = $abeceda{$pismeno} % 6;
	$pridat{$pismeno} = 6 - $zbytek;
}

my $t = Template->new({
		INCLUDE_PATH => $IN,
		ENCODING => 'utf8',
		VARIABLES => {
		 version => $VERSION,
		 appname => $appname,
		 appshortname => $appshortname,
		 appdesc => $appdesc,
   },
});

for my $pismeno (sort keys %slovicka) {
	$t->process('pismeno.html',
		{ 
			'title' => $appname . ' - '. uc $pismeno,
			'slovicka' => $slovicka{$pismeno},
			'pismeno' => $pismeno,
			'pridat' => \%pridat,
		},
		"$OUT/$pismeno.html",
		{ binmode => ':utf8' }) or die $t->error;
}

$t->process('index.html',
	{ 
		'title' => $appname,
		'abeceda' => \%abeceda,
		'aboutlink' => 1,
	},
	"$OUT/index.html",
	{ binmode => ':utf8' }) or die $t->error;

$t->process('about.html',
	{ 
		'title' => $appname,
	},
	"$OUT/about.html",
	{ binmode => ':utf8' }) or die $t->error;

my @files = (
	'slovicka.css',
	'slovicka.js',
);

for my $file (@files){
	$t->process($file ,{
		'abeceda' => \%abeceda,
	},
	"$OUT/$file",
		{ binmode => ':utf8' }) or die $t->error;
}

foreach my $file (glob("$IN/img/*")){
	my ($name,$path) = fileparse($file);
	copy("$path$name", "$OUT/$name");
}
