# Phase 3 Engineering Spec: FSM State Machine & Control Architecture

This document specifies the Finite State Machine (FSM) state transitions, control signal assignments, and interface protocols for the FFT controller core.

---

## 1. Top-Level Interface Signals

| Signal Name | Direction | Bit Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | System clock signal |
| `rst_n` | Input | 1 | Asynchronous active-low reset |
| `start` | Input | 1 | External trigger signal to initiate FFT execution |
| `busy` | Output | 1 | High whenever core is actively loading or calculating |
| `done` | Output | 1 | Single-cycle pulse asserted when full FFT computation finishes |
| `stage_cnt` | Output | $\lceil \log_2(\log_2 N) \rceil$ | Current FFT stage index ($0 \dots \log_2 N - 1$) |
| `pass_cnt` | Output | $\log_2(N/2)$ | Current butterfly pass index ($0 \dots N/2 - 1$) |

---

## 2. FSM State Transition Diagram

┌───────────────┐
              │    S_IDLE     │◄───────────────────┐
              └───────┬───────┘                    │
                      │ start == 1                 │
                      ▼                            │
              ┌───────────────┐                    │
              │    S_LOAD     │                    │
              └───────┬───────┘                    │
                      │ Load complete              │
                      ▼                            │
              ┌───────────────┐                    │
┌─────────────►│   S_COMPUTE   │                    │
│              └───────┬───────┘                    │
│                      │ Pass counter == (N/2 - 1)  │
│                      ▼                            │
│ Stage < log2(N)-1  ┌───────────────┐              │
└────────────────────┤  S_STAGE_END  │              │
└───────┬───────┘              │
│ Stage == log2(N) - 1 │
▼                      │
┌───────────────┐              │
│    S_DONE     │──────────────┘
└───────────────┘

## 3. State Definitions & Behavioral Rules

### 1. `S_IDLE` (`3'b000`)
* **Description:** Default reset state. Core waits for start assertion.
* **Outputs:** `busy = 0`, `done = 0`, RAM `write_enable = 0`.
* **Transitions:** Transitions to `S_LOAD` on `start == 1`. Resets `stage_cnt <= 0` and `pass_cnt <= 0`.

### 2. `S_LOAD` (`3'b001`)
* **Description:** Input streaming state. Writes incoming time-domain samples into Dual-Port Block RAM.
* **Address Bit-Reversal:** Input samples can be written in bit-reversed address order during this phase to allow natural-order output reading.
* **Transitions:** Transitions to `S_COMPUTE` when $N$ input samples are stored.

### 3. `S_COMPUTE` (`3'b010`)
* **Description:** Core pipeline execution loop. Issues read addresses $A$ and $B$ every clock cycle.
* **Counters:** Increments `pass_cnt` on every clock edge.
* **Transitions:** When `pass_cnt == (N/2 - 1)`, all butterfly operations for the current stage have been issued. Transitions to `S_STAGE_END`.

### 4. `S_STAGE_END` (`3'b011`)
* **Description:** Pipeline flushing and stage boundary state.
* **Latency Stall:** Waits 3 clock cycles for final pipeline writes to flush into RAM.
* **Transitions:**
  * If `stage_cnt < log2(N) - 1`: Increments `stage_cnt <= stage_cnt + 1`, resets `pass_cnt <= 0`, and returns to `S_COMPUTE`.
  * If `stage_cnt == log2(N) - 1`: All stages finished; transitions to `S_DONE`.

### 5. `S_DONE` (`3'b100`)
* **Description:** Completion state.
* **Outputs:** Asserts `done = 1` for 1 clock cycle and sets `busy = 0`.
* **Transitions:** Automatically transitions back to `S_IDLE` on the next clock cycle.