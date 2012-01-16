## gear database parser
package glm_database;
use Moose;
use Carp;

use Switch;

use constant {
    KEYWORD => 0,
    ID => 1,
    OPEN => 2,
    ASSIGN => 3,
    VALUE => 4
};

has 'state' => (isa => 'Int', is => 'rw', default=>KEYWORD);
has 'id_stack' => (isa => 'ArrayRef[Str]', is => 'rw', default => sub {[]});
has 'items' => (isa => 'HashRef[HashRef[Str]]', is => 'rw', default => sub {{}});

has 'value' => (isa => 'Str', is => 'rw');
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
                $item->{$this->last_keyword} = $this->value;
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
    $this->print_item($item);

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

package main;
use strict;

my $db = glm_database->new(filename => shift);

exit(0);


