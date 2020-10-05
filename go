set -e
python prep.py
iverilog *.v
rm -f sram[0-9]* 0???.png
./a.out
python post.py sram???
qiv 0???.png
