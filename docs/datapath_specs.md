# Phase 2 Engineering Spec: Datapath Architecture & In-Place Memory Addressing

This document specifies the hardware datapath layout, memory topology, pipeline timing, and memory address generation formulas for the Radix-2 16-bit Q2.14 FFT core.

---

## 1. Top-Level Datapath Architecture

The datapath follows an **In-Place Architecture** where intermediate and final butterfly calculations overwrite the input data in a single Dual-Port Block RAM.

┌────────────────────────┐
                                  │   Twiddle Factor ROM   │
                                  │ (Sine/Cosine Lookups)  │
                                  └───────────┬────────────┘
                                              │ Twiddle (W)
                                              ▼

                                              ┌──────────────┐     Data A     ┌──────────────────────────────┐     Out A'     ┌──────────────┐
│              ├───────────────►│                              ├───────────────►│              │
│  Dual-Port   │                │     Butterfly Processing     │                │  Dual-Port   │
│  Block RAM   │                │            Element           │                │  Block RAM   │
│ (Data Buffer)│     Data B     │  (1 Complex Mult + 2 Adders) │     Out B'     │ (Data Buffer)│
│              ├───────────────►│                              ├───────────────►│              │
└──────┬───────┘                └──────────────────────────────┘                └──────▲───────┘
│                                                                               │
└─────────────────────────────────── Read/Write ────────────────────────────────┘
In-Place Memory

---

## 2. Core Datapath Modules

### A. Dual-Port Block RAM (`fft_ram.v`)
* **Storage Size:** $N \times 32\text{ bits}$ (16 bits Real + 16 bits Imaginary per address in Q2.14 format).
* **Port Configuration:** Dual synchronous ports (Port A and Port B).
* **Operation:** Reads pair data $(A, B)$ simultaneously on a single clock cycle, and receives written output pair $(A', B')$ at the same address locations following pipeline execution.

### B. Twiddle Factor Lookup ROM (`twiddle_rom.v`)
* **Storage Size:** $\frac{N}{2} \times 32\text{ bits}$ (16 bits Real + 16 bits Imaginary per address).
* **Data Content:** Pre-calculated fixed-point trigonometric values $W_N^k = \cos\left(\frac{2\pi k}{N}\right) - j\sin\left(\frac{2\pi k}{N}\right)$ generated in Q2.14 format.

### C. Butterfly Execution Core (`butterfly.v`)
* **Arithmetic Units:** 1 Complex Multiplier (4 real multipliers + 2 real adders/subtractors) and 2 Complex Adders/Subtractors.
* **Truncation:** Bit slice `[29:14]` extracted from 32-bit Q4.28 multiplier product to maintain 16-bit Q2.14 alignment.
* **Scaling:** 1-bit Arithmetic Right Shift (`>>> 1`) applied to butterfly outputs to prevent multi-stage overflow:
  $$A' = \frac{A + (B \cdot W)}{2}$$
  $$B' = \frac{A - (B \cdot W)}{2}$$

### D. Address Generation Logic (`address_generator.v`)
Generates RAM read addresses $A$ and $B$ along with Twiddle ROM index $k$ as a function of stage index $S$ and pass index $P$.

---

## 3. Mathematical Memory Addressing Formulas

For an $N$-point FFT at Stage $S \in [0, \log_2 N - 1]$ and Pass $P \in [0, \frac{N}{2} - 1]$:

* **Group Size:** $2^{S+1}$
* **Address Span (Distance between $A$ and $B$):** $2^S$
* **Group Index:** $\lfloor P / 2^S \rfloor$
* **Element Offset:** $P \pmod{2^S}$
* **Address A:** $(\text{Group Index} \times 2^{S+1}) + \text{Element Offset}$
* **Address B:** $\text{Address A} + 2^S$
* **Twiddle Index ($k$):** $\text{Element Offset} \times \left(\frac{N}{2^{S+1}}\right)$

### 8-Point Address Mapping Table ($N = 8$):

| Stage ($S$) | Span ($2^S$) | Address Pairs $(A, B)$ | Twiddle Factor Indices ($k$) |
|---|---|---|---|
| **Stage 0** | $1$ | $(0,1),\ (2,3),\ (4,5),\ (6,7)$ | $0,\ 2,\ 0,\ 2$ |
| **Stage 1** | $2$ | $(0,2),\ (1,3),\ (4,6),\ (5,7)$ | $0,\ 1,\ 0,\ 1$ |
| **Stage 2** | $4$ | $(0,4),\ (1,5),\ (2,6),\ (3,7)$ | $0,\ 1,\ 2,\ 3$ |

---

## 4. Pipeline Execution & Memory Timing Alignment

Because complex multiplication inside the Butterfly unit contains internal registers, execution incurs a **3-clock cycle pipeline latency**:

Clock Cycle:   |  N  | N+1 | N+2 | N+3 | N+4 |
---------------+-----+-----+-----+-----+-----+
RAM Read:      | R(A,B) ...
Mult Stage:          | P = B*W ...
Add/Scale:                 | A', B' Calculated ...
RAM Write:                       | W(A',B') ...