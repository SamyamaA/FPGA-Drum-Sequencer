# FPGA-Drum-Sequencer: User Guide
This project is a drum sequencer with a kick, snare and hi-hat. Tempo is adjustable and has a
VU monitor which is shown on the 16x16 LED board.

Set Up

Have all switches set to low, headphones/speakers plugged into the green audio jack of the
FPGA, and a 16x16 LED board connected to the GPIO_1 pins. Once the program is on the
FPGA, flip the reset (SW9) to high then low.


Recording a Beat

To record your beat, first flip SW0 to high, switching the device to recording mode. Then, use
the keys to make your beat. Pressing KEY3 corresponds to a kick, KEY2 to a snare, KEY1 to a
hi-hat, and KEY0 is the next button to move the playhead forward. HEX0 displays the current
playhead (0-7), and any drum keys pressed while that playhead is active will correspond to that
playhead in the looped beat. Multiple drum keys may be played during the same playhead.


Looping a Beat

Once you are finished with recording, flip SW0 to low, switching the device to loop mode. To edit
the beat, you may switch to recording mode at any time, adding more beats to the playhead of
your choice (you may move to the playhead of your choice using the next key).


Reset
Reset on this device is SW9. Reset will reset the playhead and erase the old beat which was
made.


Changing Tempo

To change the tempo of the beat, use SW8 and SW7. Setting these two switches will determine
the speed of the tempo, with the combinations from slowest to fastest being as follows: 00, 01,
10, 11.


VU Monitor

The volume unit monitor shows the current volume of the sound being played. Generally, if the
monitor shows green, that means one drum key was pressed for the playhead. Orange means
two drum keys, and red means three keys.


# Market and Usability Analysis
This project works best if seen as a demonstration of audio synthesis on FPGA rather than a
commercial ready drum sequencer, considering every sound is synthesized in hardware from
scratch (a square wave for the kick, and LFSR for the snare and hi-hat).

In terms of usability, the interface is fairly simple, with a switch that cleanly toggles between
record and play modes, three keys for the different sounds, one key to advance steps, a reset
switch, and a pair of switches to change tempo. The seven segment display shows the current
step during the recording phase, as well as whether the board is on loop or recording mode,
making it easy for the user to understand which phase of beat development they’re at.
Additionally, the 16x16 LED display gives the user immediate visual feedback that the system is
responding. The main ergonomic limitation is that sounds can’t be deleted once their respective
key is pressed on a step, the only way to redo a sound you don’t want is by resetting the entire
beat and starting from zero. Another limitation is the fact that the beat is fixed at eight steps,
which isn’t enough to create more complex, rich beats.

Finally, considering the resource utilization, the design is fairly efficient for its complexity. The
complete system consumes 1,005 ALUTs and 500 logic registers, which is only ~1% of the
DE1-SoC’s total resources. The logic I wrote is very cheap, with the sequencer being 33 ALUTs,
the mixer being 48, the synthesized sounds ranging from 53-69, and the pattern memory and
trigger systems costing almost nothing. The block with the largest consumption ended up being
the VU meter, where 384 ALUTs were used, since rendering all 256 LEDs needs substantial
gating. The provided audio driver accounts for the majority of the rest of the resources used
(285 ALUTs and 215 logic registers).
