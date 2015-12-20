package Process::Pipeline;
use 5.22.1;
use warnings;
use experimental qw/ postderef signatures /;

use File::Temp ();
use Process::Status;

our $VERSION = '0.01';

package Process::Pipeline::Process {
    sub new ($class) {
        bless { cmd => [], set => {} }, $class;
    }
    sub cmd ($self, @arg) {
        if (@arg) {
            if (ref $arg[0] eq 'CODE') {
                $self->{cmd} = $arg[0];
            } else {
                $self->{cmd} = \@arg;
            }
        }
        $self->{cmd};
    }
    sub set ($self, @arg) {
        if (@arg) {
            $self->{set}->{$arg[0]} = $arg[1] // undef;
        }
        $self->{set};
    }
}

package Process::Pipeline::Result {
    use POSIX ();
    sub new ($class) {
        bless {result => [], fh => undef}, $class;
    }
    sub push ($self, $hash) :method {
        push $self->{result}->@*, $hash;
        $self;
    }
    sub is_success ($self) {
        $self->@* == grep { $_->{status}->is_success } $self->{result}->@*;
    }
    sub fh ($self, $arg = undef) {
        $self->{fh} = $arg if $arg;
        $self->{fh};
    }
    sub wait ($self) :method {
        while (grep { !defined $_->{status} } $self->{result}->@*) {
            my $pid = waitpid -1, POSIX::WNOHANG;
            my $save = $?;
            if ($pid == 0) {
                select undef, undef, undef, 0.1;
            } elsif ($pid == -1) {
                last;
            } else {
                my ($found) = grep { $_->{pid} == $pid } $self->{result}->@*;
                if (!$found) {
                    warn "waitpid returns $pid, but is not our child!";
                    last;
                }
                $found->{status} = Process::Status->new($save);
            }
        }
        $self;
    }
}

sub new ($class) {
    bless { process => [] }, $class;
}

sub push ($self, $callback) :method {
    my $p = Process::Pipeline::Process->new;
    $callback->($p);
    push $self->{process}->@*, $p;
    $self;
}

sub _push ($self, $p) {
    push $self->{process}->@*, $p;
    $self;
}

sub start ($self, %option) {
    my $n = $self->{process}->$#*;
    my @pipe = map { pipe my $read, my $write; [$read, $write] } 0..($n - 1);
    my $close = sub ($i) {
        my @close = map { $pipe[$_]->@* } grep { $_ != $i - 1 && $_ != $i } 0..$#pipe;
        $_->close for @close;
    };

    my ($main_out_fh, $main_out_name);
    my $result = Process::Pipeline::Result->new;
    for my $i (0..$n) {
        my $process = $self->{process}[$i];
        if ($i == $n && !$process->set->{">"} && !$process->set->{">>"}) {
            ($main_out_fh, $main_out_name) = File::Temp::tempfile(UNLINK => 0);
        }
        my $pid = fork // die "fork: $!";
        if ($pid == 0) {
            if ($main_out_name) {
                close $main_out_fh;
                open STDOUT, ">>", $main_out_name or die $!;
            }
            $close->($i);
            my $read  = $i - 1 >= 0 ? $pipe[$i - 1] : undef;
            my $write = $pipe[$i];
            if ($read) {
                $read->[1]->close;
                open STDIN, "<&", $read->[0];
            }
            if ($write) {
                $write->[0]->close;
                $write->[1]->autoflush(1);
                open STDOUT, ">&", $write->[1];
            }

            my %set = $process->set->%*;
            if (my $in = $set{"<"}) {
                open my $fh, "<", $in or die "open $in: $!";
                open STDIN, "<&", $fh;
            }
            if (my $out = $set{">"} or my $append = $set{">>"}) {
                my $mode = defined $out ? ">"  : ">>";
                my $file = defined $out ? $out : $append;
                open my $fh, $mode, $file or die "open $file: $!";
                open STDOUT, "$mode&", $fh;
            }
            if (my $out = $set{"2>"} or my $append = $set{"2>>"}) {
                my $mode = defined $out ? ">"  : ">>";
                my $file = defined $out ? $out : $append;
                open my $fh, $mode, $file or die "open $file: $!";
                open STDERR, "$mode&", $fh;
            }
            if (exists $set{"2>&1"}) {
                open STDERR, ">&", \*STDOUT;
            }

            my $cmd = $process->cmd;
            if (ref $cmd eq "CODE") {
                $cmd->();
                exit;
            } else {
                my @cmd = $cmd->@*;
                exec {$cmd[0]} @cmd;
                exit 255;
            }
        }
        $result->push({
            pid     => $pid,
            cmd => $process->cmd,
            status  => undef,
        });
    }
    $_->close for map { $_->@* } @pipe;
    if ($main_out_fh) {
        select undef, undef, undef, 0.01;
        unlink $main_out_name;
        $result->fh($main_out_fh);
    }
    $result->wait unless $option{async};
    $result;
}

1;
__END__

=encoding utf-8

=head1 NAME

Process::Pipeline - execute processes as pipeline

=head1 SYNOPSIS

In shell:

   $ zcat access.log.gz | grep 198.0.0.1 | wc -l

In perl5:

  use Process::Pipeline;

  my $pipeline = Process::Pipeline->new
    ->push(sub ($p) { $p->cmd("zcat", "access.log.gz") })
    ->push(sub ($p) { $p->cmd("grep", "198.168.10.1")  })
    ->push(sub ($p) { $p->cmd("wc", "-l")              });

  my $r = $pipeline->start;

  if ($r->is_success) {
     my $fh = $result->fh; # output filehandle of $pipeline
     say <$fh>;
  }

In perl5 with DSL:

  use Process::Pipeline::DSL;

  my $pipeline = proc { "zcat", "access.log.gz" }
                 proc { "grep", "198.168.10.1"  }
                 proc { "wc", "-l"              };

  my $r = $pipeline->start;

=head1 DESCRIPTION

Process::Pipeline helps you write a pipeline of processes.

=head1 COPYRIGHT AND LICENSE

Copyright 2015 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
