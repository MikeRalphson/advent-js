#!/usr/bin/perl -w

use strict;

# Simple Perl script to turn the ADVENT.DAT file into a bunch of JavaScript
# objects.

sub escape_json($) {
	my $str = shift;
	$str =~ s/([\"'])/\\$1/g;
	$str =~ s/\n/\\n/g;
	$str =~ s/\t/\\t/g;
	return $str;
}

open ADVENT, "advent.dat" or die "Unable to open data file.";

my %longdesc;
my %shortdesc;
my %rtext;
my %mtext;
my %actspk;
my %ptext;

my @travel_key;
my @travel;

my %vocab_motion;
my %vocab_object;
my %vocab_action;
my %vocab_special;

my @vocab_sections = ( \%vocab_motion, \%vocab_object, \%vocab_action, \%vocab_special );

my @place;
my @fixed;
my @cond;

my @rank_pts;
my @rank_text;

my @hints;

# This section handles reading which section we're in.
while (my $line = <ADVENT>) {
	# Chop the line since the data file must always be in UNIX format.
	chop $line;
	if ($line eq '1' or $line eq '2' or $line eq '6' or $line eq '12') {
		my $sec = $line;
		# section 1/2, room descriptions, or 6/12, other text
		my $hash;
		if ($line eq '1') {
			$hash = \%longdesc;
		} elsif ($line eq '2') {
			$hash = \%shortdesc;
		} elsif ($line eq '6') {
			$hash = \%rtext;
		} elsif ($line eq '12') {
			$hash = \%mtext;
		} else {
			print STDERR "Bwah?\n";
			exit 2;
		}
		while ($line = <ADVENT>) {
			chop $line;
			if ($line eq '-1') {
				last;
			}
			if ($line =~ /^(-?\d+)\t(.*)$/) {
				if ($1 eq '-1') {
					last;
				}
				if (defined $hash->{$1}) {
					$hash->{$1} .= '\n' . $2;
				} else {
					$hash->{$1} = $2;
				}
			} else {
				print STDERR "Malformed line in section ", $sec, ":\n", $line, "\n";
				exit 1;
			}
		}
	} elsif ($line eq '3') {
		# Section 3, movement table
		# The following is the original code for reading the data:
		#
		# THE STUFF FOR SECTION 3 IS ENCODED HERE.  EACH "FROM-LOCATION" GETS A
		# CONTIGUOUS SECTION OF THE "TRAVEL" ARRAY.  EACH ENTRY IN TRAVEL IS
		# NEWLOC*1000 + KEYWORD (FROM SECTION 4, MOTION VERBS), AND IS NEGATED IF
		# THIS IS THE LAST ENTRY FOR THIS LOCATION.  KEY(N) IS THE INDEX IN TRAVEL
		# OF THE FIRST OPTION AT LOCATION N.
		#
		# 1030	READ(1,1031)LOC,NEWLOC,TK
		# 1031	FORMAT(99G)
		# 	IF(LOC.EQ.0)GOTO 1030
		# C  ABOVE KLUGE IS TO AVOID AFOREMENTIONED F40 BUG
		#	IF(LOC.EQ.-1)GOTO 1002
		#	IF(KEY(LOC).NE.0)GOTO 1033
		#	KEY(LOC)=TRVS
		#	GOTO 1035
		# 1033	TRAVEL(TRVS-1)=-TRAVEL(TRVS-1)
		# 1035	DO 1037 L=1,20
		#	IF(TK(L).EQ.0)GOTO 1039
		#	TRAVEL(TRVS)=NEWLOC*1000+TK(L)
		#	TRVS=TRVS+1
		#	IF(TRVS.EQ.TRVSIZ)CALL BUG(3)
		# 1037	CONTINUE
		# 1039	TRAVEL(TRVS-1)=-TRAVEL(TRVS-1)
		#	GOTO 1030
		#
		# Translated into Perl, that looks something entirely unlike:
		# (TRVS was initialized to 1 before the above code)
		my $trvs = 0;
		while ($line = <ADVENT>) {
			chop $line;
			if ($line eq '-1') {
				last;
			}
			# There's probably a more efficient way to do this, but programmer
			# time is the constraint here :)
			if ($line =~ /^(\d+)\t(\d+)\t(.*)$/) {
				# Movement information for room
				my $loc = $1 - 1;
				my $newloc = $2;
				my $tk = $3;
				if (defined $travel_key[$loc]) {
					$travel[$trvs-1] = -$travel[$trvs-1];
				} else {
					$travel_key[$loc] = $trvs;
				}
				while ($tk =~ /(\d+)/g) {
					$travel[$trvs] = $newloc * 1000 + $1;
					$trvs++;
				}
				$travel[$trvs-1] = -$travel[$trvs-1];
			} else {
				print STDERR "Malformed line in section 3:\n", $line, "\n";
				exit 1;
			}
		}
	} elsif ($line eq '4') {
		# Section 4, vocab
		while ($line = <ADVENT>) {
			chop $line;
			if ($line =~ /^-1\s*$/) {
				last;
			} elsif ($line =~ /^(-?\d+)\t(\S+)/) {
				my $meaning = $1;
				my $section = int($1 / 1000);
				my $word = $2;
				if ($section < 0 || $section > $#vocab_sections) {
					print STDERR "Invalid word meaning ", $meaning, " - out of range 0 - ", $#vocab_sections, "999\n";
					exit 1;
				}
				my $hash = $vocab_sections[$section];
				if (defined $hash->{$word}) {
					print STDERR "Note: Word ", $word, " has multiple meanings in section ", $section, ".\n";
					print STDERR "Ignoring the second definition.\n";
				} else {
					$hash->{$word} = $meaning;
				}
			} else {
				print STDERR "Malformed line in section 4:\n", $line, "\n";
				exit 1;
			}
		}
	} elsif ($line eq '5') {
		# Section 5, item descriptions
		my $last;
		while ($line = <ADVENT>) {
			chop $line;
			if ($line eq '-1') {
				last;
			}
			if ($line =~ /^(-?\d+)\t(.*)$/) {
				if ($1 eq "000" or $1 >= 100) {
					my $i = int($1/100) + 1;
					if (defined $last->[$i]) {
						$last->[$i] .= "\n" . $2;
					} else {
						$last->[$i] = $2;
					}
				} else {
					if (defined $ptext{$1}) {
						$last = $ptext{$1};
					} else {
						$last = [];
						$ptext{$1} = $last;
					}
					if (defined $last->[0]) {
						$last->[0] .= "\n" . $2;
					} else {
						$last->[0] = $2;
					}
				}
			} else {
				print STDERR "Malformed line in section 5:\n", $line, "\n";
				exit 1;
			}
		}
	} elsif ($line eq '7') {
		# Section 7, initial object locations
		while ($line = <ADVENT>) {
			chop $line;
			if ($line eq '-1') {
				last;
			}
			if ($line =~ /^(\d+)\t(\d+)(?:\t(-?\d+))?$/) {
				my $obj = $1 - 1;
				$place[$obj] = $2;
				if (defined $3) {
					$fixed[$obj] = $3;
				}
			} else {
				print STDERR "Malformed line in section 7:\n", $line, "\n";
			}
		}
	} elsif ($line eq '8') {
		while ($line = <ADVENT>) {
			chop $line;
			if ($line eq '-1') {
				last;
			}
			if ($line =~ /^(-?\d+)\t(\d+)$/) {
				if (defined $actspk{$1}) {
					print STDERR "Already have an actspk for action $1\n";
					exit 1;
				}
				$actspk{$1} = $2;
			} else {
				print STDERR "Malformed line in section 8:\n", $line, "\n";
				exit 1;
			}
		}
	} elsif ($line eq '9') {
		# Original Fortran code:
		# 1070	READ(1,1031)K,TK
		#	IF(K.EQ.-1)GOTO 1002
		#	DO 1071 I=1,20
		#	LOC=TK(I)
		#	IF(LOC.EQ.0)GOTO 1070
		#	IF(BITSET(LOC,K))CALL BUG(8)
		# 1071	COND(LOC)=COND(LOC)+SHIFT(1,K)
		#	GOTO 1070
		while ($line = <ADVENT>) {
			chop $line;
			last if $line eq '-1';
			if ($line =~ /^(\d+)\t(.*)$/) {
				my $k = $1;
				$line = $2;
				while ($line =~ /(\d+)/g) {
					my $loc = $1;
					$loc--;
					if (defined($cond[$loc])) {
						$cond[$loc] |= (1 << $k);
					} else {
						$cond[$loc] = (1 << $k);
					}
				}
			} else {
				print STDERR "Malformed line in section 8:\n", $line, "\n";
				exit 1;
			}
		}
	} elsif ($line eq '10') {
		while ($line = <ADVENT>) {
			chop $line;
			last if ($line eq '-1');
			if ($line =~ /^(\d+)\t(.*)$/) {
				push @rank_pts, $1;
				push @rank_text, $2;
			}
		}
	} elsif ($line eq '11') {
		while ($line = <ADVENT>) {
			chop $line;
			last if ($line eq '-1');
			if ($line =~ /^(\d+)\t(\d+)\t(\d+)\t(\d+)\t(\d+)/) {
				if (defined $hints[$1-1]) {
					print STDERR "Duplicate hint index ", $1, ":\n", $line, "\n";
					exit 1;
				}
				$hints[$1-1] = [ $2, $3, $4, $5 ];
			}
		}
	}
}

# Next up, we have to initialize all forced-movement rooms to have cond 2. So
# go though the travel table and check for forced-movement

my $i;
my $j;

for ($i = 0; $i <= $#travel_key; $i++) {
	$j = $travel_key[$i];
	$cond[$i] = 2 if (abs($travel[$j]) % 1000) == 1;
}

# Now that we're done, add in some custom additional vocab...
# Allow Chirpy for the bird:
$vocab_object{"CHIRP"} = $vocab_object{"BIRD"};
# (Due to http://forums.somethingawful.com/showthread.php?threadid=3357967)

print "// Auto-generated data from ADVENT.DAT.\n";

my $comma = 0;
sub pcomma {
	if ($comma) {
		print ",\n";
	} else {
		$comma = 1;
	}
}

sub max_key($) {
	my $hash = shift;
	my $max_key = 0;
	
	for my $key (keys %$hash) {
		$key = int($key);
		$max_key = $key if $key > $max_key;
	}
	return $max_key;
}

sub dump_desc($) {
	my $hash = shift;

	# Find the largest key within the descriptions
	my $max_key = max_key($hash);
	
	for (my $i = 1; $i <= $max_key; $i++) {
		my $str = $hash->{$i};
		print ",\n" if $i > 1;
		if (defined $str) {
			print "\t\"", escape_json($str), "\"";
		} else {
			print "\tnull";
		}
	}
}

sub dump_ptext($) {
	my $hash = shift;

	# Find the largest key within the descriptions
	my $max_key = max_key($hash);
	
	for (my $i = 1; $i <= $max_key; $i++) {
		my $arr = $hash->{$i};
		print ",\n" if $i > 1;
		if ($arr) {
			print "\t[\n";
			$comma = 0;
			for my $str (@$arr) {
				pcomma();
				if (defined($str)) {
					print "\t\t\"", escape_json($str), "\"";
				} else {
					print "\t\tnull";
				}
			}
			print "\n\t]";
		} else {
			print "\tnull";
		}
	}
}

sub dump_actspk($) {
	my $hash = shift;

	# Find the largest key within the descriptions
	my $max_key = max_key($hash);
	
	for (my $i = 1; $i <= $max_key; $i++) {
		my $str = $hash->{$i};
		print ",\n" if $i > 1;
		if (defined $str) {
			print "\t", $str;
		} else {
			print "\tnull";
		}
	}
}

print "// Section 1:\nAdventure.LONG_DESCRIPTIONS = [\n";

dump_desc(\%longdesc);

print "\n];\n\n// Section 2:\nAdventure.SHORT_DESCRIPTIONS = [\n";

dump_desc(\%shortdesc);

print "\n];\n\n// Section 3:\nAdventure.TRAVEL_KEY = [\n";

for my $key (@travel_key) {
	pcomma();
	print "\t", $key;
}

print "\n];\n\nAdventure.TRAVEL = [\n";

$comma = 0;

for my $t (@travel) {
	pcomma();
	print "\t", $t;
}

print "\n];\n\n// Section 4:\nAdventure.VOCAB = [\n";

for (my $i = 0; $i <= $#vocab_sections; $i++) {
	print ",\n" if $i > 0;
	print "\t{\n";
	my $vocab = $vocab_sections[$i];
	$comma = 0;
	for my $word (keys %$vocab) {
		if ($comma) {
			print ",\n";
		} else {
			$comma = 1;
		}
		print "\t\t\"", escape_json($word), "\": ", $vocab->{$word};
	}
	print "\n\t}";
}

print "\n];\n\n// Section 5:\nAdventure.PTEXT = [\n";

dump_ptext(\%ptext);

print "\n];\n\n// Section 6:\nAdventure.RTEXT = [\n";

dump_desc(\%rtext);

print "\n];\n\n// Section 7:\nAdventure.PLACE = [\n";

$comma = 0;
for my $p (@place) {
	pcomma();
	print "\t", defined $p ? $p : "0";
}

print "\n];\n\nAdventure.FIXED = [\n";

$comma = 0;
for my $p (@fixed) {
	pcomma();
	print "\t", defined $p ? $p : "0";
}

print "\n];\n\n// Section 8:\nAdventure.ACTSPK = [\n";

dump_actspk(\%actspk);

print "\n];\n\n// Section 9:\nAdventure.COND = [\n";

$comma = 0;
for my $c (@cond) {
	pcomma();
	print "\t", defined $c ? $c : "0";
}

print "\n];\n\n// Section 10:\nAdventure.RANKS = [\n";

for ($i = 0; $i <= $#rank_pts; $i++) {
	if ($i > 0) {
		print ",\n";
	}
	print "\t{ score: ", $rank_pts[$i], ", message: \"", escape_json($rank_text[$i]), "\" }";
}

print "\n];\n\n// Section 11:\nAdventure.HINTS = [\n";

my $hint;
my $len;

for ($i = 0; $i <= $#hints; $i++) {
	if ($i > 0) {
		print ",\n";
	}
	$hint = $hints[$i];
	if (defined $hint) {
		print "\t[ ";
		$len = scalar @$hint;
		for ($j = 0; $j < $len; $j++) {
			if ($j > 0) {
				print ", ";
			}
			print $hint->[$j];
		}
		print " ]";
	} else {
		print "\tnull";
	}
}

# MSpeak is currently never used, so commenting it out.
#print "\n];\n\n// Section 12:\nAdventure.MTEXT = [\n";
#
#dump_desc(\%mtext);

print "\n];\n\n";
print <<EOJS;
// Accessor functions to ease Fortran-JavaScript conversion:
function make_accessor(array, max) {
	if (!('length' in array))
		throw Error("Missing required array");
	return function(i) {
		if (i >= 1 && i <= max) {
			i--;
			return i < array.length ? array[i] : 0;
		}
		throw Error("Index out of bounds [1-" + max + "]: " + i);
	};
}

Adventure.cond = make_accessor(Adventure.COND, 150);
Adventure.fixd = make_accessor(Adventure.FIXED, 100);
Adventure.plac = make_accessor(Adventure.PLACE, 100);
EOJS
