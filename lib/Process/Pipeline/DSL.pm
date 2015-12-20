package Process::Pipeline::DSL;
use 5.22.1;
use experimental qw/ postderef signatures /;
use Process::Pipeline;

use Exporter qw/ import /;
our @EXPORT = qw/ proc /;

our $TOP;

sub proc ($code, @proc) :prototype(&;@) {
    if (!$TOP) {
        local $TOP = Process::Pipeline->new;
        my $p = Process::Pipeline::Process->new;
        $p->cmd($code->());
        $TOP->_push($p);
        $TOP->_push($_) for map { $_->{process}->@* } @proc;
        return $TOP;
    } else {
        my $p = Process::Pipeline::Process->new;
        $p->cmd( $code->() );
        return $p;
    }
}


1;
