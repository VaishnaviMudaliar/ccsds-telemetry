`timescale 1ns / 1ps

module tb_ccsds_deserializer;

    parameter PAYLOAD_BYTES = 8;

    reg        clk;
    reg        rst_n;
    reg  [7:0] rx_byte;
    reg        rx_valid;

    wire [31:0] frame_header;
    wire [7:0]  payload_byte;
    wire        payload_valid;
    wire        frame_valid;
    wire        crc_error;

    ccsds_deserializer #(
        .PAYLOAD_BYTES(PAYLOAD_BYTES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid),
        .frame_header(frame_header),
        .payload_byte(payload_byte),
        .payload_valid(payload_valid),
        .frame_valid(frame_valid),
        .crc_error(crc_error)
    );

    // Clock Generation (100 MHz -> 10ns period)
    always #5 clk = ~clk;

    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            rx_byte  <= data;
            rx_valid <= 1'b1;
            @(posedge clk);
            rx_valid <= 1'b0;
        end
    endtask

    function [15:0] calc_crc16(input [7:0] data_in, input [15:0] current_crc);
        integer i;
        reg [15:0] crc;
        begin
            crc = current_crc ^ (data_in << 8);
            for (i = 0; i < 8; i = i + 1) begin
                if (crc[15])
                    crc = (crc << 1) ^ 16'h1021;
                else
                    crc = crc << 1;
            end
            calc_crc16 = crc;
        end
    endfunction

    reg [15:0] test1_crc;

    initial begin
        clk      = 0;
        rst_n    = 0;
        rx_byte  = 0;
        rx_valid = 0;

        #20 rst_n = 1;
        #20;

        $display("=== STARTING CCSDS FRAME DE-SERIALIZER SIMULATION ===");

        // Pre-calculate valid CRC for Test 1
        test1_crc = 16'hFFFF;
        test1_crc = calc_crc16(8'h08, test1_crc);
        test1_crc = calc_crc16(8'h00, test1_crc);
        test1_crc = calc_crc16(8'h00, test1_crc);
        test1_crc = calc_crc16(8'h07, test1_crc);
        test1_crc = calc_crc16(8'h01, test1_crc);
        test1_crc = calc_crc16(8'h02, test1_crc);
        test1_crc = calc_crc16(8'h03, test1_crc);
        test1_crc = calc_crc16(8'h04, test1_crc);
        test1_crc = calc_crc16(8'h05, test1_crc);
        test1_crc = calc_crc16(8'h06, test1_crc);
        test1_crc = calc_crc16(8'h07, test1_crc);
        test1_crc = calc_crc16(8'h08, test1_crc);

        // --- TEST 1: Valid Frame ---
        $display("\n[TEST 1] Sending Noise + Valid Telemetry Frame...");
        send_byte(8'hFF);
        send_byte(8'h00);

        // Sync Word
        send_byte(8'h1A); send_byte(8'hCF); send_byte(8'hFC); send_byte(8'h1D);

        // Header
        send_byte(8'h08); send_byte(8'h00); send_byte(8'h00); send_byte(8'h07);

        // Payload
        send_byte(8'h01); send_byte(8'h02); send_byte(8'h03); send_byte(8'h04);
        send_byte(8'h05); send_byte(8'h06); send_byte(8'h07); send_byte(8'h08);

        // Send Valid CRC
        send_byte(test1_crc[15:8]);
        send_byte(test1_crc[7:0]);

        // Wait for the exact clock edge where frame_valid pulses
        @(posedge clk);
        if (frame_valid)
            $display("[PASS] Frame successfully decoded and CRC verified!");
        else
            $display("[FAIL] Frame verification failed!");

        // --- TEST 2: Single Event Upset ---
        $display("\n[TEST 2] Sending Frame with Corrupted Data Bit (SEU)...");

        // Sync Word
        send_byte(8'h1A); send_byte(8'hCF); send_byte(8'hFC); send_byte(8'h1D);

        // Header
        send_byte(8'h08); send_byte(8'h00); send_byte(8'h00); send_byte(8'h07);

        // Corrupted Payload
        send_byte(8'h01); send_byte(8'h02); send_byte(8'hFF); send_byte(8'h04);
        send_byte(8'h05); send_byte(8'h06); send_byte(8'h07); send_byte(8'h08);

        // Send Test 1 CRC (Mismatched)
        send_byte(test1_crc[15:8]);
        send_byte(test1_crc[7:0]);

        // Wait for the exact clock edge where crc_error pulses
        @(posedge clk);
        if (crc_error)
            $display("[PASS] CRC Engine correctly identified corrupted frame!");
        else
            $display("[FAIL] Failed to detect CRC error!");

        $display("\n=== SIMULATION COMPLETE ===");
        $finish;
    end

    always @(posedge clk) begin
        if (payload_valid)
            $display("   [Payload Data Received]: 0x%h", payload_byte);
    end

endmodule