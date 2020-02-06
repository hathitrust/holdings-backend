use strict;
use warnings;

my ($f1, $f2) = @ARGV;

# print "# 0 = exists in both\n";
print "# < = exists only in $f1\n";
print "# > = exists only in $f2\n";
print "# --------------------- \n";

my $h1 = read_file($f1);
my $h2 = read_file($f2);

compare_sets($h1, $h2, $f1, $f2);

sub read_file {
    my $f = shift;
    my $h =  {};
    open(F, $f) || die $!;
    while(<F>){
	my $line = $_;

	# Whitespace normalization:
	chomp $line;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	# $line =~ s/\s+/ /g;

	$$h{$line}++;
    }
    close(F);
    return $h;
}

sub compare_sets {
    my $h1 = shift;
    my $h2 = shift;

    my $f1 = shift;
    my $f2 = shift;

    foreach my $line (keys %$h1, keys %$h2) {
	if ( exists $$h1{$line} && exists $$h2{$line}) {
	    # don't actually care about these
	    # print "0\t$line\n";
	    delete $$h1{$line};
	    delete $$h2{$line};
	} elsif (exists $$h1{$line}) {
	    print "<\t$line\n";
	    delete $$h1{$line};
	} elsif (exists $$h2{$line}) {
	    print ">\t$line\n";
	    delete $$h2{$line};
	}
    }
}
