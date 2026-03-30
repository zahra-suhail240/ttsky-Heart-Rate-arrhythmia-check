![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)
## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [LibreLane](https://www.zerotoasiccourse.com/terminology/librelane/).

# ❤️ Real-Time Heart Rate Arrhythmia Detection (Tiny Tapeout ASIC)

A **Verilog-based ASIC design** for real-time detection and classification of cardiac arrhythmias using **RR-interval analysis**. Developed as part of an ASIC hackathon and targeting the **Tiny Tapeout** flow.

---

## 🚀 Overview

This project implements a **hardware accelerator** that processes heartbeat signals and classifies them into:

- **Bradycardia** → consistently long RR intervals (low heart rate)  
- **Tachycardia** → consistently short RR intervals (high heart rate)  
- **Irregular rhythms** → high variability between consecutive beats  

The system operates in **real time**, producing:
- **Live classification outputs**
- **Probability/likelihood estimates** across arrhythmia types

---

## 🧠 Key Concept

Heart rate is derived directly from RR intervals:

> **BPM ≈ 60 / RR (seconds)**

### Examples
- RR = 1.0s → 60 BPM (normal)  
- RR = 0.5s → 120 BPM (tachycardia)  
- RR = 1.2s → 50 BPM (bradycardia)  

Arrhythmias are identified through **patterns in RR intervals**:
- **Bradycardia** → consistently long intervals  
- **Tachycardia** → consistently short intervals  
- **Irregular rhythms** → high beat-to-beat variability  
- **Extrasystoles** → sudden abnormal spikes (very short/long RR)

---

## 🏗️ Architecture

The design is implemented as a **modular RTL system**:

### 🔹 Top-Level (50 MHz system clock)
- Integrates all submodules
- Coordinates signal flow and classification

### 🔹 Core Modules

- **Interval Detection**  
  Measures time between consecutive heartbeats and converts pulse input → RR interval

- **Clock Divider**  
  Generates timing resolution for interval measurement

- **Live Arrhythmia Comparator**  
  Classifies each heartbeat in real time:  
  - Tachycardia → RR < 0.6s  
  - Normal → 0.6s ≤ RR ≤ 1.0s  
  - Bradycardia → RR > 1.0s  

- **Statistics / Counter Module**  
  Tracks total beats and counts per arrhythmia type

- **Final Analysis Module**  
  Computes **probability/likelihood distribution** for all arrhythmia types

---

## ⚙️ Input / Output

### Input
- Simulated **digital heartbeat signal** (pulse stream)  
- *(Planned)*: raw ECG signal via ADC

### Output
- Real-time classification flags: Bradycardia / Tachycardia / Irregular  
- Running statistics: beat counts per category  
- Final output: **probability distribution across arrhythmia types**

---

## 🧪 Verification

- Designed using **synthesizable Verilog RTL**  
- Verified with **testbenches and simulation**  
- Validated:
  - Accurate RR interval detection  
  - Correct classification across edge cases  
  - Stable operation under varying heartbeat patterns  

---

## 🧩 ASIC Flow (Tiny Tapeout)

Prepared for:
- **RTL → Synthesis → Place & Route**  
- Integration into the **Tiny Tapeout** ASIC pipeline

Focus:
- Clean, synthesizable RTL  
- Modular design for scalability  
- Compatibility with constrained silicon area  

---

## 🔮 Future Work

- Integrate **ADC + raw ECG input**  
- Improve classification using statistical variance models and sliding-window analysis  
- Add support for additional arrhythmias (e.g., atrial fibrillation)  
- Optimize for **area and power efficiency**  

---

## 🛠️ Tech Stack

- **Hardware Description**: Verilog  
- **Simulation/Verification**: Testbenches (ModelSim or equivalent)  
- **ASIC Flow**: Tiny Tapeout  



## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
