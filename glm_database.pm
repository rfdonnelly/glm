## gear database parser
package glm_database;
use Moose;
use Carp;

use FindBin qw($Script);

use Switch;

use constant {
    KEYWORD => 0,
    ID => 1,
    OPEN => 2,
    ASSIGN => 3,
    VALUE => 4
};

use constant KG_PER_OZ => 0.0283495231;

has 'state' => (isa => 'Int', is => 'rw', default=>KEYWORD);
has 'id_stack' => (isa => 'ArrayRef[Str]', is => 'rw', default => sub {[]});
has 'items' => (isa => 'HashRef[HashRef[Str]]', is => 'rw', default => sub {{}});

has 'value' => (isa => 'Str', is => 'rw', default => '');
has 'last_keyword' => (isa => 'Str', is => 'rw');
has 'prev_token' => (isa => 'Str', is => 'rw');

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

        my @tokens = split(/\s+/);
        for my $token (@tokens) {
            $this->parse_token($token);
        }

        $this->parse_token("newline");
    }

    close($fh);
}

sub parse_token {
    my ($this, $token) = @_;

    switch ($this->state) {
        case KEYWORD {
            switch ($token) {
                case "item" {
                    $this->state(ID);
                } case "weight" {
                    $this->state(ASSIGN);
                } case "volume" {
                    $this->state(ASSIGN);
                } case "desc" {
                    $this->state(ASSIGN);
                } case "}" {
                    $this->pop_item();
                } case "newline" {
                } else {
                    die("unexpected keyword $token");
                }
            }

            $this->last_keyword($token);
        } case ID {
            die unless ($this->prev_token eq "item");

            $this->push_item($token);

            $this->state(OPEN);
        } case OPEN {
            die unless ($token eq "{");
            $this->state(KEYWORD);
        } case ASSIGN {
            die unless ($token eq "=");
            $this->state(VALUE);
        } case VALUE {
            if ($token eq "newline" || $token eq "}") {
                my $item = $this->current_item();
                if ($this->last_keyword eq "weight") {
                    $item->{$this->last_keyword} = $this->parse_weight($this->value);
                } else {
                    $item->{$this->last_keyword} = $this->value;
                }
                $this->value("");

                $this->state(KEYWORD);

                $this->pop_item() if ($token eq "}");
            } else {
                $this->value($this->value . "$token ");
            }
        } else {
            die("unexpected state $this->state");
        }
    }

    $this->prev_token($token);
}

sub push_item {
    my ($this, $id) = @_;

    push(@{$this->id_stack}, $id);

    my $item = {};
    $item->{id} = $this->current_id();
    $this->items->{$this->current_id()} = $item;
}

sub pop_item {
    my ($this) = @_;

    my $item = $this->current_item();
    #FIXME
    ##$this->print_item($item);

    my $id = pop(@{$this->id_stack});
}

sub print_item {
    my ($this, $item) = @_;

    print("$item->{id}\n");
    for my $key (sort(keys(%$item))) {
        print("$key = $item->{$key}\n") if ($key ne "id");
    }
    print("\n");
}

sub current_item {
    my ($this) = @_;

    my @id_stack = @{$this->id_stack};

    die unless (scalar(@id_stack) > 0);

    return $this->items->{$this->current_id()};
}

sub current_id {
    my ($this) = @_;

    my @id_stack = @{$this->id_stack};

    die unless (scalar(@id_stack) > 0);

    return join("::", @id_stack);
}

# parses a single unit w/o multiplier and mixed unit measure
# single unit
#   syntax: parse_measure($expr, $unit)
#   example:
#       parse_measure('12.4oz', 'oz')
#       returns 12.4
# single unit w/ multiplier
#   syntax: parse_measure($expr, $unit, $multiplier)
#   example:
#       parse_measure('5lb', 'lb', 16)
#       returns 5 * 16
# mixed unit
#   syntax: parse_measure($expr, $unit_a, $multiplier_a, $unit_b)
#   example:
#       parse_measure('5lb12.4oz', 'lb', 16, 'oz')
#       returns 5 * 16 + 12.4
sub parse_measure {
    my ($this, $expr, @args) = @_;

    my $re_decimal = qr/([+-]?(\d+\.\d+|\d+\.|\.\d+|\d+))/;

    if (scalar(@args) == 3) {
        if ($expr =~ m/$re_decimal$args[0]\s*$re_decimal$args[2]/) {
            return $1 * $args[1] + $3;
        } else {
            return 0;
        }
    } elsif (scalar(@args) == 2 || scalar(@args) == 1) {
        if ($expr =~ m/$re_decimal$args[0]/) {
            if (scalar(@args) == 2) {
                return $1 * $args[1];
            } else {
                return $1;
            }
        } else {
            return 0;
        }
    } else {
        die("$Script: FATAL: invalid args");
    }

}

# returns weight in kg
sub parse_weight {
    my ($this, $expr) = @_;

    my $val = $this->parse_measure($expr, 'lb', 16, 'oz');
    return KG_PER_OZ * $val if ($val);

    $val = $this->parse_measure($expr, 'oz');
    return KG_PER_OZ * $val if ($val);

    $val = $this->parse_measure($expr, 'lb', 16);
    return KG_PER_OZ * $val if ($val);

    $val = $this->parse_measure($expr, 'g', 1/1000);
    return $val if ($val);

    die("$Script: ERROR: unable to parse volume $expr\n");
}

1;

#package main;
#use strict;
#
#my $db = glm_database->new(filename => shift);
#
#exit(0);


