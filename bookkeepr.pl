#!/opt/pkg/bin/perl -w -T

use strict;
use JSON;
use File::Basename;

my $modeljsonobject;
my $modelfilehandle;
my $modeljsonstring;

sub usage {
	die "usage: " . basename($0) . " init <reponame>|subscribe <repourl> <reponame>|sync|<add|edit|tag|list|search> <reponame> [<..>]";
}

sub init {
	my $reponame;
	$reponame = shift;
	$reponame = validatereponame($reponame);
	mkdir($ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame);
	system("git", "init", $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame);
}

sub subscribe {
	my $repourl;
	my $reponame;
	$repourl = shift;
	$reponame = shift;
	$repourl = validaterepourl($repourl);
	$reponame = validatereponame($reponame);
	mkdir($ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame);
	system("git", "clone", $repourl, $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame);
}

sub sync {
	my $directorypath;
	for $directorypath (glob($ENV{'HOME'} . "/.bookkeepr/bookmarks/*")) {
		$directorypath = validatereponame($directorypath);
		system("git", "pull", $directorypath);
		system("git", "push", $directorypath);
	}
}

sub add {
	my $reponame;
	my $url;
	my $entryname;
	my $filename;
	my %jsonobject;
	my @entrytaglist;
	my $filehandle;
	my $taglist;
	$reponame = shift;
	$url = shift;
	$reponame = validatereponame($reponame);
	$url = validateurl($url);
	$entryname = $url;
	$filename = sanitizefilename($entryname);
	$filename = $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . $filename;
	if (-f $filename) {
		die "E: did you mean edit";
	} else {
		$jsonobject{'url'} = $url;
		@entrytaglist = classifyname($entryname, $modeljsonobject);
		$jsonobject{'name'} = $entryname;
		$jsonobject{'tags'} = join(", ", @entrytaglist);
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
	$filename = validatefilename($filename);
	if (! -f $filename) {
		die "E: did you mean add";
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

sub validaterepourl {
	my $repourl;
	$repourl = shift;
	if ($repourl =~ /(git@|http[s]*:\/\/)([A-Za-z0-9\-_\.:\/]+)/) {
		$repourl = $1 . $2;
	} else {
		die "E: invalid repo URL";
	}
	return $repourl;
}

sub validatereponame {
	my $reponame;
	$reponame = shift;
	if ($reponame =~ /([A-Za-z0-9\-_\.]+)/) {
		$reponame = $1;
	} else {
		die "E: invalid repo name";
	}
	return $reponame;
}

sub validateurl {
	my $url;
	$url = shift;
	if ($url =~ /(.*)/) {
		$url = $1;
	} else {
		die "E: invalid URL";
	}
	return $url;
}

sub validatefilename {
	my $filename;
	$filename = shift;
	if ($filename =~ /([\/A-Za-z0-9\-_\.]+)/) {
		$filename = $1;
	} else {
		die "E: invalid filename";
	}
	return $filename;
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
	my $modeltag;
	my @wordlist;
	my $wordcounter;
	my %similartaglist;
	my $taggedcounter;
	my $similartag;
	my @toptaglist;
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
	my $entryname;
	my $reponame;
	my $newfilename;
	$filename = shift;
	$filename = validatefilename($filename);
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
		$reponame = basename(dirname($filename));
		$newfilename = sanitizefilename($jsonobject->{'name'});
		rename($filename, $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . $newfilename);
		$filename = $ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . $newfilename;
	}
	return $jsonobject->{'tags'};
}

sub tag {
	my $taglist;
	my $filename;
	my $reponame;
	my $taggedcounter;
	my $entrytag;
	$taglist = shift;
	$filename = shift;
	$filename = validatefilename($filename);
	$reponame = basename(dirname($filename));
	$taggedcounter = 0;
	foreach $entrytag (split(/, /, $taglist)) {
		if ($entrytag =~ /([A-Za-z0-9\-_\.]+)/) {
			$entrytag = $1;
			if (! -d $ENV{'HOME'} . "/.bookkeepr/" . $entrytag) {
				mkdir($ENV{'HOME'} . "/.bookkeepr/" . $entrytag);
			}
			symlink($ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . basename($filename), $ENV{'HOME'} . "/.bookkeepr/" . $entrytag . "/" . basename($filename));
			$taggedcounter ++;
		} else {
			print "W: invalid tag\n";
		}
	}
	if ($taggedcounter == 0) {
		symlink($ENV{'HOME'} . "/.bookkeepr/bookmarks/" . $reponame . "/" . basename($filename), $ENV{'HOME'} . "/.bookkeepr/untagged/" . basename($filename));
	}
}

sub untag {
	my $taglist;
	my $filename;
	my $taggedcounter;
	my $entrytag;
	$taglist = shift;
	$filename = shift;
	$filename = validatefilename($filename);
	$taggedcounter = 0;
	foreach $entrytag (split(/, /, $taglist)) {
		if ($entrytag =~ /([A-Za-z0-9\-_\.]+)/) {
			$entrytag = $1;
			unlink($ENV{'HOME'} . "/.bookkeepr/" . $entrytag . "/" . basename($filename));
			$taggedcounter ++;
		} else {
			print "W: invalid tag\n";
		}
	}
	if ($taggedcounter == 0) {
		unlink($ENV{'HOME'} . "/.bookkeepr/untagged/" . basename($filename));
	}
}

if ($ENV{'HOME'} =~ /(.*)/) {
	$ENV{'HOME'} = $1;
}
if ($ENV{'PATH'} =~ /(.*)/) {
	$ENV{'PATH'} = $1;
}
if (! -d $ENV{'HOME'} . "/.bookkeepr") {
	mkdir($ENV{'HOME'} . "/.bookkeepr");
}
if (! -d $ENV{'HOME'} . "/.bookkeepr/bookmarks") {
	mkdir($ENV{'HOME'} . "/.bookkeepr/bookmarks");
}
if (@ARGV < 1) {
	usage();
}
if ($ARGV[0] eq "init") {
	if (defined($ARGV[1])) {
		init($ARGV[1]);
	} else {
		die "E: no reponame specified";
	}
} else {
	if ($ARGV[0] eq "subscribe") {
		if (defined($ARGV[1]) && defined($ARGV[2])) {
			subscribe($ARGV[1], $ARGV[2]);
		} else {
			die "E: no repo URL or repo name specified";
		}
	} else {
		if ($ARGV[0] eq "sync") {
			sync();
		} else {
			if (-f $ENV{'HOME'} . "/.bookkeepr/model.json") {
				open($modelfilehandle, "<" . $ENV{'HOME'} . "/.bookkeepr/model.json");
				$modeljsonstring = "";
				while (<$modelfilehandle>) {
					$modeljsonstring .= $_;
				}
				close($modelfilehandle);
				$modeljsonobject = decode_json($modeljsonstring);
			}
			if ($ARGV[0] eq "add") {
				if (defined($ARGV[1]) && defined($ARGV[2])) {
					add($ARGV[1], $ARGV[2]);
				} else {
					die "E: no repo name or URL specified";
				}
			} else {
				if ($ARGV[0] eq "edit") {
					if (defined($ARGV[1])) {
						edit($ARGV[1])
					}
				} else {
					if ($ARGV[0] eq "tag") {
					} else {
						if ($ARGV[0] eq "list") {
						} else {
							if ($ARGV[0] eq "search") {
							} else {
								usage();
							}
						}
					}
				}
			}
		}
	}
}
