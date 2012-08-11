# *.glm preprocessor
package glm_preprocessor;
use Moose;
use Carp;

use FindBin qw($Script);

has 'filenames' => (isa => 'ArrayRef[Str]', is => 'rw', required => 1);
has 'input_handle' => (isa => 'FileHandle', is => 'rw');

my $stream;


## constructor
sub BUILD {
    my ($this, $args) = @_;

    $this->load();
}

sub load {
    my ($this) = @_;

    open(my $out, ">", \$stream);

    for my $filename (@{$this->filenames}) {
        $this->read($filename, $out);
    }

    close($out);

    # open for reading for others
    open(my $fh, "<", \$stream);
    $this->input_handle($fh);
}

sub read {
    my ($this, $filename, $out) = @_;

    open(my $in, "<", $filename) or die("cannot open '$filename'");

    while (<$in>) {
        my $line = $_;

        if (m/^#include <(.*)>/) {
            # process includes
            $this->read($1, $out);
        } else {
            print $out $line;
        }
    }

    close($in);
}

1;
