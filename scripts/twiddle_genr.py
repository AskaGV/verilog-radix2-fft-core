import numpy as np
import sys
import os

BITS = 14 # Q2.14 : fractional bits;

#default to 32 point DFT oif argument is not provided
N = int(sys.argv[1]) if len(sys.argv) > 1 else 32 

output_path = "twiddle.hex"
with open(output_path, "w") as f:
    for k in range(N // 2):
        angle = -2.0 * np.pi * k / N
        cos_val = int(round(np.cos(angle) * (1 << BITS)))
        sin_val = int(round(np.sin(angle) * (1 << BITS)))
        
        # Mask to 16-bit 2's complement hex
        cos_hex = f"{(cos_val & 0xFFFF):04X}"
        sin_hex = f"{(sin_val & 0xFFFF):04X}"
        
        # Write packed 32-bit word: [REAL_IMAG]
        f.write(f"{cos_hex}{sin_hex}\n")

print(f"Successfully generated {output_path} for N = {N}")