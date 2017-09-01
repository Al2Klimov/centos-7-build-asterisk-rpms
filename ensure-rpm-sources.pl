# (C) 2017 NETWAYS GmbH | GPLv2+
#
# Authors:
#   Alexander A. Klimov <alexander.klimov@netways.de>

# Parse the spec file, download all required sources
# and link them to the rpmbuild SOURCES directory.
#
# Usage: perl -- ensure-rpm-sources.pl SPEC_FILE SOURCES_DIR

# Fetch args
my $specFile = shift;
my $rpmSourcesDir = shift;

# RTFM
exit 2 if ! (defined($specFile) && defined($rpmSourcesDir));

# Change to the spec file's directory
chdir($specFile =~ s~[^/]+$~~r) if ($specFile =~ m~/~);

my $name = undef;
my $version = undef;
my @sources = ();
my $sourcesOld = undef;
my $clipboard = undef;

{
	local @ARGV = ($specFile);
	# Read the spec file
	while (<>) {
		# Skip empty lines and comments
		next if /^\s*(?:#|$)/;

		$sourcesOld = scalar(@sources);

		# Parse RPM spec directive
		if (/^((?:\w|[()])+)\d*:\s*(.+?)$/) {
			$value = $2;
			if ($1 =~ /^Source\d*$/) {
				push @sources, $value
			} elsif ($1 eq "Name") {
				$name = $value
			} elsif ($1 eq "Version") {
				$version = $value
			}
		}

		# If we have already collected some sources
		# and then hit a non-/^Source/ line,
		# assume that there are no more sources to collect
		last if ($sourcesOld > 0 && scalar(@sources) == $sourcesOld)
	}
}

for (@sources) {
	# Resolve expected RPM macros
	s/%\{name\}/$name/g;
	s/%\{version\}/$version/g;

	# Download if non-local
	if (m~^https?://~) {
		m~([^/]+)$~;
		$clipboard = $1;
		runcmd_strict("wget", $_) if ! -e $clipboard;
		$_ = $clipboard
	}

	if (-e) {
		if ($_ eq "$name-$version.tar.gz") {
			# The main source tarball -- mix with the local sources directory
			# (Assume that the local sources will be packed
			# to a tarball by another preparation script)
			runcmd("tar", "--strip-components=1", "-xzf", $_)
		} else {
			# Yet another source -- link to SOURCES
			$clipboard = "$rpmSourcesDir/$_";
			runcmd_strict("rm", "-r", $clipboard) if -e $clipboard;
			runcmd_strict("cp", "-a", $wd . $_, $clipboard)
		}
	}
}


sub runcmd {
	print "+ " . join(" ", @_) . "\n";
	system(@_) >> 8
}

sub runcmd_strict {
	die if runcmd(@_)
}
