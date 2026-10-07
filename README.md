# <img alt="Dancelor" src="src/static/logo.svg" height="100px">

A chancelor for Scottish country dance musicians. See:

- the [website](https://dancelor.org/)
- the [documentation](./doc)
- the [API documentation](https://niols.github.io/dancelor/dancelor)

### Naming things

_Entities_ are anything that we store in the database. They are split into two
categories: the _principals_ are users and groups, the “social” part of Dancelor
(see [Wikipedia](<https://en.wikipedia.org/wiki/Principal_(computer_security)>));
non-principal entities are _resources_.

The _actor_ is the authenticated user interacting with Dancelor, or the
information that the user is unauthenticated (so it will typically be an
option).
