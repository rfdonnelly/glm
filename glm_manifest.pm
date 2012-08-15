package glm_manifest;
use Moose;
use Carp;

use FindBin qw($Script);
use POSIX qw(floor);

use glm_database;

use Switch;

use constant {
    SECTION => 0,
    ITEM => 1,
};

use constant KG_PER_OZ => 0.0283495231;

#has 'state' => (isa => 'Int', is => 'rw', default=>SECTION);
#has 'section' => (isa => 'Str', is => 'rw');
#has 'section_weight' => (isa => 'Num', is => 'rw');
#has 'section_weights' => (isa => 'HashRef[Num]', is => 'rw', default => sub { {} });


#has 'filename' => (isa => 'Str', is => 'rw', required => 1);
has 'db' => (isa => 'glm_database', is => 'rw', required => 1);

# "constructor"
sub BUILD {
    my ($this, $args) = @_;

    $this->load();
}

sub load {
    my ($this) = @_;

    my $db = $this->db;

    for my $id (@{$db->identifiers}) {
        if ($db->groups->{$id}) {
            my $group = $db->groups->{$id};
            print("$id\n");

            for my $item_inst (@{$group->{items}}) {
                my $count = $item_inst->{count};
                my $item = $item_inst->{item};
                my $weight_str = $item->{weight} ? 
                $this->sprint_weight(abs($item_inst->{count} * $item->{weight})) :
                    "TBD";

                printf("%+3d %-30s %15s", $count, $this->sprint_obj_id($item), $weight_str);
                printf(" -- %s", $item->{desc}) if (exists($item->{desc}));
                print("\n");
            }

            my $weight_str = $this->sprint_weight($group->{weight});
            printf("%-34s %15s\n", "SUBTOTAL", $weight_str);
            print("\n");
        }
    }
}

sub load2 {
    my ($this) = @_;

    open(my $fh, "<", $this->filename);

    while (<$fh>) {
        next if (m/\s*#/); # skip full-line comments
        s/\s+#.*//; # strip end-of-line comment
        s/^\s+//; # strip leading whitespace

        switch ($this->state) {
            case SECTION {
                if (m/^\w+$/) {
                    # section heading
                    chomp($_);
                    $this->section($_);

                    $this->section_weight(0);
                    print(uc()."\n");

                    $this->state(ITEM);
                } elsif (m/^\s*$/) {
                    # blank between sections
                    next;
                } else {
                    die("$Script: error - cannot parse section");
                }
            } case ITEM {
                if (m/^\s*$/) {
                    # end current section -> next section
                    $this->section_weights->{lc($this->section)} = $this->section_weight;
                    printf("%-34s %15s\n", "SUBTOTAL", $this->sprint_weight($this->section_weight));
                    print("\n");
                    $this->state(SECTION);
                } elsif (m/^([+-]\d+)\s(.*$)/) {
                    # item
                    $this->process_manifest_line($1, $2);
                } else {
                    die("$Script: error - cannot parse item");
                }
            } else {
                croak("unexpected state $this->state");
            }
        }

    }

    close($fh);
}

sub process_manifest_line {
    my ($this, $count, $id) = @_;

    if ($id =~ /section::/) {
        # lookup section
        $id =~ s/section:://;
        die("$Script: section $id does not exist in db.\n") if (!exists($this->section_weights->{$id}));
        my $weight = $count*$this->section_weights->{$id};
        $this->section_weight($this->section_weight + $weight);
        printf("%+3d %-30s %15s\n", $count, uc($id), $this->sprint_weight(abs($weight)));
    } else {
        # lookup item
        #warn("$Script: id $id does not exist in db.\n") && return if (!exists($db{$id}));
        my $weight;
        my %item;
        if (exists($this->db->items->{$id})) {
            %item = %{$this->db->items->{$id}};
            $weight = $count*$item{weight};
            $this->section_weight($this->section_weight + $weight);
            $weight = $this->sprint_weight(abs($weight));
        } else {
            $weight = "TBD";
        }
        printf("%+3d %-30s %15s", $count, $this->sprint_id($id), $weight);
        printf(" -- %s", $item{desc}) if (%item && exists($item{desc}));
        print("\n");
    }
}

sub sprint_id {
    my ($this, $id) = @_;

    return join(' ', map {ucfirst($_)} split(/_|::/,$id));
}

sub sprint_obj_id {
    my ($this, $o) = @_;

    my $id = $o->{id};

    if ($o->{type} && $o->{type} eq "group") {
        return $id;
    } else {
        return join(' ', map {ucfirst($_)} split(/_|::/,$id));
    }
}


sub sprint_weight {
    my ($this, $kg) = @_;

    my $oz = $kg / KG_PER_OZ;
    my $lb = floor($oz/16);
    $oz -= $lb*16;

    return $lb ? sprintf("%dlb %.1foz", $lb, $oz) : sprintf("%.1foz", $oz);
}

1;
