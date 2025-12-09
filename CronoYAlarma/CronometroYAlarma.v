`timescale 1ns / 1ps

module CronometroYAlarma(
    input  wire clk,        // 50 MHz
    input  wire rst_n,      // reset activo bajo
    output reg  RS,
    output wire RW,
    output wire E,
    output reg [7:0] lcd_data,
    output reg [4:0] hour,   // 0-23
    output reg [5:0] minute, // 0-59
    output reg [5:0] second, // 0-59
    output blink_led,        // LED que titila cada segundo
	 output blink_led_delayed,        // LED que titila cada segundo
output reg [4:0] ext_leds,  // 5 LEDs externos
output reg bell,   // nueva salida para la alarma

	 input key0
);

assign RW = 1'b0;

//--------------------------------------------------
// TICK CADA 2 ms
//--------------------------------------------------
reg [17:0] dcnt = 0;
reg tick = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dcnt <= 0;
        tick <= 0;
    end else begin
        if (dcnt == 18'd100000) begin
            dcnt <= 0;
            tick <= 1;
        end else begin
            dcnt <= dcnt + 1;
            tick <= 0;
        end
    end
end

//--------------------------------------------------
// PULSO E
//--------------------------------------------------
reg [5:0] ecnt = 0;
reg epulse = 0;
reg [7:0] state = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        epulse <= 0;
        ecnt <= 0;
    end else begin
        if (tick && (state <= 20)) begin
            epulse <= 1;
            ecnt <= 0;
        end else if (epulse) begin
            if (ecnt == 6'd10)
                epulse <= 0;
            else
                ecnt <= ecnt + 1;
        end
    end
end

assign E = epulse;

//--------------------------------------------------
// GENERAR 1 SEGUNDO DESDE 50 MHz
//--------------------------------------------------
reg [25:0] one_sec_cnt = 0;
reg one_sec_tick = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        one_sec_cnt <= 0;
        one_sec_tick <= 0;
    end else begin
        if (one_sec_cnt == 26'd49_999_999) begin
            one_sec_cnt <= 0;
            one_sec_tick <= 1;
        end else begin
            one_sec_cnt <= one_sec_cnt + 1;
            one_sec_tick <= 0;
        end
    end
end

//--------------------------------------------------
// CONTADOR hh:mm:ss
//--------------------------------------------------
reg [5:0] sec_q = 0;
reg [5:0] min_q = 0;
reg [4:0] hr_q  = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sec_q <= 0;
        min_q <= 0;
        hr_q  <= 0;
    end else if (one_sec_tick) begin
        if (sec_q == 59) begin
            sec_q <= 0;
            if (min_q == 59) begin
                min_q <= 0;
                if (hr_q == 23)
                    hr_q <= 0;
                else
                    hr_q <= hr_q + 1;
            end else begin
                min_q <= min_q + 1;
            end
        end else begin
            sec_q <= sec_q + 1;
        end
    end
end

// Asignar a las salidas
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hour <= 0;
        minute <= 0;
        second <= 0;
    end else begin
        hour   <= hr_q;
        minute <= min_q;
        second <= sec_q;
    end
end

//--------------------------------------------------
// Señal para reiniciar titileo al cambiar de minuto
//--------------------------------------------------
reg restart_blink = 0;
reg [5:0] prev_min = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        restart_blink <= 0;
        prev_min      <= 0;
    end else begin
        if (minute != prev_min) begin
            prev_min      <= minute;
            restart_blink <= 1'b1;  // marcar reinicio
        end else begin
            restart_blink <= 1'b0;  // solo pulso de un ciclo
        end
    end
end

//--------------------------------------------------
// LED NORMAL: titila cada segundo, se detiene con key0
//--------------------------------------------------
reg blink_q = 0;
reg stop_blink = 0;
reg [5:0] prev_sec = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blink_q   <= 0;
        stop_blink <= 0;
        prev_sec  <= 0;
        bell      <= 0;  // alarma apagada por defecto
    end else begin
        // reiniciar titileo si cambia minuto
        if (restart_blink) begin
            blink_q   <= 0;
            stop_blink <= 0;
        end

        // detectar cambio de segundo
        if (sec_q != prev_sec) begin
            prev_sec <= sec_q;
            if (!stop_blink)
                blink_q <= ~blink_q;   // titilar normalmente
        end

        // activar detención al presionar key0
        if (key0) begin
            stop_blink <= 1'b1;
            blink_q    <= 0; // apagar inmediatamente
        end

        // Asignar titileo a la alarma
		bell <= ~blink_q;  // invertir para que 0 active la alarma
    end
end


assign blink_led = blink_q;

//--------------------------------------------------
// LED DELAYED: titila 10s tras key0, luego apaga
//--------------------------------------------------
reg blink_delayed_q = 0;
reg delayed_active  = 0;
reg [3:0] delayed_counter = 0;
reg [5:0] prev_sec_del = 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blink_delayed_q <= 0;
        delayed_active  <= 0;
        delayed_counter <= 0;
        prev_sec_del    <= 0;
    end else begin
        // reiniciar titileo si cambia minuto
        if (restart_blink) begin
            blink_delayed_q <= 0;
            delayed_active  <= 0;
            delayed_counter <= 0;
        end

        // detectar cambio de segundo
        if (sec_q != prev_sec_del) begin
            prev_sec_del <= sec_q;

            if (!stop_blink) begin
                blink_delayed_q <= ~blink_delayed_q;
                delayed_counter <= 0;
                delayed_active  <= 1;
            end else if (delayed_active) begin
                if (delayed_counter < 10) begin
                    blink_delayed_q <= ~blink_delayed_q;
                    delayed_counter <= delayed_counter + 1;
                end else begin
                    blink_delayed_q <= 0;
                    delayed_active  <= 0;
                end
            end
        end
    end
end

assign blink_led_delayed = blink_delayed_q;

//--------------------------------------------------
// LEDs externos: 5 LEDs controlados por el LED delayed
//--------------------------------------------------
//--------------------------------------------------
// LEDs externos: 5 LEDs controlados por LED delayed
//--------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ext_leds <= 5'b11111;  // TODOS apagados por defecto
    end else begin
        // Por defecto apagados
        ext_leds <= 5'b11111;

        // Encender el LED correspondiente mientras blink_delayed_q activo
        if (blink_delayed_q) begin
            case (minute % 10)
                4'd0, 4'd5: ext_leds <= 5'b11110; // LED0 encendido
                4'd1, 4'd6: ext_leds <= 5'b11101; // LED1 encendido
                4'd2, 4'd7: ext_leds <= 5'b11011; // LED2 encendido
                4'd3, 4'd8: ext_leds <= 5'b10111; // LED3 encendido
                4'd4, 4'd9: ext_leds <= 5'b01111; // LED4 encendido
            endcase
        end
    end
end



//--------------------------------------------------
// CONVERTIR A ASCII PARA LCD
//--------------------------------------------------
wire [7:0] hr_t  = (hr_q / 10) + "0";
wire [7:0] hr_u  = (hr_q % 10) + "0";
wire [7:0] min_t = (min_q / 10) + "0";
wire [7:0] min_u = (min_q % 10) + "0";
wire [7:0] sec_t = (sec_q / 10) + "0";
wire [7:0] sec_u = (sec_q % 10) + "0";

//--------------------------------------------------
// FSM PARA CONTROL DE LCD
//--------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 0;
        RS <= 0;
        lcd_data <= 8'h00;
    end else if (tick) begin
        case (state)
            0:  begin RS<=0; lcd_data<=8'h38; state<=1; end
            1:  begin RS<=0; lcd_data<=8'h0C; state<=2; end
            2:  begin RS<=0; lcd_data<=8'h01; state<=3; end
            3:  begin RS<=0; lcd_data<=8'h06; state<=4; end
            4:  begin RS<=0; lcd_data<=8'h84; state<=5; end
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
