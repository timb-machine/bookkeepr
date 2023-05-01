#!/opt/pkg/bin/perl -w -T
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
