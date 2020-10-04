set -e
python prep.py
iverilog *.v
./a.out
python post.py
qiv out.png
