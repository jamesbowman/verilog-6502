import zipfile
import sys
import array
from PIL import Image, ImageDraw

def signed2(x):
    return (x & 0x3) * (-1 if (x & 0x4) else 1)
def signed10(x):
    return (x & 0x3ff) * (-1 if (x & 0x400) else 1)
gsf = [
lambda x: x     , # 0   Multiply by 0
lambda x: x*2   , # 1   Multiply by 2
lambda x: x*4   , # 2   Multiply by 4
lambda x: x*8   , # 3   Multiply by 8
lambda x: x*16  , # 4   Multiply by 16
lambda x: x*32  , # 5   Multiply by 32
lambda x: x*64  , # 6   Multiply by 64
lambda x: x*128 , # 7   Multiply by 128
lambda x: x/256 , # 8   Divide by 256
lambda x: x/128 , # 9   Divide by 128
lambda x: x/64  , # 10  Divide by 64
lambda x: x/32  , # 11  Divide by 32
lambda x: x/16  , # 12  Divide by 16
lambda x: x/8   , # 13  Divide by 8
lambda x: x/4   , # 14  Divide by 4
lambda x: x/2   , # 15  Divide by 2
]

class DVG:
    def __init__(self, mem):
        self.im = Image.new("L", (1024, 1024))
        self.dr = ImageDraw.Draw(self.im)
        self.mem = mem

        self.stack = []

    def draw(self, dx, dy, bright):
        dx = self.sf(dx)
        dy = self.sf(dy)
        x1 = self.x + dx
        y1 = self.y + dy
        if bright:
            self.dr.line((self.x, 1024 - self.y, x1, 1024 - y1), 15 * bright)
        (self.x, self.y) = (x1, y1)

    def run(self):
        self.pc = 0
        self.x = 0
        self.y = 0
        self.s = 0
        while 1:
            insn = self.mem[self.pc // 2]
            # print("pc=%04x %04x" % (self.pc, insn))
            cmd = insn >> 12
            if cmd <= 9:
                dy = signed10(insn)
                f = self.mem[self.pc // 2 + 1]
                bright = f >> 12
                dx = signed10(f)
                s = 1 << (9 - cmd)
                self.draw(dx / s, dy / s, bright)
                print("               VEC scale=%02d bri=%-2d  x=%-5d y=%-5d (%.4f, %.4f)" % (self.s + cmd, bright, dx, dy, dx / s, dy / s))
                self.pc += 4
            elif cmd == 0xa:
                self.y = insn & 0x3ff
                f = self.mem[self.pc // 2 + 1]
                self.s = f >> 12
                self.sf = gsf[f >> 12]
                self.x = f & 0x3ff
                self.pc += 4
            elif cmd == 0xb:
                return
            elif cmd == 0xc:
                self.stack.append(self.pc + 2)
                self.goto(insn & 0xfff)
            elif cmd == 0xd:
                self.pc = self.stack.pop()
            elif cmd == 0xe:
                self.goto(insn & 0xfff)
            elif cmd == 0xf:
                dx = signed2(insn) << 8
                dy = signed2(insn >> 8) << 8
                bright = (insn >> 4) & 0xf
                SF1 = 1 & (insn >> 3)
                SF0 = 1 & (insn >> 11)
                s = {
                    (0, 0) : 128,
                    (0, 1) : 64,
                    (1, 0) : 32,
                    (1, 1) : 16}[(SF1, SF0)]
                self.draw(dx / s, dy / s, bright)
                print("               SVEC scale=%02d bri=%-2d  x=%-5d y=%-5d (%.4f, %.4f) S=%d" % (s, bright, dx, dy, dx / s, dy / s, self.s))
                self.pc += 2
            else:
                assert 0, hex(cmd)

    def goto(self, aa):
        self.pc = aa * 2
        return
        self.pc = (aa - 0x800) * 2 + 0x800

    def save(self, fn):
        self.im.save(fn)

def post(srams):
    with zipfile.ZipFile("asteroids_rom_2.zip") as z:
        with z.open("035127.02", "r") as f:
            rom = f.read()
    for sram in srams:
        frame = sram[4:]
        ram = bytes([int(l,16) for l in open(sram) if l[0] != "/"])
        mem = array.array("H", ram + bytes(2048) + rom + bytes(2048))
        assert len(mem) == 4096
        open("dump", "wb").write(mem.tobytes())
        dvg = DVG(mem)
        dvg.run()
        dvg.save("%s.png" % frame)

def post2(fn):
    mem = array.array("H", bytes([int(l,16) for l in open(fn) if l[0] != "/"]))
    assert len(mem) == 4096, fn
    dvg = DVG(mem)
    dvg.run()
    dvg.save("out.png")

if __name__ == "__main__":
    post(sys.argv[1:])
    # post2("snapshot")
