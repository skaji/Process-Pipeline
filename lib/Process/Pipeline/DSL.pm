package Process::Pipeline::DSL;
use 5.22.1;
use experimental qw/ postderef signatures /;
use Process::Pipeline;

use Exporter qw/ import /;
our @EXPORT = qw/ proc set /;

our $PIPELINE;
our $PROCESS;

sub set ($key, $value = undef) {
    die "Cannot call outside proc()\n" unless $PROCESS;
    $PROCESS->set($key, $value);
}

sub proc ($code, @process) :prototype(&;@) {
    if (!$PIPELINE) {
        local $PIPELINE = Process::Pipeline->new;
        local $PROCESS  = Process::Pipeline::Process->new;
        $PROCESS->cmd($code->());
        $PIPELINE->_push($PROCESS);
        $PIPELINE->_push($_) for map { $_->{process}->@* } @process;
        return $PIPELINE;
    } else {
        local $PROCESS = Process::Pipeline::Process->new;
        $PROCESS->cmd($code->());
        return $PROCESS;
    }
}


1;
