module PruebaPantallaLCD(
    input  wire clk,        

    // <<< Seis dígitos BCD desde el RTC >>>
    input  wire [3:0] hour1, hour0,
    input  wire [3:0] min1,  min0,
    input  wire [3:0] sec1,  sec0,

    output reg  RS,
    output wire RW,
    output wire E,
    output reg [7:0] lcd_data
);


assign RW = 1'b0;

//--------------------------------------------------
// TICK CADA 2 ms
//--------------------------------------------------
reg [17:0] dcnt = 0;
reg tick = 0;

always @(posedge clk) begin
    if (dcnt == 18'd100000) begin
        dcnt <= 0;
        tick <= 1;
    end else begin
        dcnt <= dcnt + 1;
        tick <= 0;
    end
end

//--------------------------------------------------
// PULSO E
//--------------------------------------------------
reg [5:0] ecnt = 0;
reg epulse = 0;

always @(posedge clk) begin
    if (tick && (state <= 20)) begin
        epulse <= 1;
        ecnt <= 0;
    end
    else if (epulse) begin
        if (ecnt == 6'd10)
            epulse <= 0;
        else
            ecnt <= ecnt + 1;
    end
end

assign E = epulse;

//--------------------------------------------------
// GENERAR 1 SEGUNDO DESDE 50 MHz
//--------------------------------------------------
reg [25:0] one_sec_cnt = 0;
reg one_sec_tick = 0;

always @(posedge clk) begin
    if (one_sec_cnt == 26'd49_999_999) begin
        one_sec_cnt <= 0;
        one_sec_tick <= 1;
    end else begin
        one_sec_cnt <= one_sec_cnt + 1;
        one_sec_tick <= 0;
    end
end

//--------------------------------------------------
// CONTADOR hh:mm:ss
//--------------------------------------------------
reg [5:0] sec = 0;
reg [5:0] min = 0;
reg [4:0] hr  = 0;

always @(posedge clk) begin
    if (one_sec_tick) begin

        if (sec == 59) begin
            sec <= 0;

            if (min == 59) begin
                min <= 0;
                if (hr == 23)
                    hr <= 0;
                else
                    hr <= hr + 1;
            end else begin
                min <= min + 1;
            end

        end else begin
            sec <= sec + 1;
        end

    end
end

//--------------------------------------------------
// CONVERTIR A ASCII
//--------------------------------------------------
wire [7:0] hr_t  = hour1 + "0";
wire [7:0] hr_u  = hour0 + "0";

wire [7:0] min_t = min1 + "0";
wire [7:0] min_u = min0 + "0";

wire [7:0] sec_t = sec1 + "0";
wire [7:0] sec_u = sec0 + "0";

//--------------------------------------------------
// FSM
//--------------------------------------------------
reg [7:0] state = 0;

always @(posedge clk) begin
    if (tick) begin
        case (state)

            // INICIALIZACIÓN
            0: begin RS<=0; lcd_data<=8'h38; state<=1; end
            1: begin RS<=0; lcd_data<=8'h0C; state<=2; end
            2: begin RS<=0; lcd_data<=8'h01; state<=3; end
            3: begin RS<=0; lcd_data<=8'h06; state<=4; end

            // Cursor posición centrada
            4: begin RS<=0; lcd_data<=8'h84; state<=5; end

            // IMPRIMIR HH:MM:SS
            5:  begin RS<=1; lcd_data<=hr_t;  state<=6; end
            6:  begin RS<=1; lcd_data<=hr_u;  state<=7; end
            7:  begin RS<=1; lcd_data<=":";   state<=8; end
            8:  begin RS<=1; lcd_data<=min_t; state<=9; end

            9:  begin RS<=1; lcd_data<=min_u; state<=10; end
            10: begin RS<=1; lcd_data<=":";   state<=11; end
            11: begin RS<=1; lcd_data<=sec_t; state<=12; end
            12: begin RS<=1; lcd_data<=sec_u; state<=4;  end

            default: state <= 4;

        endcase
    end
end

endmodule
