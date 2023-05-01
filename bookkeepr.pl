#!/usr/bin/perl -w

use strict;
use JSON;
use File::Basename;

my $modelfilehandle;
my $modeljsonstring;
my $modeljsonobject;

sub usage {
	die "usage: " . basename($0) . " <add|edit|tag|list|search> [<..>]";
}

sub add {
	my $url;
	my $entryname;
	my @entrytaglist;
	my $filename;
	my %jsonobject;
	my $filehandle;
	my $taglist;
	$url = shift;
	$entryname = $url;
	$filename = sanitizefilename($entryname);
	$filename = $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $filename;
	if (-f $filename) {
		print "E: did you mean edit\n";
	} else {
		$jsonobject{'url'} = $url;
		@entrytaglist = classifyname($entryname, $modeljsonobject);
		$jsonobject{'name'} = $entryname;
		$jsonobject{'tags'} = join(", ", @entrytaglist);;
		open($filehandle, ">" . $filename);
		print $filehandle to_json(\%jsonobject, {utf8 => 1, pretty => 1});
		close($filehandle);
	}
	$taglist = textedit($filename);
	tag($taglist, $filename);
}

sub edit {
	my $filename;
	my $filehandle;
	my $jsonstring;
	my $jsonobject;
	my $taglist;
	$filename = shift;
	if (! -f $filename) {
		print "E: did you mean add\n";
	}
	open($filehandle, "<" . $filename);
	$jsonstring = "";
	while (<$filehandle>) {
		$jsonstring .= $_;
	}
	close($filehandle);
	$jsonobject = decode_json($jsonstring);
	untag($jsonobject->{'tags'}, $filename);
	$taglist = textedit($filename);
	tag($taglist, $filename);
}

sub sanitizefilename {
	my $filename;
	$filename = shift;
	$filename =~ s/[\-\+\.\?\\\(\)\[\]\{\}\|\/\$`"':;,!# ]/_/g;
	$filename = substr($filename, 0, 250);
	return $filename;
}

sub sanitizename {
	my $entryname;
	$entryname = shift;
	$entryname = $entryname;
	$entryname =~ s/[\-\+\.\?\\\(\)\[\]\{\}\|\/\$`"':;,!#]/ /g;
	$entryname = lc($entryname);
	return $entryname;
}

sub classifyname {
	my $entryname;
	my $modeljsonobject;
	my %similartaglist;
	my $modeltag;
	my @wordlist;
	my $wordcounter;
	my @toptaglist;
	my $taggedcounter;
	my $similartag;
	$entryname = shift;
	$modeljsonobject = shift;
	$entryname = sanitizename($entryname);
	foreach $modeltag (keys %{$modeljsonobject->{'tags'}}) {
		@wordlist = split(/ /, $entryname);
		for ($wordcounter = 0; $wordcounter < @wordlist - 1; $wordcounter ++) {
			if (defined($modeljsonobject->{'tags'}->{$modeltag}->{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]})) {
				$similartaglist{$modeltag} += ($modeljsonobject->{'tags'}->{$modeltag}->{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]}->{'score'} / $modeljsonobject->{'tags'}->{$modeltag}->{$wordlist[$wordcounter] . " " . $wordlist[$wordcounter + 1]}->{'weight'});
			}
		}
	}
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

sub textedit {
	my $filename;
	my $filehandle;
	my $jsonstring;
	my $jsonobject;
	my $newfilename;
	my $entryname;
	my $taggedcounter;
	$filename = shift;
	open($filehandle, "<" . $filename);
	$jsonstring = "";
	while (<$filehandle>) {
		$jsonstring .= $_;
	}
	close($filehandle);
	$jsonobject = decode_json($jsonstring);
	$entryname = $jsonobject->{'name'};
	if (defined($ENV{'EDITOR'})) {
		system($ENV{'EDITOR'} . " " . $filename);
	} else {
		system("vi " . $filename);
	}
	open($filehandle, "<" . $filename);
	$jsonstring = "";
	while (<$filehandle>) {
		$jsonstring .= $_;
	}
	close($filehandle);
	$jsonobject = decode_json($jsonstring);
	if ($jsonobject->{'name'} ne $entryname) {
		$newfilename = sanitizefilename($jsonobject->{'name'});
		rename($filename, $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $newfilename);
		$filename = $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $newfilename;
	}
	return $jsonobject->{'tags'};
}

sub tag {
	my $taglist;
	my $filename;
	my $taggedcounter;
	my $entrytag;
	$taglist = shift;
	$filename = shift;
	$taggedcounter = 0;
	foreach $entrytag (split(/, /, $taglist)) {
		if (! -d $ENV{'HOME'} . "/.bookkeepr/" . $entrytag) {
			mkdir($ENV{'HOME'} . "/.bookkeepr/" . $entrytag);
		}
		symlink($ENV{'HOME'} . $filename, $ENV{'HOME'} . "/.bookkeepr/" . $entrytag . "/" . basename($filename));
		$taggedcounter ++;
	}
	if ($taggedcounter == 0) {
		symlink($filename, $ENV{'HOME'} . "/.bookkeepr/untagged/" . basename($filename));
	}
}

sub untag {
	my $taglist;
	my $filename;
	my $taggedcounter;
	my $entrytag;
	$taglist = shift;
	$filename = shift;
	$taggedcounter = 0;
	foreach $entrytag (split(/, /, $taglist)) {
		unlink($ENV{'HOME'} . "/.bookkeepr/" . $entrytag . "/" . basename($filename));
		$taggedcounter ++;
	}
	if ($taggedcounter == 0) {
		unink($ENV{'HOME'} . "/.bookkeepr/untagged/" . basename($filename));
	}
}

if (@ARGV < 2) {
	usage();
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
if (! -d $ENV{'HOME'} . "/.bookkeepr/bookmarks") {
	mkdir($ENV{'HOME'} . "/.bookkeepr/bookmarks");
}
if ($ARGV[0] eq "add") {
	if (defined($ARGV[1])) {
		add($ARGV[1]);
	} else {
		print "E: no URL specified\n";
	}
} else {
	if ($ARGV[0] eq "edit") {
		if (defined($ARGV[1])) {
			edit($ARGV[1]);
		}
	} else {
		if ($ARGV[0] eq "tag") {
		} else {
			if ($ARGV[0] eq "list") {
			} else {
				if ($ARGV[0] eq "search") {
				}
			}
		}
	}
}
