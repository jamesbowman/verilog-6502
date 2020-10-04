import zipfile

def prepare():
    with zipfile.ZipFile("asteroids_rom_2.zip") as z:
        for fn in "035127.02 035143.02 035144.02 035145.02".split():
            with z.open(fn, "r") as f:
                binary = f.read()
                with open(fn + ".hex", "wt") as h:
                    for b in binary:
                        h.write("%02x\n" % b)

if __name__ == "__main__":
    prepare()
