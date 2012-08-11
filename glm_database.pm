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
    VALUE => 4,
    INSTANCE => 5,
};

use constant KG_PER_OZ => 0.0283495231;

# parser state
has 'state' => (isa => 'Int', is => 'rw', default=>KEYWORD);

# for nested ids
has 'id_stack' => (isa => 'ArrayRef[Str]', is => 'rw', default => sub {[]});

# type identifiers
has 'items' => (isa => 'HashRef[HashRef[Str]]', is => 'rw', default => sub {{}});
has 'groups' => (isa => 'HashRef[ArrayRef[HashRef[Str]]]', is => 'rw', default => sub {{}});

# all identifiers
has 'identifiers' => (isa => 'ArrayRef[Str]', is => 'rw', default => sub {[]});

# used to build up a value for the VALUE state
has 'value' => (isa => 'Str', is => 'rw', default => '');

# misc
has 'prev_keyword' => (isa => 'Str', is => 'rw');
has 'prev_token' => (isa => 'Str', is => 'rw');
has 'curr_type' => (isa => 'Str', is => 'rw');

has 'input_handle' => (isa => 'FileHandle', is => 'rw', required => 1);

# supported types and their attributes
my $types = {
    group => [],
    item => [
        "weight",
        "volume",
        "desc",
    ],
};

# "constructor"
sub BUILD {
    my ($this, $args) = @_;

    $this->load();
}

sub load {
    my ($this) = @_;

    my $fh = $this->input_handle;

    while (<$fh>) {
        next if (m/\s*#/); # skip full-line comments
        s/\s+#.*//; # strip end-of-line comment
        s/^\s+//; # strip leading whitespace

        my @tokens = split(/\s+/);
        for my $token (@tokens) {
            $this->parse_token($token);
        }

        $this->parse_token("\n");
    }

    close($fh);
}

sub parse_token {
    my ($this, $token) = @_;

    switch ($this->state) {
        case KEYWORD {
            switch ($token) {
                case "}" {
                    switch ($this->curr_type) {
                        case "group" {
                            $this->pop_group();
                        } case "item" {
                            $this->pop_item();
                        } else {
                            die("possible extraneous '}' curr_type " . $this->curr_type);
                        }
                    }
                } case "\n" {
                } else {
                    my $token_qm = quotemeta($token);

                    if ($this->curr_type && grep(/^$token_qm$/, @{$types->{$this->curr_type}})) {
                        # parse attributes inside a type
                        $this->state(ASSIGN);
                    } elsif (
                        $this->curr_type 
                        && $this->curr_type eq "group"
                        && $token =~ m/^(\+|-)(\d+)$/
                    ) {
                        # parse instances inside a group
                        $this->state(INSTANCE);
                    } elsif (grep(/^$token_qm$/, keys(%$types))) {
                        # parse for types
                        $this->state(ID);
                        $this->curr_type($token);
                    } else {
                        die("unexpected keyword $token");
                    }
                }
            }

            $this->prev_keyword($token);
        } case INSTANCE {
            my $count = $this->prev_token;
            my $id = $token;
            my $item = $this->items->{$id} ? $this->items->{$id} : $this->groups->{$id};

            if (!grep(/^$id$/, @{$this->identifiers})) {
                die("indentifier '$id' not defined");
            }

            #print "DBG $count $id ";
            #print $item->{weight} if $item->{weight};
            #print "\n";

            # add item to current group
            my $group = $this->current_group();
            my $item_inst = {
                item => $item,
                count => $count,
            };
            push(@{$group->{items}}, $item_inst);

            $this->state(KEYWORD);
        } case ID {
            switch ($this->prev_token) {
                case "item" {
                    $this->push_item($token);
                } case "group" {
                    $this->push_group($token);
                } else {
                    die("unexpected prev_token $this->prev_token in ID state");
                }
            }

            $this->state(OPEN);
        } case OPEN {
            die unless ($token eq "{");
            $this->state(KEYWORD);
        } case ASSIGN {
            die unless ($token eq "=");
            $this->state(VALUE);
        } case VALUE {
            if ($token eq "\n" || $token eq "}") {
                my $item = $this->current_item();
                if ($this->prev_keyword eq "weight") {
                    $item->{$this->prev_keyword} = $this->parse_weight($this->value);
                } else {
                    $item->{$this->prev_keyword} = $this->value;
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
    $item->{id} = $this->current_id;
    $this->items->{$item->{id}} = $item;

    push(@{$this->identifiers}, $item->{id});
}

sub push_group {
    my ($this, $id) = @_;

    push(@{$this->id_stack}, $id);

    my $group = {};
    $group->{id} = $this->current_id;
    $this->groups->{$group->{id}} = $group;

    push(@{$this->identifiers}, $group->{id});
}

sub pop_item {
    my ($this) = @_;

    my $item = $this->current_item();

    my $id = pop(@{$this->id_stack});

    my @id_stack = @{$this->id_stack};
    if (scalar(@id_stack) == 0) {
        $this->curr_type("");
    }
}

sub pop_group {
    my ($this) = @_;

    my $group = $this->current_group();

    # sum up weights for group and store in "weight" attribute
    my $weight = 0;
    for my $item_inst (@{$group->{items}}) {
        $weight += $item_inst->{item}->{weight} ? $item_inst->{count} * $item_inst->{item}->{weight} : 0;
    }
    $group->{weight} = $weight;

#    print "DBG $group->{id}\n";
#    for my $item_inst (@{$group->{items}}) {
#        print "DBG $item_inst->{count} $item_inst->{item}->{id} $item_inst->{item}->{weight}\n";
#    }
#    print "DBG SUBTOTAL $group->{weight}\n";
#    print "DBG \n";

    my $id = pop(@{$this->id_stack});

    my @id_stack = @{$this->id_stack};
    if (scalar(@id_stack) == 0) {
        $this->curr_type("");
    }
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

sub current_group {
    my ($this) = @_;

    my @id_stack = @{$this->id_stack};
    die unless (scalar(@id_stack) > 0);

    return $this->groups->{$this->current_id()};
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


