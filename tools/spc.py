"""Tiny SPC700 assembler (just the instructions the sound driver uses).

Usage: a = Asm(0x200); a.label('x'); a.mov_a_imm(5); ...; a.link() -> bytes
Operands that are labels are resolved at link time.
"""

class Asm:
    def __init__(self, org):
        self.org = org
        self.code = bytearray()
        self.labels = {}
        self.fix = []   # (offset, kind, label)

    # ------------------------------------------------------------ core
    def pc(self):
        return self.org + len(self.code)

    def label(self, name):
        assert name not in self.labels, name
        self.labels[name] = self.pc()

    def b(self, *bs):
        for x in bs:
            self.code.append(x & 0xFF)

    def w16(self, v):
        if isinstance(v, str):
            self.fix.append((len(self.code), 'abs', v))
            self.b(0, 0)
        else:
            self.b(v & 0xFF, v >> 8)

    def rel(self, target):
        self.fix.append((len(self.code), 'rel', target))
        self.b(0)

    def data(self, bs):
        self.code += bytes(bs)

    def words(self, vals):
        for v in vals:
            self.w16(v)

    def resolve(self, lab):
        import re
        m = re.match(r'^([A-Za-z_][\w]*)([+-]\d+)?$', lab)
        assert m and m.group(1) in self.labels, 'undefined label ' + lab
        return self.labels[m.group(1)] + int(m.group(2) or 0)

    def link(self):
        for off, kind, lab in self.fix:
            t = self.resolve(lab)
            if kind == 'abs':
                self.code[off] = t & 0xFF
                self.code[off + 1] = t >> 8
            else:
                d = t - (self.org + off + 1)
                assert -128 <= d <= 127, 'branch out of range to ' + lab
                self.code[off] = d & 0xFF
        return bytes(self.code)

    # ------------------------------------------------------------ moves
    def mov_a_imm(self, v): self.b(0xE8, v)
    def mov_x_imm(self, v): self.b(0xCD, v)
    def mov_y_imm(self, v): self.b(0x8D, v)
    def mov_a_x(self): self.b(0x7D)
    def mov_a_y(self): self.b(0xDD)
    def mov_x_a(self): self.b(0x5D)
    def mov_y_a(self): self.b(0xFD)
    def mov_sp_x(self): self.b(0xBD)
    def mov_a_dp(self, d): self.b(0xE4, d)
    def mov_a_dpx(self, d): self.b(0xF4, d)
    def mov_a_abs(self, a): self.b(0xE5); self.w16(a)
    def mov_a_absx(self, a): self.b(0xF5); self.w16(a)
    def mov_a_absy(self, a): self.b(0xF6); self.w16(a)
    def mov_a_indy(self, d): self.b(0xF7, d)       # A = [dp]+Y
    def mov_x_dp(self, d): self.b(0xF8, d)
    def mov_y_dp(self, d): self.b(0xEB, d)
    def mov_y_dpx(self, d): self.b(0xFB, d)
    def mov_dp_a(self, d): self.b(0xC4, d)
    def mov_dpx_a(self, d): self.b(0xD4, d)
    def mov_abs_a(self, a): self.b(0xC5); self.w16(a)
    def mov_absx_a(self, a): self.b(0xD5); self.w16(a)
    def mov_dp_x(self, d): self.b(0xD8, d)
    def mov_dp_y(self, d): self.b(0xCB, d)
    def mov_dp_imm(self, d, v): self.b(0x8F, v, d)
    def mov_dp_dp(self, dst, src): self.b(0xFA, src, dst)
    def movw_ya_dp(self, d): self.b(0xBA, d)
    def movw_dp_ya(self, d): self.b(0xDA, d)
    def addw_ya_dp(self, d): self.b(0x7A, d)
    def incw_dp(self, d): self.b(0x3A, d)

    # ------------------------------------------------------------ alu
    def adc_a_imm(self, v): self.b(0x88, v)
    def adc_a_dp(self, d): self.b(0x84, d)
    def adc_a_dpx(self, d): self.b(0x94, d)
    def sbc_a_imm(self, v): self.b(0xA8, v)
    def cmp_a_imm(self, v): self.b(0x68, v)
    def cmp_a_dp(self, d): self.b(0x64, d)
    def cmp_x_imm(self, v): self.b(0xC8, v)
    def cmp_y_imm(self, v): self.b(0xAD, v)
    def and_a_imm(self, v): self.b(0x28, v)
    def and_a_dp(self, d): self.b(0x24, d)
    def or_a_imm(self, v): self.b(0x08, v)
    def or_a_dp(self, d): self.b(0x04, d)
    def eor_a_imm(self, v): self.b(0x48, v)
    def inc_a(self): self.b(0xBC)
    def dec_a(self): self.b(0x9C)
    def inc_x(self): self.b(0x3D)
    def dec_x(self): self.b(0x1D)
    def inc_y(self): self.b(0xFC)
    def dec_y(self): self.b(0xDC)
    def inc_dp(self, d): self.b(0xAB, d)
    def dec_dp(self, d): self.b(0x8B, d)
    def inc_dpx(self, d): self.b(0xBB, d)
    def dec_dpx(self, d): self.b(0x9B, d)
    def asl_a(self): self.b(0x1C)
    def lsr_a(self): self.b(0x5C)
    def xcn_a(self): self.b(0x9F)
    def clrc(self): self.b(0x60)
    def setc(self): self.b(0x80)

    # ------------------------------------------------------------ flow
    def bra(self, t): self.b(0x2F); self.rel(t)
    def beq(self, t): self.b(0xF0); self.rel(t)
    def bne(self, t): self.b(0xD0); self.rel(t)
    def bcs(self, t): self.b(0xB0); self.rel(t)
    def bcc(self, t): self.b(0x90); self.rel(t)
    def bmi(self, t): self.b(0x30); self.rel(t)
    def bpl(self, t): self.b(0x10); self.rel(t)
    def jmp(self, t): self.b(0x5F); self.w16(t)
    def call(self, t): self.b(0x3F); self.w16(t)
    def ret(self): self.b(0x6F)
    def push_a(self): self.b(0x2D)
    def push_x(self): self.b(0x4D)
    def push_y(self): self.b(0x6D)
    def pop_a(self): self.b(0xAE)
    def pop_x(self): self.b(0xCE)
    def pop_y(self): self.b(0xEE)

    # ------------------------------------------------------------ helpers
    def dsp_imm(self, reg, val):
        self.mov_dp_imm(0xF2, reg)
        self.mov_dp_imm(0xF3, val)

    def dsp_a(self, reg):
        """DSP[reg] = A (reg constant)"""
        self.mov_dp_imm(0xF2, reg)
        self.mov_dp_a(0xF3)
