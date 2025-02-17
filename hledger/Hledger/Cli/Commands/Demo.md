## demo

Play demos of hledger usage in the terminal, if asciinema is installed.

_FLAGS

Run this command with no argument to list the demos.
To play a demo, write its number or a prefix or substring of its title.
Tips:

Make your terminal window large enough to see the demo clearly.

During playback, several keys are available:
SPACE to pause/unpause, . to step forward (while paused),
CTRL-c  quit.

asciinema options can be added following a double dash, such as
`-s N` to adjust speed and `-i SECS` to limit pauses.
Run `asciinema -h` to list these options.

Examples:
```shell
$ hledger demo                      # list available demos
$ hledger demo 1                    # play the first demo
$ hledger demo install -- -s5 -i.5  # play the install demo at 5x speed,
                                    # with pauses limited to half a second
```
