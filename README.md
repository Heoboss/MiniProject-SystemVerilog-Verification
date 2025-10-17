# 🔬 UART + FIFO Controller & SystemVerilog Verification Environment

> UART 및 FIFO Controller를 Verilog/SystemVerilog로 설계하고, SystemVerilog의 객체 지향 프로그래밍(OOP)과 Randomization 기능을 활용하여 기능 및 예외 상황에 대한 검증 환경(Testbench)을 구축한 프로젝트입니다.

---

## 📜 목차
1. [**프로젝트 목표**](#-프로젝트-목표)
2. [**사용 기술 및 환경**](#-사용-기술-및-환경)
3. [**시스템 아키텍처**](#-시스템-아키텍처)
4. [**검증 환경**](#검증-환경)
5. [**검증 시나리오 및 결과**](#-검증-시나리오-및-결과)
6. [**트러블슈팅 및 고찰**](#-트러블슈팅-및-고찰)

---

## 🚀 프로젝트 목표
본 프로젝트의 목표는 Verilog와 SystemVerilog를 이용해 **UART 통신 기반의 스톱워치 컨트롤러를 설계**하고, **SystemVerilog를 활용한 체계적인 검증 환경을 구축**하여 설계된 하드웨어(DUT)의 기능적 정확성과 안정성을 검증하는 것입니다.

### DUT (Device Under Test)의 주요 기능
- **UART 통신**: PC 또는 외부 컨트롤러와 UART 프로토콜을 통해 데이터를 송수신합니다.
- **스톱워치 제어**: UART 통신 또는 외부 버튼 입력을 통해 스톱워치의 Count Up/Down, Run/Stop, Clear 기능을 제어합니다.
- **7-Segment 출력**: 스톱워치의 현재 값을 7-Segment 디스플레이에 표시합니다.
- **FIFO 버퍼링**: 송신(TX) 및 수신(RX) 데이터 경로에 FIFO(First-In, First-Out) 메모리를 적용하여 데이터 흐름을 안정적으로 관리합니다.

---

## 🔨 사용 기술 및 환경

| 구분 | 기술 |
|---|---|
| **설계 언어** | `Verilog`, `SystemVerilog` |
| **검증 언어** | `SystemVerilog` |
| **시뮬레이션 툴** | `Vivado Simulator` |

---

## 🔧 시스템 아키텍처

### 전체 시스템 블록 다이어그램
> UART 컨트롤러와 스톱워치, 그리고 외부 버튼 입력이 결합된 전체 시스템의 구조입니다.

<img width="800" height="333" alt="image" src="https://github.com/user-attachments/assets/e3295b85-e5cf-4326-8b78-76dc161cfbb4" />


- **UART + FIFO**: PC와의 비동기 직렬 통신 및 데이터 버퍼링을 담당합니다.
- **Control Unit**: UART로부터 수신된 데이터를 해석하여 스톱워치 제어 신호(enable, mode, clear)를 생성합니다.
- **Button Debounce**: 물리적 버튼 입력 시 발생하는 채터링 노이즈를 제거하여 안정적인 신호를 Control Unit에 전달합니다.
- **StopWatch**: 실제 카운팅 로직을 수행하고 7-Segment에 표시할 데이터를 출력합니다.

### UART 상세 블록 다이어그램
> UART Controller 내부의 RX, TX 경로와 FIFO, 그리고 Testbench와의 연결 관계를 보여줍니다.

<img width="800" height="474" alt="image" src="https://github.com/user-attachments/assets/ba6a9f88-8dbf-4d41-9284-17dbd9754939" />


---

## 검증 환경

SystemVerilog의 클래스 기반 객체 지향 프로그래밍을 활용하여 재사용 가능하고 유연한 테스트벤치 환경을 구축했습니다.

<img width="779" height="828" alt="image" src="https://github.com/user-attachments/assets/02fa1331-ff41-4ac7-8141-2c389e05cd59" />


- **Transaction**: 데이터 패킷의 기본 단위 클래스. 전송할 데이터, Start/Stop 비트, 예외 상황 플래그 등을 포함합니다.
- **Generator**: 테스트 시나리오에 맞는 Transaction을 생성합니다. (예: 랜덤 데이터, 예외 상황 데이터)
- **Driver**: Generator로부터 Transaction을 받아 DUT의 입력 포맷에 맞게 신호를 인가합니다.
- **Monitor**: DUT의 출력 신호를 감지하여 Transaction 형태로 변환합니다.
- **Scoreboard**: Driver가 보낸 원본 데이터와 Monitor가 수집한 결과 데이터를 비교하여 Pass/Fail을 판정합니다.
- **Mailbox**: Generator, Driver, Scoreboard 간의 Transaction 데이터 전달을 위한 통신 채널입니다.
- **Interface**: DUT와 검증 환경 간의 신호 연결을 간소화합니다.

---

## ✨ 검증 시나리오 및 결과

### 시나리오 1: 정상 동작 검증 (Random Data 전송)
- **목표**: 0부터 255까지의 모든 데이터(256개)를 랜덤 순서로 전송했을 때, DUT가 오류 없이 데이터를 Loop-back하는지 확인합니다.
- **실행**: Generator가 0~255 범위의 데이터를 랜덤하게 생성하여 Driver에 전달하고, Scoreboard는 송신 데이터와 수신 데이터가 일치하는지 비교합니다.
- **결과**:

<img width="524" height="292" alt="image" src="https://github.com/user-attachments/assets/7a16cfa2-a25f-48b3-9b81-2901358f4d25" />

- **분석**: 256개의 모든 데이터가 오류 없이 송수신되었으며, 100%의 데이터 커버리지를 달성하여 정상적인 데이터 전송 기능이 완벽함을 확인했습니다.

### 시나리오 2: 예외 상황 검증 (Negative Testing)
- **목표**: UART 프로토콜을 위반하는 비정상적인 데이터(잘못된 Start/Stop 비트, 'x'/'z' 데이터 등)를 입력했을 때 DUT가 어떻게 반응하는지 확인하여 시스템의 강건성(Robustness)을 검증합니다.
- **실행**: Generator가 48개의 비정상적인 데이터(강건성 벡터)와 256개의 정상 데이터를 함께 생성하여 전송합니다. Scoreboard는 정상 데이터에 대해서만 Pass를 기대합니다.
- **결과**:

<img width="524" height="497" alt="image" src="https://github.com/user-attachments/assets/4733adb5-7fb4-415c-a8c7-3c7359620b4f" />

<img width="737" height="385" alt="image" src="https://github.com/user-attachments/assets/0ec35eb1-8254-4564-9d27-51a9a839df96" />


- **분석**: 의도적으로 주입한 오류 중 3개의 케이스에서 Fail이 발생했음을 Scoreboard가 정확히 탐지했습니다. 이는 **검증 환경이 예상치 못한 오류를 올바르게 잡아내고 있음을 의미**하며, 동시에 **설계된 DUT가 프로토콜 위반 상황에 대해서는 완벽하게 대응하지 못함**을 발견했습니다. 이를 통해 향후 설계 보완점을 명확히 할 수 있었습니다.


---

## 🔧 트러블슈팅 및 고찰

- **시뮬레이션 시간 단축**: 초기 `fork-join_any` 기반의 이벤트 제어 방식에서 `fork-join_none`을 사용한 병렬 프로세스 실행 방식으로 변경하여, 전체 시뮬레이션 시간을 약 46% 단축했습니다. 이를 통해 검증 사이클의 효율성을 크게 향상시킬 수 있었습니다.
- **Tool의 한계점과 극복**: 사용한 시뮬레이션 툴에서 SystemVerilog의 `shuffle()` 메소드가 지원되지 않는 문제를 발견했습니다. 이를 해결하기 위해 Fisher-Yates 알고리즘을 기반으로 직접 `shuffle` 로직을 구현하여 테스트 데이터의 Randomness를 확보했습니다.
- **OOP 개념의 중요성**: Generator 클래스에서 Environment의 변수를 참조해야 할 때 `'environment' is not declared` 오류가 발생했습니다. 이는 클래스 간의 의존성 문제로, `typedef`를 통해 클래스를 전방 선언(forward declaration)하여 컴파일 순서에 따른 종속성 문제를 해결하며 OOP 설계의 중요성을 체감했습니다.
