set -e
python prep.py
iverilog asteroids.v top.v MUX.v chip_6502.v
rm -f sram[0-9]* 0???.png
./a.out
exit
python post.py sram???
qiv 0???.png
