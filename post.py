import zipfile
import array
from PIL import Image, ImageDraw

def signed2(x):
    return (x & 0x3) * (-1 if (x & 0x4) else 1)
def signed10(x):
    return (x & 0x3ff) * (-1 if (x & 0x400) else 1)

class DVG:
    def __init__(self, mem):
        self.im = Image.new("L", (1024, 1024))
        self.dr = ImageDraw.Draw(self.im)
        self.mem = mem

        self.stack = []

    def draw(self, dx, dy, bright):
        x1 = self.x + dx
        y1 = self.y + dy
        if bright:
            self.dr.line((self.x, 1024 - self.y, x1, 1024 - y1), 255)
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
                s = 1 << (9 - (self.s + cmd))
                x1 = self.x + dx / s
                y1 = self.y + dy / s
                self.draw(dx / s, dy / s, bright)
                print("               VEC scale=%02d bri=%-2d  x=%-5d y=%-5d (%.4f, %.4f)" % (self.s + cmd, bright, dx, dy, dx / s, dy / s))
                self.pc += 4
            elif cmd == 0xa:
                self.y = insn & 0x3ff
                f = self.mem[self.pc // 2 + 1]
                s = f >> 12
                x = f & 0x3ff
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
                sf = 2 + (2 * SF1 + SF0)
                s = 1 << (9 - (self.s + sf))
                self.draw(dx / s, dy / s, bright)
                print("               SVEC scale=%02d bri=%-2d  x=%-5d y=%-5d (%.4f, %.4f)" % (sf, bright, dx, dy, dx / s, dy / s))
                self.pc += 2
            else:
                assert 0, hex(cmd)

    def goto(self, aa):
        self.pc = (aa - 0x800) * 2 + 0x800

    def save(self, fn):
        self.im.save(fn)

def post():
    with zipfile.ZipFile("asteroids_rom_2.zip") as z:
        with z.open("035127.02", "r") as f:
            rom = f.read()
    ram = bytes([int(l,16) for l in open("sram") if l[0] != "/"])
    mem = array.array("H", ram + rom)
    dvg = DVG(mem)
    dvg.run()
    dvg.save("out.png")

if __name__ == "__main__":
    post()

