[![Build Status](https://travis-ci.org/shoichikaji/Process-Pipeline.svg?branch=master)](https://travis-ci.org/shoichikaji/Process-Pipeline)

# NAME

Process::Pipeline - execute processes as pipeline

# SYNOPSIS

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

# DESCRIPTION

Process::Pipeline helps you write a pipeline of processes.

# COPYRIGHT AND LICENSE

Copyright 2015 Shoichi Kaji &lt;skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
