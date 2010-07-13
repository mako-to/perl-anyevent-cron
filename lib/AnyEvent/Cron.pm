package AnyEvent::Cron;

use strict;
use warnings;
use parent 'Class::Accessor::Lvalue::Fast';
use List::Rubyish;
use AE;
use Carp;
use Set::Crontab;
use Set::CrossProduct;
use DateTime;
use DateTime::TimeZone;
use DateTime::Event::Cron;

__PACKAGE__->mk_accessors(qw/schedule main time_zone/);

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(\%args);
    $self->initialize;
    return $self;
}

sub initialize {
    my $self = shift;
    $self->main      = AE::cv;
    $self->schedule  = List::Rubyish->new;
    $self->time_zone ||= DateTime::TimeZone->new( name => 'local' );
}

sub reg_cb {
    my ($self, @args) = @_;
    my $now = DateTime->now( time_zone => $self->time_zone );

    while ( my ($cron, $callback) = splice @args, 0, 2 ) {
        my @spec = split /\s+/, $cron;
        croak "invalid cron\n" unless @spec == 5;
        @spec = map { [ /[\-,\/]/ ? Set::Crontab->new( $_, [] )->list : $_ ] } @spec;
        my @schedules = Set::CrossProduct->new(\@spec)->combinations;
        for my $schedule ( map { join ' ', @$_ } @schedules ) {
            my $event = DateTime::Event::Cron->from_cron(
                cron  => $schedule,
                after => $now,
            );
            my $after    = $event->next->subtract_datetime_absolute($now)->seconds;
            my $interval = $event->next->subtract_datetime_absolute($now)->seconds - $after;
            $self->schedule->push( AE::timer $after, $interval, $callback );
        }
    }
}

sub run {
    my $self = shift;
    $self->main->recv;
}

sub stop {
    my $self = shift;
    $self->main->send;
}

1;
__END__

=head1 NAME

AnyEvent::Cron -

=head1 SYNOPSIS

  use AnyEvent::Cron;

  my $cron = AnyEvent::Cron->new;
  $cron->reg_cb(
      '* * * * *' => sub { print scalar localtime, "\n" }
  );
  $cron->run;

=head1 DESCRIPTION

AnyEvent::Cron is

=head1 METHOD

=head2 new

=head2 run

=head2 stop

=head1 AUTHOR

Makoto Miura E<lt>makoto at nanolia.netE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
