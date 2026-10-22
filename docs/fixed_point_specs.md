# Engineering Design Report: Fixed-Point Arithmetic & Precision Rules for Verilog FFT

This report documents the numerical representation, mathematical foundations, bit-width growth rules, and precision trade-offs established during **Phase 1** of our hardware implementation plan.

---

## 1. Executive Summary & Core Definitions

### What Type of Number Format Are We Using?
We are using a **Signed Fixed-Point Representation** structured as **Q2.14** within a 16-bit register.

| Property | Value / Specification |
|---|---|
| **Total Register Width** | 16 bits (`[15:0]`) |
| **Format Notation** | **Q2.14** (2's complement) |
| **Sign Bit** | 1 bit (`[15]`) |
| **Integer Bits** | 1 bit (`[14]`) |
| **Fractional Bits** | 14 bits (`[13:0]`) |
| **Dynamic Range** | $-2.0 \le x \le +1.99993895$ |
| **Resolution / Precision** | $2^{-14} = \frac{1}{16384} \approx 0.000061035$ |

### Mathematical Formula for Quantization
To convert any real decimal number $X_{decimal}$ into a 16-bit Q2.14 integer $X_{fixed}$:

$$X_{fixed} = \text{round}\left( X_{decimal} \cdot 2^{14} \right)$$

---

## 2. Why Fixed-Point (Q2.14) Instead of Floating-Point?

When designing digital signal processing (DSP) hardware on FPGAs or ASICs, choosing the number format involves a direct trade-off between hardware area/power and numerical flexibility:

1. **Hardware Efficiency:** Floating-point units (FPUs) require complex mantissa alignment, exponent subtraction, and normalization circuits. Fixed-point operations use standard integer multipliers and adders, directly matching the dedicated DSP slices inside modern FPGAs.
2. **Deterministic Latency:** Fixed-point operations execute in predictable, single-cycle or fixed pipeline stages without variable clock delays.

---

## 3. Engineering Problems Solved by Q2.14

### Problem A: Overflow Protection during Complex Multiplication
In a Radix-2 FFT, the Butterfly unit computes a complex product $B \cdot W$, where $B$ is the input data point and $W = \cos(\theta) - j\sin(\theta)$ is the Twiddle Factor.

$$\text{Real Part: } P_{real} = (B_{real} \cdot W_{real}) - (B_{imag} \cdot W_{imag})$$

Because $W_{real}$ and $W_{imag}$ can be up to $1.0$, the worst-case subtraction $(+1.0) - (-1.0) = 2.0$ would immediately cause overflow in a standard Q1.15 format (which caps at $+0.9999$). 

* **The Solution:** **Q2.14** provides 2 integer bits, extending the range to $[-2.0, +1.9999]$. This guarantees that intermediate complex products never overflow.

### Problem B: Bit Growth across Multi-Stage Additions
Each stage of an FFT performs additions of the form $A' = A + (B \cdot W)$. Adding two signed numbers increases the required bit-width by 1 bit. 

* **The Solution:** Rather than expanding register widths at every stage (which would grow memory width from 16 bits to 24+ bits for larger $N$), we apply a **1-bit Arithmetic Right Shift (`>>> 1`)** at the output of every Butterfly unit. This divides the result by 2, keeping the data word size fixed at 16 bits throughout the system.

---

## 4. Consolidated Technical Q&A Log

---

### Question 1: How does 16-bit Q2.14 integer multiplication result in redundant sign bits? Why are there two redundant bits, and how do we know bits `[31:30]` mirror each other?

#### Engineering Answer:
When two 16-bit signed (2's complement) numbers are multiplied, hardware generates a 32-bit output container (bits `[31:0]`).

1. **Range Bounds:**
   * Minimum 16-bit value: $-32,768$ (`0x8000`)
   * Maximum 16-bit value: $+32,767$ (`0x7FFF`)
2. **Maximum Positive Output:**
   $$(-32,768) \times (-32,768) = +1,073,741,824 = \text{\texttt{32'b0010\_0000\_0000\_0000\_0000\_0000\_0000\_0000}}$$
   Notice that bits `31` and `30` are both **`0`**. A full 32-bit container could hold values up to $+2,147,483,647$, but a 16-bit multiplication can never reach that capacity. Bit `30` never turns into a `1` for any positive product.
3. **Maximum Negative Output:**
   $$(-32,768) \times (+32,767) = -1,073,709,056 = \text{\texttt{32'b1101\_1111\_1111\_1111\_1111\_0000\_0000\_0000}}$$
   Notice that bits `31` and `30` are both **`1`** due to 2's complement sign-extension.

Because no combination of two 16-bit signed numbers can generate a magnitude large enough to alter bit `30` independently of bit `31`, **bits `[31:30]` are mathematically identical duplicates of the sign bit**.

---

### Question 2: Why extract bits `[29:14]` specifically when truncating 32-bit products back to 16-bit Q2.14?

#### Engineering Answer:
Multiplying two Q2.14 numbers produces a Q4.28 result ($2+2=4$ integer bits, $14+14=28$ fractional bits):

$$\text{Q2.14} \times \text{Q2.14} = \text{Q4.28 (32 bits)}$$

* **Bit 31:** Redundant sign bit (discarded).
* **Bit 30:** True sign bit.
* **Bits `[29:28]`:** Integer bits.
* **Bits `[27:14]`:** The top 14 fractional bits.

Taking bits **`[29:14]`** isolates 1 true sign bit, 1 integer bit, and 14 fractional bits—restoring the exact **Q2.14 structure** while discarding lower precision bits (`[13:0]`).

---

### Question 3: Why choose Q2.14 over Q1.15 if input numbers stay within $[-1.0, +1.0]$?

#### Engineering Answer:
While normalized inputs and Twiddle factors ($W_N^k = \cos\theta - j\sin\theta$) are strictly bounded by $[-1.0, +1.0]$, **intermediate butterfly calculations exceed $1.0$**.

For instance, during complex cross-multiplication:
$$P_{real} = (B_{real} \cdot W_{real}) - (B_{imag} \cdot W_{imag})$$

If $B_{real} = 0.707$, $W_{real} = 0.707$, $B_{imag} = -0.707$, and $W_{imag} = 0.707$:
$$P_{real} = (0.707 \cdot 0.707) - (-0.707 \cdot 0.707) = 0.5 - (-0.5) = +1.0$$

In Q1.15, $+1.0$ cannot be represented (max value is $+0.999939$), resulting in wrap-around overflow to $-1.0$. The extra integer bit in **Q2.14** provides the headroom needed to prevent intermediate arithmetic overflow.

---

### Question 4: Does scaling down by 1 bit (`>>> 1`) during addition introduce errors in the fractions?

#### Engineering Answer:
**Yes.** Performing an arithmetic right-shift drops bit `0`, which removes the least significant bit (LSB) and introduces **quantization noise** (truncation error).

However, this trade-off is deliberate and standard in hardware design:
* **Alternative 1 (No Scaling):** Register widths would grow by 1 bit per stage. For a 1024-point (10-stage) FFT, register widths would expand from 16 bits to 26 bits, increasing multiplier size and memory bandwidth requirements by over 60%.
* **Alternative 2 (1-Bit Scaling Per Stage):** Register widths remain fixed at 16 bits across all stages, significantly reducing silicon area while maintaining an acceptable Signal-to-Quantization-Noise Ratio (SQNR) for fixed-point systems.

---

## 5. Summary Reference Table

| Value / Operation | Binary Representation | Integer Hex | Fixed-Point Equivalence |
|---|---|---|---|
| **$+1.0$ in Q2.14** | `0100_0000_0000_0000` | `0x4000` | $\frac{16384}{16384} = 1.0$ |
| **$+0.5$ in Q2.14** | `0010_0000_0000_0000` | `0x2000` | $\frac{8192}{16384} = 0.5$ |
| **$-1.0$ in Q2.14** | `1100_0000_0000_0000` | `0xC000` | $\frac{-16384}{16384} = -1.0$ |
| **$0.7071$ ($\frac{1}{\sqrt{2}}$)** | `0010_1101_0100_0001` | `0x2D41` | $\frac{11585}{16384} \approx 0.707092$ |
| **Product Extraction** | Slice `[29:14]` | — | Converts 32-bit Q4.28 $\rightarrow$ 16-bit Q2.14 |
| **Overflow Control** | `Data >>> 1` | — | Arithmetic 1-bit right shift (Divide-by-2) |