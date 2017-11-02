#!/usr/bin/perl
# $Header: $
#

use strict;
use Getopt::Long;
use Test::More tests => 3;
use FindBin qw($Bin);  # Where was this script installed?
use lib "$Bin/.."; # Add .. to @INC;

use Refactor;

## Parse options
my ($verbose);
GetOptions( 
            "verbose"     => \$verbose,
          );


my $code = <<'eos';
  my @results;
  my $hash = $self->{hash};
  my $date = localtime;
  for my $loopvar (@array) {
     print "Checking $loopvar\n";
     push @results, $hash->{$loopvar} || '';
  }

eos

my $refactory = Devel::Refactor->new($verbose);
my ($new_method_call,$new_code) = $refactory->extract_subroutine('newMethod',$code);
if ($verbose) {
    diag "new method call:\n####\n$new_method_call\n####";
    diag "new code:\n####\n$new_code\n####";
    diag "Scalars:\n  " , join "\n  ", $refactory->get_scalars, "\n";
    diag "Arrays: \n  ", join "\n  ", $refactory->get_arrays, "\n";
    diag "Hashes:\n  ",join "\n  ",  $refactory->get_hashes, "\n";
}

# Check return values
my $expected_result = 'my ($date, $hash, $results) = $self->newMethod(\@array);';
my $result = $new_method_call;
chop $result; # remove newline, just to make diagnostic message prettier.
ok ($result eq $expected_result, 'New method signature') or
  diag("Expected '$expected_result'\ngot      '$result' instead");

eval $new_code;
ok ( $@ eq '', 'eval extracted method declaration') or diag "New code failed to eval\n####\n$new_code\n####\n$@";

$code = <<'eos';
package M;
use Test::More;
    sub new {
        my $class = shift;
        my $self = bless {
            hash => { foo => 'value 1', bar => 'value 2' },
        }, $class;
        return $self;
    }
    sub longMethod()
    {
        my $self = shift;
        my @array = qw( foo bar baz );
eos
$code .= $new_method_call;
$code .= <<'eos';
        if ($verbose) {
            diag "\$date: $date";
            diag "\@results: ", join ', ', @$results;
            diag "\%hash: ", join ', ', keys %{$hash};
            diag "\%hash: ", join ', ', values %{$hash};
        }
    }
eos
$code .= $new_code;
$code .= <<'eos';

    my $m = M->new();
    $m->longMethod();
eos
diag "About to eval code\n####\n$code\n####" if $verbose;
eval $code;

ok ( $@ eq '', 'run extracted method') or diag "Error eval'ing '$code': $@";

__END__
