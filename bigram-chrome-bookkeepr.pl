#!/opt/pkg/bin/perl -w -T

use strict;
use JSON;

my $modelfilehandle;
my $modeljsonstring;
my $modeljsonobject;
my $bookmarksfilehandle;
my $bookmarksjsonstring;
my $bookmarksjsonobject;
my $rootfolder;

sub parsesubfolder {
	my $reponame;
	my $subfolderlist;
	my $modeljsonobject;
	my $subfolder;
	$reponame = shift;
	$subfolderlist = shift;
	$modeljsonobject = shift;
	if ($subfolderlist->{"url"}) {
		parseentry($reponame, $subfolderlist, $modeljsonobject);
	} else {
		foreach $subfolder (@{$subfolderlist->{'children'}}) {
			parsesubfolder($reponame, $subfolder, $modeljsonobject);
		}
	}
}

sub parseentry {
	my $reponame;
	my $entryobject;
	my $modeljsonobject;
	my @entrytaglist;
	my %newentryobject;
	my $sanitizedtitle;
	my $filehandle;
	my $entrytag;
	$reponame = shift;
	$entryobject = shift;
	$modeljsonobject = shift;
	@entrytaglist = classifytitle($entryobject->{"name"}, $modeljsonobject);
	if (! -d $ENV{'HOME'} . "/.bookkeepr/bookmarks") {
		mkdir($ENV{'HOME'} . "/.bookkeepr/bookmarks");
	}
	if (! -d $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame) {
		mkdir($ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame);
	}
	%newentryobject = ();
	if ($entryobject->{'name'} ne "") {
		$newentryobject{'name'} = $entryobject->{'name'};
	} else {
		$newentryobject{'name'} = $entryobject->{'url'};
	}
	$newentryobject{'url'} = $entryobject->{'url'};
	$newentryobject{'tags'} = join(", ", @entrytaglist);
	$sanitizedtitle = $newentryobject{'name'};
	$sanitizedtitle =~ s/[\-\+\.\?\\\(\)\[\]\{\}\|\/\$`"':;,!# ]/_/g;
	$sanitizedtitle = substr($sanitizedtitle, 0, 250);
	if (-f $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . $sanitizedtitle) {
		print "W: " . $sanitizedtitle . " is a duplicate\n";
	} else {
		open($filehandle, ">" . $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . $sanitizedtitle);
		print $filehandle to_json(\%newentryobject, {utf8 => 1, pretty => 1});
		close($filehandle);
		foreach $entrytag (@entrytaglist) {
			if (! -d $ENV{'HOME'} . "/.bookkeepr/" . $entrytag) {
				mkdir($ENV{'HOME'} . "/.bookkeepr/" . $entrytag);
			}
			symlink($ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . $sanitizedtitle, $ENV{'HOME'} . "/.bookkeepr/" . $entrytag . "/" . $sanitizedtitle);
		}
	}
}

sub classifytitle {
	my $entrytitle;
	my $modeljsonobject;
	my %similartaglist;
	my $sanitizedtitle;
	my $modeltag;
	my @wordlist;
	my $wordcounter;
	my @toptaglist;
	my $taggedcounter;
	my $similartag;
	$entrytitle = shift;
	$modeljsonobject = shift;
	%similartaglist = ();
	$sanitizedtitle = $entrytitle;
	$sanitizedtitle =~ s/[\-\+\.\?\\\(\)\[\]\{\}\|\/\$`"':;,!#]/ /g;
	$sanitizedtitle = lc($sanitizedtitle);
	foreach $modeltag (keys %{$modeljsonobject->{'tags'}}) {
		@wordlist = split(/ /, $sanitizedtitle);
		for ($wordcounter = 0; $wordcounter < @wordlist - 1; $wordcounter ++) {
			if (defined($modeljsonobject->{'tags'}->{$modeltag}->{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]})) {
				$similartaglist{$modeltag} += ($modeljsonobject->{'tags'}->{$modeltag}->{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]}->{'score'} / $modeljsonobject->{'tags'}->{$modeltag}->{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]}->{'weight'});
			}
		}
	}
	@toptaglist = ();
	$taggedcounter = 0;
	foreach $similartag (sort { $similartaglist{$b} <=> $similartaglist{$a} } keys %similartaglist) {
		if ($similartaglist{$similartag} >= 0.3) {
			push(@toptaglist, $similartag);
			$taggedcounter ++;
		}
	}
	if ($taggedcounter == 0) {
		push(@toptaglist, "untagged");
	}
	return @toptaglist;
}

if (! -d $ENV{'HOME'} . "/.bookkeepr") {
	mkdir($ENV{'HOME'} . "/.bookkeepr");
}
if (-f $ENV{'HOME'} . "/.bookkeepr/model.json") {
	open($modelfilehandle, "<" . $ENV{'HOME'} . "/.bookkeepr/model.json");
	$modeljsonstring = "";
	while (<$modelfilehandle>) {
		$modeljsonstring .= $_;
	}
	close($modelfilehandle);
	$modeljsonobject = decode_json($modeljsonstring);
}
if (defined($ARGV[0])) {
	if (-f $ARGV[0]) {
		open($bookmarksfilehandle, "<" . $ARGV[0]);
		$bookmarksjsonstring = "";
		while (<$bookmarksfilehandle>) {
			$bookmarksjsonstring .= $_;
		}
		close($bookmarksfilehandle);
		$bookmarksjsonobject = decode_json($bookmarksjsonstring);
		foreach $rootfolder (keys %{$bookmarksjsonobject->{'roots'}}) {
			parsesubfolder($ARGV[1], $bookmarksjsonobject->{'roots'}->{$rootfolder}, $modeljsonobject);
		}
	}
}
