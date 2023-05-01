#!/opt/pkg/bin/perl -w -T

use strict;
use JSON;

my $filehandle;
my $jsonstring;
my $jsonobject;
my $entry;
my $entrytag;
my $sanitizedtag;
my $sanitizedtitle;
my $sanitizeddescription;
my @wordlist;
my $wordcounter;
my %model;
my %weightings;
my $modeltag;
my $bigram;

if (! -d $ENV{'HOME'} . "/.bookkeepr" ) {
	mkdir($ENV{'HOME'} . "/.bookkeepr");
}
if (defined($ARGV[0])) {
	if (-f $ARGV[0]) {
		open($filehandle, "<" . $ARGV[0]);
		$jsonstring = "";
		while (<$filehandle>) {
			$jsonstring .= $_;
		}
		close($filehandle);
		$jsonobject = decode_json($jsonstring);
		foreach $entry (@{$jsonobject}) {
			foreach $entrytag (@{$entry->{'tags'}}) {
				$sanitizedtag = $entrytag;
				$sanitizedtag =~ s/[\/ ]//g;
				if ($sanitizedtag ne "") {
					$sanitizedtitle = $entry->{'title'};
					$sanitizedtitle =~ s/[\-\+\.\?\\\(\)\[\]\{\}\|\/\$`"':;,!#]/ /g;
					$sanitizedtitle = lc($sanitizedtitle);
					$sanitizeddescription = $entry->{'description'};
					$sanitizeddescription =~ s/[\-\+\.\?\\\(\)\[\]\{\}\|\/\$`"':;,!#]/ /g;
					$sanitizeddescription = lc($sanitizeddescription);
					@wordlist = split(/ /, $sanitizedtitle);
					for ($wordcounter = 0; $wordcounter < @wordlist - 1; $wordcounter ++) {
						$model{'tags'}{$sanitizedtag}{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]}{'score'} += 1;
						$weightings{$wordlist[$wordcounter] . " " .  $wordlist[$wordcounter + 1]} += 1;
					}
					@wordlist = split(/ /, $sanitizeddescription);
					for ($wordcounter = 0; $wordcounter < @wordlist - 1; $wordcounter ++) {
						$model{'tags'}{$sanitizedtag}{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]}{'score'} += 1;
						$weightings{$wordlist[$wordcounter] . " " .  $wordlist[$wordcounter + 1]} += 1;
					}
				}
			}
		}
		foreach $modeltag (keys %{$model{'tags'}}) {
			foreach $bigram (keys %{$model{'tags'}{$tag}}) {
				$model{'tags'}{$tag}{$bigram}{'weight'} = $weightings{$bigram};
			}
		}
		open($filehandle, ">" . $ENV{'HOME'} . "/.bookkeepr/model.json");
		print $filehandle to_json(\%model, {utf8 => 1, pretty => 1});
		close($filehandle);
	}
}
