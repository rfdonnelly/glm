package glm_manifest;
use Moose;
use Carp;

use Switch;

use constant {
    SECTION => 0,
    ITEM => 1,
    FIELD => 2
};

has 'state' => (isa => 'Int', is => 'rw', default=>KEYWORD);
has 'filename' => (isa => 'Str', is => 'rw', required => 1);

# "constructor"
sub BUILD {
    my ($this, $args) = @_;

    $this->load();
}

sub load {
    my ($this) = @_;

    open(my $fh, "<", $this->filename);

    while (<$fh>) {
        next if (m/\s*#/); # skip full-line comments
        s/\s+#.*//; # strip end-of-line comment
        s/^\s+//; # strip leading whitespace

        switch ($this->state) {
            case SECTION {
            } case ITEM {
            } case FIELD {
            } else {
                croak("unexpected state $this->state");
            }
        }

    }

    close($fh);
}
