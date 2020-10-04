set -e
python prep.py
iverilog *.v
# rm -f sram[0-9]*
# ./a.out
python post.py sram???
qiv 00???.png
