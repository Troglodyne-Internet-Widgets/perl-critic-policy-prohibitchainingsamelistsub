# NAME

Perl::Critic::Policy::BuiltinFunctions::ProhibitChainingSameListSub - Walk a list once: do not feed map into map, or grep into grep.

# VERSION

version 0.001

# Perl::Critic::Policy::BuiltinFunctions::ProhibitChainingSameListSub

A list function whose list is the result of another call to the same function
walks the list twice and builds a list in between that nobody keeps:

```perl
my @names = map { lc } map { $_->name } @users;          # reported
my @names = map { lc $_->name } @users;                   # one pass

my @live  = grep { !$_->deleted } grep { $_->active } @rows;   # reported
my @live  = grep { $_->active && !$_->deleted } @rows;          # one pass
```

The two blocks go into one, joined as the function calls for: one expression
after the other for `map`, `&&` for `grep`.

## PROHIBITED

```perl
map { f($_) } map { g($_) } @x;
map( { f($_) } map { g($_) } @x );
map f($_), map g($_), @x;
grep { a($_) } grep { b($_) } @x;
sort { $a <=> $b } sort @x;
any { a($_) } any { b($_) } @x;             # List::Util, and its kin
List::Util::first { a($_) } first { b($_) } @x;
```

## ALLOWED

```perl
map { f($_) } grep { g($_) } @x;            # two different functions
map { f($_) } @x, map { g($_) } @y;         # the second is one list of several
map { [ map { f($_) } @$_ ] } @rows;        # nested, not chained
$obj->map( sub { ... } )->map( sub { ... } );   # methods, not the builtin
```

## CONFIGURATION

- `functions`

    Space separated list of function names to check, which **adds to** the built-in
    list rather than replacing it.  A name with a package matches only a call that
    names that package; a name without one matches a call with or without a package.

    ```
    [BuiltinFunctions::ProhibitChainingSameListSub]
    functions = pairmap My::Util::each_item
    ```

    The built-in list is:

    ```
    map grep sort first any all none notall
    ```

## CAVEATS

A `map` whose inner block returns more than one element per item flattens as
it goes, and combining the two blocks means writing that flattening into one.
It is still one pass, but when the result reads worse than the chain, say
`## no critic (ProhibitChainingSameListSub)` and why.

`sort` chained with `sort` is reported because the first sort's order is
thrown away by the second, whatever the blocks say.

## METHODS

### supported\_parameters

### initialize\_if\_enabled

### default\_severity

### default\_themes

### applies\_to

### violates

# AUTHORS

Current Maintainers:

- George S. Baugh <george@troglodyne.net>

# COPYRIGHT AND LICENSE

Copyright (c) 2026 Troglodyne LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
