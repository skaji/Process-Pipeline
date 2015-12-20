requires 'perl', '5.22.1';
requires 'Process::Status';
requires 'experimental';

on test => sub {
    requires 'Test::More', '0.98';
};
