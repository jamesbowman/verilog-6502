set -e
python prep.py
iverilog *.v
./a.out
python post.py sram??
qiv 00??.png
