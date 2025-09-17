`timescale 1ns / 1ps

parameter BIT_PERIOD = (100_000_000 / 9600) * 10;

typedef class environment;

interface uart_fifo_interface;
    logic clk;
    logic rst;
    logic rx;
    logic tx;
endinterface  //reg_interface

class transaction;
    logic [7:0] rand_wdata;
    logic [7:0] rdata;
    // Start bit와 Stop bit를 제어하기 위한 변수 추가
    // 기본값은 정상적인 UART 통신 값으로 설정
    logic start_bit = 1'b0;
    logic stop_bit  = 1'b1;

    // 이 트랜잭션이 강건성 테스트용인지 표시하는 플래그
    bit is_robustness_vector = 0;  // 기본값은 0 (정상 트랜잭션)

    task display(string name_s);
        // GEN이나 DRV에서 호출된 경우, 송신 데이터(rand_wdata)를 출력
        if (name_s == "GEN" || name_s == "DRV") begin
            $display("[%12d ns] : [%s] : Sent data = 0x%02h, start=%b, stop=%b",
                     $time, name_s, rand_wdata, start_bit, stop_bit);
            // 그 외(MON 등)의 경우, 수신 데이터(rdata)를 출력
        end else begin
            $display("[%12d ns] : [%s] : Received data = 0x%02h", $time,
                     name_s, rdata);
        end
    endtask
endclass

class generator;

    transaction tr;
    environment env;
    mailbox #(transaction) gen2drv_mbox;
    int total_cnt = 0;


    function new(mailbox#(transaction) gen2drv_mbox, environment env);
        this.gen2drv_mbox = gen2drv_mbox;
        this.env          = env;
    endfunction  //new()

    task generate_robustness_vectors();
        logic four_states[4] = '{1'b0, 1'b1, 1'bx, 1'bz};
        logic [7:0] data_patterns[3];

        data_patterns[0] = 8'hxx;  // 모두 X
        data_patterns[1] = 8'hzz;  // 모두 Z
        data_patterns[2] = 8'b10xz_01zx;  // 섞인 경우

        $display("[%12d ns] : [%s] : Generating 4x4x3=48 robustness vectors...",
                 $time, "GEN");

        // 중첩 루프를 사용하여 48개 모든 조합 생성
        foreach (four_states[i]) begin  // Start bit 루프 (4가지)
            foreach (four_states[j]) begin  // Stop bit 루프 (4가지)
                foreach (data_patterns[k]) begin // Data 패턴 루프 (3가지)
                    tr = new();
                    total_cnt++; // 전체 트랜잭션 수 증가
                    tr.is_robustness_vector = 1;

                    tr.start_bit  = four_states[i];
                    tr.stop_bit   = four_states[j];
                    tr.rand_wdata = data_patterns[k];

                    // 검증 1 : start bit가 0 , stop bit가 1일 때만 기대응답 개수 증가
                    if (tr.start_bit === 1'b0 && tr.stop_bit == 1'b1) begin
                        env.expected_responses++;
                        gen2drv_mbox.put(tr);
                        tr.display("GEN");
                    end

                    // 검증 2 : 모든 경우를 mailbox로 전달
                    // env.expected_responses++;
                    // gen2drv_mbox.put(tr);
                    // tr.display("GEN");

                end
            end
        end
    endtask

    // 0~255 모든 값을 섞어서 생성하는 태스크
    task generate_shuffled_vectors();
        int data_q[$];
        for (int i = 0; i < 256; i++) begin
            data_q.push_back(i);
        end

        //직접 shuffle
        for (int i = data_q.size() - 1; i > 0; i--) begin
            int j = $urandom_range(i, 0);
            int temp = data_q[i];
            data_q[i] = data_q[j];
            data_q[j] = temp;
        end

        // XSIM에서 not supported yet
        //data_q.shuffle();

        total_cnt += data_q.size(); // 전체 트랜잭션 수에 추가
        $display(
            "[%12d ns] : [%s] : Generating %0d shuffled transactions (0x00 to 0xFF)...",
            $time, "GEN", total_cnt);

        foreach (data_q[i]) begin
            tr = new();
            tr.rand_wdata = data_q[i];
            // 모든 정상 데이터는 응답을 기대하므로 env의 카운터 증가
            if (tr.start_bit === 1'b0 && tr.stop_bit === 1'b1)
                env.expected_responses++;
            gen2drv_mbox.put(tr);
            tr.display("GEN");
        end
    endtask

    // 메인 실행 태스크
    task run();
        total_cnt = 0;  // 카운터 초기화
        env.expected_responses = 0;  // env의 기대 응답 카운터 초기화
        generate_robustness_vectors(); // 1. 강건성 테스트 벡터 먼저 생성
        generate_shuffled_vectors();  // 2. 정상 데이터 벡터 생성
    endtask

endclass  //generator

class driver;

    transaction                 tr;
    mailbox #(transaction)      gen2drv_mbox;
    mailbox #(transaction)      drv2scb_mbox;
    virtual uart_fifo_interface uart_if;
    event                       gen_next_event;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) drv2scb_mbox,
                 virtual uart_fifo_interface uart_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.drv2scb_mbox = drv2scb_mbox;
        this.uart_if      = uart_if;
    endfunction

    task reset();
        uart_if.clk = 0;
        uart_if.rst = 1;
        uart_if.rx  = 1;
        #10;
        uart_if.rst = 0;
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            drv2scb_mbox.put(tr);

            uart_if.rx = tr.start_bit;
            #(BIT_PERIOD);

            for (int i = 0; i < 8; i++) begin
                uart_if.rx = tr.rand_wdata[i];
                #(BIT_PERIOD);
            end

            uart_if.rx = tr.stop_bit;
            #(BIT_PERIOD);

            tr.display("DRV");
        end
    endtask
endclass  //driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_fifo_interface uart_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_fifo_interface uart_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if = uart_if;
    endfunction  //new()

    task run();
        forever begin

            @(negedge uart_if.tx);
            #(BIT_PERIOD / 2);
            // *** START BIT 유효성 검사 ***
            // 이 시점에서 tx 라인이 '0'이 아니라면, 그것은 노이즈나 글리치(glitch)이다.
            if (uart_if.tx !== 1'b0) begin
                $display(
                    "[%12d ns] : [MON] : Glitch or invalid start bit detected (tx=%b). Ignoring.",
                    $time, uart_if.tx);
                continue; // 이번 엣지는 무시하고, 루프의 처음으로 돌아가 다음 하강 엣지를 기다린다.
            end
            #(BIT_PERIOD);

            tr = new();
            for (int i = 0; i < 8; i++) begin
                tr.rdata[i] = uart_if.tx;
                #(BIT_PERIOD);
            end
            #(BIT_PERIOD / 2);
            mon2scb_mbox.put(tr);
            tr.display("MON");
        end
    endtask
endclass  //monitor

class scoreboard;

    transaction tr;
    transaction send_data;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;

    int pass_cnt = 0;
    int fail_cnt = 0;

    // 0~255까지의 값이 커버되었는지 체크하기 위한 256비트 배열
    bit [255:0] covered_bins;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) drv2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
        this.drv2scb_mbox = drv2scb_mbox;
        // 체크리스트를 모두 0으로 초기화
        this.covered_bins = '0;
    endfunction  //new()

    task run();
        forever begin
            // 1. Driver로부터 모든 트랜잭션을 일단 받는다.
            drv2scb_mbox.get(send_data);

            // 2. Start bit가 유효한지 확인한다.
            if (send_data.start_bit !== 1'b0) begin
                // 2-1. Start bit가 '0'이 아니면 프로토콜 위반이므로 응답이 없을 것이다.
                //      따라서 응답을 기다리지 않고 넘어간다.
                $display(
                    "[%12d ns] : [SCB] : Skipping check for invalid start bit (start_bit=%b)",
                    $time, send_data.start_bit);
                continue;  // 루프의 처음으로 돌아감
            end

            // 3. Start bit가 유효하면, Monitor로부터 응답을 기다린다.
            //    (데이터가 X/Z라도 프레임은 유효하므로 응답이 온다)
            mon2scb_mbox.get(tr);

            // 4. 수신된 값을 비교한다. X,Z 값 비교를 위해 '===' 사용.
            if (send_data.rand_wdata === tr.rdata) begin
                // PASS: 기대값과 실제값이 완벽히 일치 (0,1,X,Z 모두 포함)
                $display(
                    "[%12d ns] : ==============  SCORE BOARD   ===========",
                    $time);
                if (!send_data.is_robustness_vector) begin
                    pass_cnt++;
                    $display(
                        "[%12d ns] : [SCB] PASS: Sent 0x%02h, Received 0x%02h",
                        $time, send_data.rand_wdata, tr.rdata);
                end else begin
                    $display(
                        "[%12d ns] : [SCB] FAIL: Sent 0x%02h, Received 0x%02h",
                        $time, send_data.rand_wdata, tr.rdata);
                    fail_cnt++;
                end
                $display(
                    "[%12d ns] : =========================================\n",
                    $time);
            end else begin
                // FAIL: 기대값과 실제값이 다름
                $display(
                    "[%12d ns] : ==============  SCORE BOARD   ===========",
                    $time);
                $error("[%12d ns] : [SCB]: Expected 0x%02h, But got 0x%02h",
                       $time, send_data.rand_wdata, tr.rdata);
                $display(
                    "[%12d ns] : =========================================\n",
                    $time);
                fail_cnt++;
            end

            // 5. 커버리지 체크는 '정상' 데이터에 대해서만 수행한다.
            if (!send_data.is_robustness_vector) begin
                covered_bins[send_data.rand_wdata] = 1'b1;
            end
        end
    endtask


endclass  //scoreboard

class environment;

    generator                   gen;
    driver                      drv;
    transaction                 tr;
    mailbox #(transaction)      gen2drv_mbox;
    mailbox #(transaction)      drv2scb_mbox;
    mailbox #(transaction)      mon2scb_mbox;
    virtual uart_fifo_interface uart_if;
    event                       gen_next_event;
    monitor                     mon;
    scoreboard                  scb;

    int                         expected_responses = 0;

    function new(virtual uart_fifo_interface uart_if);
        gen2drv_mbox = new();
        drv2scb_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, this);  // 'this'를 넘겨줌
        drv = new(gen2drv_mbox, drv2scb_mbox, uart_if);
        mon = new(mon2scb_mbox, uart_if);
        scb = new(mon2scb_mbox, drv2scb_mbox);
        this.uart_if = uart_if;
    endfunction  //new()

    task report();
        int covered_count = 0;
        int uncovered_q[$];  // 테스트되지 않은 값들을 저장할 큐

        // 1. scoreboard의 체크리스트(covered_bins)를 검사
        for (int i = 0; i < 256; i++) begin
            if (scb.covered_bins[i] == 1'b1) begin
                covered_count++;
            end else begin
                uncovered_q.push_back(i);  // 테스트 안된 값 저장
            end
        end

        // 2. 기본 테스트 결과 출력
        $display("========================================");
        $display("============= TEST SUMMARY =============");
        $display("========================================");
        $display("  Total Transactions : %0d", gen.total_cnt);
        $display("  Expected Responses : %0d", this.expected_responses);
        $display("  Passed             : %0d", scb.pass_cnt);
        $display("  Failed             : %0d", scb.fail_cnt);
        $display("----------------------------------------");

        // *** gen.total_cnt 대신 this.expected_responses와 비교 ***
        if (scb.fail_cnt == 0 && this.expected_responses == scb.pass_cnt) begin
            $display("  TEST RESULT: ** PASSED **");
        end else begin
            $display("  TEST RESULT: ** FAILED **");
        end
        $display("========================================");

        // 3. 커버리지 결과 출력
        $display("========== COVERAGE REPORT ===========");
        $display("========================================");
        $display("  Data Value Coverage: %0.2f %% (%0d / 256)",
                 (real'(covered_count) / 256.0) * 100.0, covered_count);

        // 4. 테스트되지 않은 항목이 있다면 출력
        if (uncovered_q.size() > 0) begin
            $write("  Uncovered values : ");
            foreach (uncovered_q[i]) begin
                $write("0x%02h, ", uncovered_q[i]);
            end
            $display("");  // new line
        end
        $display("========================================");
    endtask

    // X/Z 강건성 테스트를 위한 새로운 태스크
    task run_robustness_test();
        // Generator의 종료를 알리기 위한 event
        event gen_done;

        $display("[%12d ns] : [ENV] : Starting Test...", $time);
        drv.reset();

        fork
            begin
                gen.run();
                ->gen_done;  // gen.run()이 끝나면 이 event를 발생시킴
            end
            drv.run();
            mon.run();
            scb.run();
        join_none

        // 2. 메인 스레드는 먼저 Generator가 끝나기를 기다린다.
        @(gen_done);
        $display(
            "[%12d ns] : [ENV] : Generator finished. Total expected responses: %0d",
            $time, this.expected_responses);

        wait (scb.pass_cnt + scb.fail_cnt >= this.expected_responses);

        // TIMEOUT 처리 Code
        // begin
        //     #250_000_000; // 250ms
        //     $display("[%12d ns] : [ENV] : Test finished by TIMEOUT.", $time);
        //     report();
        //     $finish;
        // end

        report();
        $stop;
    endtask
endclass  //environment

module tb_v2 ();

    uart_fifo_interface uart_if_tb ();
    environment env;

    uart_top dut (
        .clk(uart_if_tb.clk),
        .rst(uart_if_tb.rst),
        .rx (uart_if_tb.rx),
        .tx (uart_if_tb.tx)
    );

    always #5 uart_if_tb.clk = ~uart_if_tb.clk;

    initial begin
        uart_if_tb.clk = 0;
        env = new(uart_if_tb);
        env.run_robustness_test();
    end

endmodule
