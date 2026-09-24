package Perl::Critic::Policy::BuiltinFunctions::ProhibitChainingSameListSub;

# ABSTRACT: Walk a list once: do not feed map into map, or grep into grep.

use strict;
use warnings FATAL => 'all';

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification };
use parent              qw{Perl::Critic::Policy};

=head1 Perl::Critic::Policy::BuiltinFunctions::ProhibitChainingSameListSub

A list function whose list is the result of another call to the same function
walks the list twice and builds a list in between that nobody keeps:

    my @names = map { lc } map { $_->name } @users;          # reported
    my @names = map { lc $_->name } @users;                   # one pass

    my @live  = grep { !$_->deleted } grep { $_->active } @rows;   # reported
    my @live  = grep { $_->active && !$_->deleted } @rows;          # one pass

The two blocks go into one, joined as the function calls for: one expression
after the other for C<map>, C<&&> for C<grep>.

=head2 PROHIBITED

    map { f($_) } map { g($_) } @x;
    map( { f($_) } map { g($_) } @x );
    map f($_), map g($_), @x;
    grep { a($_) } grep { b($_) } @x;
    sort { $a <=> $b } sort @x;
    any { a($_) } any { b($_) } @x;             # List::Util, and its kin
    List::Util::first { a($_) } first { b($_) } @x;

=head2 ALLOWED

    map { f($_) } grep { g($_) } @x;            # two different functions
    map { f($_) } @x, map { g($_) } @y;         # the second is one list of several
    map { [ map { f($_) } @$_ ] } @rows;        # nested, not chained
    $obj->map( sub { ... } )->map( sub { ... } );   # methods, not the builtin

=head2 CONFIGURATION

=over 4

=item C<functions>

Space separated list of function names to check, which B<adds to> the built-in
list rather than replacing it.  A name with a package matches only a call that
names that package; a name without one matches a call with or without a package.

    [BuiltinFunctions::ProhibitChainingSameListSub]
    functions = pairmap My::Util::each_item

The built-in list is:

    map grep sort first any all none notall

=back

=head2 CAVEATS

A C<map> whose inner block returns more than one element per item flattens as
it goes, and combining the two blocks means writing that flattening into one.
It is still one pass, but when the result reads worse than the chain, say
C<## no critic (ProhibitChainingSameListSub)> and why.

C<sort> chained with C<sort> is reported because the first sort's order is
thrown away by the second, whatever the blocks say.

=cut

Readonly::Scalar my $DESC => q{Same list function chained on its own result};
Readonly::Scalar my $EXPL => q{Combine the two blocks, so the list is walked once and no list is built in between};

Readonly::Array my @DEFAULT_FUNCTIONS => qw{ map grep sort first any all none notall };

=head2 METHODS

=head3 supported_parameters

=cut

sub supported_parameters {
    return (
        {
            name           => 'functions',
            description    => 'More list functions to check, beside the built-in ones.',
            default_string => q{},
            behavior       => 'string list',
        },
    );
}

=head3 initialize_if_enabled

=cut

sub initialize_if_enabled {
    my ( $self, $config ) = @_;
    $self->{_functions} = { map { $_ => 1 } @DEFAULT_FUNCTIONS, keys %{ $self->{_functions} // {} } };
    return 1;
}

=head3 default_severity

=head3 default_themes

=head3 applies_to

=cut

sub default_severity { return $SEVERITY_MEDIUM }
sub default_themes   { return qw{ performance } }
sub applies_to       { return 'PPI::Token::Word' }

=head3 violates

=cut

sub violates {
    my ( $self, $elem, undef ) = @_;

    my $name = $self->_listed($elem) or return;
    return unless is_function_call($elem);

    my $inner = _first_of_list( $elem->snext_sibling, $elem ) or return;
    return unless $inner->isa('PPI::Token::Word');

    my $inner_name = $self->_listed($inner) or return;
    return unless _bare($inner_name) eq _bare($name);

    return $self->violation( $DESC, $EXPL, $elem );
}

# The name as written, when it is a function this policy checks: listed as
# written, or listed without the package it was called through.
sub _listed {
    my ( $self, $word ) = @_;

    my $name = $word->content;
    return $name if $self->{_functions}{$name} || $self->{_functions}{ _bare($name) };
    return;
}

sub _bare {
    my ($name) = @_;
    my $at = rindex( $name, '::' );
    return $at < 0 ? $name : substr( $name, $at + 2 );
}

# The first element of the list a list function is walking, given the element
# after its name: past the block for the block form, past the first
# top-level comma for the expression form, and inside the parentheses when the
# arguments are parenthesised.
sub _first_of_list {
    my ( $next, $call ) = @_;
    return unless $next;

    if ( $next->isa('PPI::Structure::List') ) {
        my $expr = $next->schild(0) or return;
        return _first_of_list( $expr->schild(0), $call );
    }

    return $next->snext_sibling if $next->isa('PPI::Structure::Block');

    # sort has no EXPR, LIST form: without a block, its list starts here.
    return $next if _bare( $call->content ) eq 'sort';

    # map EXPR, LIST: the list starts after the first comma at this level.
    my $at = $next;
    while ($at) {
        return $at->snext_sibling if $at->isa('PPI::Token::Operator') && ( $at->content eq q{,} || $at->content eq q{=>} );
        return                    if $at->isa('PPI::Token::Structure');
        $at = $at->snext_sibling;
    }
    return;
}

1;
