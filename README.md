# spork
Spork is a component framework

## Building entities
* Components defining callbacks must be interfaces having a `@component` metadata, with `@callback` metadata defining the callback functions
* Actual components must be classes, that implement callback components and extend `spork.core.Entity`