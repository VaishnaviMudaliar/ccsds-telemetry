// ============================================================================
// Module: ccsds_deserializer
// Description: CCSDS Telemetry Frame De-serializer & CRC Engine
// ============================================================================

module ccsds_deserializer #(
    parameter PAYLOAD_BYTES = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Serial Stream Input
    input  wire [7:0]  rx_byte,
    input  wire        rx_valid,
    
    // Decoded Outputs
    output reg  [31:0] frame_header,
    output reg  [7:0]  payload_byte,
    output reg         payload_valid,
    output reg         frame_valid,
    output reg         crc_error
);

    localparam [31:0] CCSDS_SYNC = 32'h1ACFFC1D;

    // FSM States
    localparam STATE_SYNC_SEARCH = 2'b00;
    localparam STATE_HEADER      = 2'b01;
    localparam STATE_PAYLOAD     = 2'b10;
    localparam STATE_CRC_CHECK   = 2'b11;

    reg [1:0]  state;
    reg [31:0] shift_reg;
    reg [15:0] crc_reg;
    reg [15:0] received_crc;
    reg [15:0] byte_count;

    // Standard Bit-wise CRC16 CCITT (Polynomial 0x1021, Seed 0xFFFF)
    function [15:0] next_crc16(input [7:0] data_in, input [15:0] current_crc);
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
            next_crc16 = crc;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= STATE_SYNC_SEARCH;
            shift_reg      <= 32'h0;
            crc_reg        <= 16'hFFFF;
            received_crc   <= 16'h0000;
            byte_count     <= 0;
            frame_header   <= 32'h0;
            payload_byte   <= 8'h0;
            payload_valid  <= 1'b0;
            frame_valid    <= 1'b0;
            crc_error      <= 1'b0;
        end else begin
            payload_valid  <= 1'b0;
            frame_valid    <= 1'b0;
            crc_error      <= 1'b0;

            if (rx_valid) begin
                shift_reg <= {shift_reg[23:0], rx_byte};

                case (state)
                    STATE_SYNC_SEARCH: begin
                        if ({shift_reg[23:0], rx_byte} == CCSDS_SYNC) begin
                            state      <= STATE_HEADER;
                            byte_count <= 0;
                            crc_reg    <= 16'hFFFF;
                            $display("[RTL DEBUG @ %0t] >>> SYNC DETECTED!", $time);
                        end
                    end

                    STATE_HEADER: begin
                        crc_reg    <= next_crc16(rx_byte, crc_reg);
                        byte_count <= byte_count + 1;

                        $display("[RTL DEBUG @ %0t] HEADER Byte[%0d]=0x%h | CRC=0x%h", $time, byte_count, rx_byte, next_crc16(rx_byte, crc_reg));

                        if (byte_count == 0) frame_header[31:24] <= rx_byte;
                        if (byte_count == 1) frame_header[23:16] <= rx_byte;
                        if (byte_count == 2) frame_header[15:8]  <= rx_byte;
                        if (byte_count == 3) begin
                            frame_header[7:0] <= rx_byte;
                            state             <= STATE_PAYLOAD;
                            byte_count        <= 0;
                        end
                    end

                    STATE_PAYLOAD: begin
                        crc_reg       <= next_crc16(rx_byte, crc_reg);
                        payload_byte  <= rx_byte;
                        payload_valid <= 1'b1;
                        byte_count    <= byte_count + 1;

                        $display("[RTL DEBUG @ %0t] PAYLOAD Byte[%0d]=0x%h | CRC=0x%h", $time, byte_count, rx_byte, next_crc16(rx_byte, crc_reg));

                        if (byte_count == PAYLOAD_BYTES - 1) begin
                            state      <= STATE_CRC_CHECK;
                            byte_count <= 0;
                        end
                    end

                    STATE_CRC_CHECK: begin
                        byte_count <= byte_count + 1;

                        if (byte_count == 0) begin
                            received_crc[15:8] <= rx_byte;
                            $display("[RTL DEBUG @ %0t] Received CRC MSB = 0x%h | Expected CRC = 0x%h", $time, rx_byte, crc_reg);
                        end else if (byte_count == 1) begin
                            received_crc[7:0] <= rx_byte;
                            $display("[RTL DEBUG @ %0t] Received Full CRC = 0x%h | Calculated CRC = 0x%h", $time, {received_crc[15:8], rx_byte}, crc_reg);

                            if (crc_reg == {received_crc[15:8], rx_byte}) begin
                                $display("[RTL DEBUG @ %0t] *** CRC MATCH! *** ", $time);
                                frame_valid <= 1'b1;
                            end else begin
                                $display("[RTL DEBUG @ %0t] *** CRC MISMATCH! *** ", $time);
                                crc_error   <= 1'b1;
                            end

                            state <= STATE_SYNC_SEARCH;
                        end
                    end

                    default: state <= STATE_SYNC_SEARCH;
                endcase
            end
        end
    end
endmodule