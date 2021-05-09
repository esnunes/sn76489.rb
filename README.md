# SN76489 chip emulator

## TODO

- [ ] Add the concept of internal clock (system clock / 16).
- [ ] Keep track of system clock value.
- [ ] Add method `#step_to(system_clock)`.
- [ ] Create a SDL2 driver.
- [ ] Create a Master Clock machine that uses sound as the crystal.

## Tests

``` shell
rake test
rake coverage
```

## Demo

``` shell
./exe/demo
```
