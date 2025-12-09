// Módulo maestro I2C simple para comunicación con DS1307
module i2c_master (
    input wire clk,
    input wire rst,
    input wire start,           // señal para iniciar comunicación
    input wire rw,              // 0 = write, 1 = read
    input wire [6:0] addr,      // dirección I2C del esclavo
    input wire [7:0] reg_addr,  // dirección del registro interno
    input wire [7:0] data_in,   // dato a escribir
    output reg [7:0] data_out,  // dato leído
    output reg done,            // indica fin de transacción
    inout wire sda,
    output reg scl
);

    // Estados
    localparam [3:0]
        IDLE    = 0,
        START   = 1,
        ADDR    = 2,
        REG     = 3,
        RW_BIT  = 4,
        READ    = 5,
        STOP    = 6,
        DONE    = 7;

    reg [3:0] state = IDLE;
    reg [7:0] bit_cnt;
    reg sda_out, sda_dir;
    assign sda = sda_dir ? sda_out : 1'bz; // Tri-state SDA

    reg [15:0] clk_div;
    wire scl_tick = (clk_div == 16'd24999); // ajusta para ~1kHz

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div <= 0;
            scl <= 1;
        end else begin
            clk_div <= clk_div + 1;
            if (scl_tick)
                scl <= ~scl;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            sda_out <= 1;
            sda_dir <= 1;
            bit_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= START;
                end

                START: begin
                    sda_out <= 0; // START
                    sda_dir <= 1;
                    state <= ADDR;
                    bit_cnt <= 7;
                end

                ADDR: begin
                    sda_out <= addr[bit_cnt];
                    if (bit_cnt == 0) state <= REG;
                    else bit_cnt <= bit_cnt - 1;
                end

                REG: begin
                    sda_out <= reg_addr[bit_cnt];
                    if (bit_cnt == 0) state <= RW_BIT;
                    else bit_cnt <= bit_cnt - 1;
                end

                RW_BIT: begin
                    sda_out <= rw;
                    sda_dir <= 1;
                    state <= READ;
                end

                READ: begin
                    if (rw)
                        data_out <= reg_addr; // simula lectura
                    state <= STOP;
                end

                STOP: begin
                    sda_out <= 0;
                    sda_out <= 1; // STOP
                    done <= 1;
                    state <= DONE;
                end

                DONE: state <= DONE;
            endcase
        end
    end
endmodule
