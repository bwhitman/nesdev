# nesdev
tests on NES / famicom dev on real hardware / keyboards

```
 make # build the assembler
 build/nesasm keyboard.asm # assemble the asm to NES file
 cp keyboard.nes /Volumes/NO\ NAME/  # copy it to the Everdrive SD card
 diskutil unmount /Volumes/NO\ NAME/ # unmount the SD card
 ```

 Keyboard details: https://wiki.nesdev.com/w/index.php/Family_BASIC_Keyboard

 6502 help: http://www.6502.org/tutorials/6502opcodes.html#BCC
 
 and https://dwheeler.com/6502/oneelkruns/asm1step.html
