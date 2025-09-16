# 🔬 UART + FIFO Controller & SystemVerilog Verification Environment

<br>

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-1800--2017-134372?style=for-the-badge&logo=ieee&logoColor=white)
![Verilog](https://img.shields.io/badge/VerilogHDL-8E44AD?style=for-the-badge)

> UART 및 FIFO Controller를 Verilog/SystemVerilog로 설계하고, SystemVerilog의 객체 지향 프로그래밍(OOP)과 Randomization 기능을 활용하여 기능 및 예외 상황에 대한 검증 환경(Testbench)을 구축한 프로젝트입니다.

<br>

### 프로젝트 시뮬레이션 결과
> 💡 **Tip**


<br>

## 📜 목차
1. [**프로젝트 소개**](#1-프로젝트-소개)
2. [**기술 스택**](#2-기술-스택)
3. [**시스템 아키텍처**](#3-시스템-아키텍처)
4. [**검증 환경**](#4-검증-환경)
5. [**검증 시나리오 및 결과**](#5-검증-시나리오-및-결과)
6. [**트러블슈팅 및 고찰**](#6-트러블슈팅-및-고찰)

<br>

## 1. 프로젝트 소개

### 프로젝트 목표
본 프로젝트의 목표는 Verilog와 SystemVerilog를 이용해 **UART 통신 기반의 스톱워치 컨트롤러를 설계**하고, **SystemVerilog를 활용한 체계적인 검증 환경을 구축**하여 설계된 하드웨어(DUT)의 기능적 정확성과 안정성을 검증하는 것입니다.

### DUT (Device Under Test)의 주요 기능
- **UART 통신**: PC 또는 외부 컨트롤러와 UART 프로토콜을 통해 데이터를 송수신합니다.
- **스톱워치 제어**: UART 통신 또는 외부 버튼 입력을 통해 스톱워치의 Count Up/Down, Run/Stop, Clear 기능을 제어합니다.
- **7-Segment 출력**: 스톱워치의 현재 값을 7-Segment 디스플레이에 표시합니다.
- **FIFO 버퍼링**: 송신(TX) 및 수신(RX) 데이터 경로에 FIFO(First-In, First-Out) 메모리를 적용하여 데이터 흐름을 안정적으로 관리합니다.

<br>

## 2. 기술 스택

| 구분 | 기술 |
|---|---|
| **설계 언어** | `Verilog`, `SystemVerilog` |
| **검증 언어** | `SystemVerilog` |
| **시뮬레이션 툴** | `QuestaSim`, `Vivado Simulator` 등 |

<br>

## 3. 시스템 아키텍처

### 전체 시스템 블록 다이어그램
> UART 컨트롤러와 스톱워치, 그리고 외부 버튼 입력이 결합된 전체 시스템의 구조입니다.

![전체 시스템 블록 다이어그램](https://i.imgur.com/your-block-diagram-image.png)

- **UART + FIFO**: PC와의 비동기 직렬 통신 및 데이터 버퍼링을 담당합니다.
- **Control Unit**: UART로부터 수신된 데이터를 해석하여 스톱워치 제어 신호(enable, mode, clear)를 생성합니다.
- **Button Debounce**: 물리적 버튼 입력 시 발생하는 채터링 노이즈를 제거하여 안정적인 신호를 Control Unit에 전달합니다.
- **StopWatch**: 실제 카운팅 로직을 수행하고 7-Segment에 표시할 데이터를 출력합니다.

### UART 상세 블록 다이어그램
> UART Controller 내부의 RX, TX 경로와 FIFO, 그리고 Testbench와의 연결 관계를 보여줍니다.

![UART 상세 블록 다이어그램](https://i.imgur.com/your-uart-diagram-image.png)

<br>

## 4. 검증 환경

SystemVerilog의 클래스 기반 객체 지향 프로그래밍을 활용하여 재사용 가능하고 유연한 테스트벤치 환경을 구축했습니다.

![검증 환경 블록 다이어그램](https://i.imgur.com/your-verification-env-image.png)

- **Transaction**: 데이터 패킷의 기본 단위 클래스. 전송할 데이터, Start/Stop 비트, 예외 상황 플래그 등을 포함합니다.
- **Generator**: 테스트 시나리오에 맞는 Transaction을 생성합니다. (예: 랜덤 데이터, 예외 상황 데이터)
- **Driver**: Generator로부터 Transaction을 받아 DUT의 입력 포맷에 맞게 신호를 인가합니다.
- **Monitor**: DUT의 출력 신호를 감지하여 Transaction 형태로 변환합니다.
- **Scoreboard**: Driver가 보낸 원본 데이터와 Monitor가 수집한 결과 데이터를 비교하여 Pass/Fail을 판정합니다.
- **Mailbox**: Generator, Driver, Scoreboard 간의 Transaction 데이터 전달을 위한 통신 채널입니다.
- **Interface**: DUT와 검증 환경 간의 신호 연결을 간소화합니다.

<br>

## 5. 검증 시나리오 및 결과

### 시나리오 1: 정상 동작 검증 (Random Data 전송)
- **목표**: 0부터 255까지의 모든 데이터(256개)를 랜덤 순서로 전송했을 때, DUT가 오류 없이 데이터를 Loop-back하는지 확인합니다.
- **실행**: Generator가 0~255 범위의 데이터를 랜덤하게 생성하여 Driver에 전달하고, Scoreboard는 송신 데이터와 수신 데이터가 일치하는지 비교합니다.
- **결과**:
