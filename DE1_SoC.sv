module DE1_SoC (CLOCK_50, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, KEY, LEDR, SW,
                FPGA_I2C_SCLK, FPGA_I2C_SDAT, AUD_XCK, AUD_DACLRCK,
                AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT, AUD_DACDAT, GPIO_1); 	
	input  logic         CLOCK_50; // 50MHz clock.	
	output logic  [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5; 		
	output logic  [9:0]  LEDR; 		
	input  logic  [3:0]  KEY; // True when not pressed, False when pressed	
	input  logic  [9:0]  SW; 			
	
	//audio
	inout FPGA_I2C_SDAT;
	output logic FPGA_I2C_SCLK, AUD_XCK, AUD_DACDAT;
	input logic AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT;
			
	//16x16 leds
	output logic [35:0] GPIO_1;	
	
	//reset and modes
	logic reset, recordMode;
	assign reset = SW[9];
	assign recordMode = SW[0];

	logic advance; 
	logic [23:0] adc_left, adc_right; //line-in, unused
	logic signed [23:0] kickSound; 
	logic signed [23:0] snareSound;
	logic signed [23:0] hatSound;
	logic signed [23:0] mixed;
	
	//user input
	logic kickKey, snareKey, hatKey, nextKey;
	user_input kick_btn (.clk (CLOCK_50), .reset, .key (~KEY[3]), .user_out (kickKey));
	user_input snare_btn (.clk (CLOCK_50), .reset, .key (~KEY[2]), .user_out (snareKey));
	user_input hat_btn (.clk (CLOCK_50), .reset, .key (~KEY[1]), .user_out (hatKey));
	user_input next_btn (.clk (CLOCK_50), .reset, .key (~KEY[0]), .user_out (nextKey));

	//patterm + memory
	logic [7:0] kickPattern;
	logic [7:0] snarePattern;
	logic [7:0] hatPattern;
	logic [2:0] recPos;

	always_ff @(posedge CLOCK_50) begin
		if (reset) begin
			kickPattern  <= 8'd0; 
			snarePattern <= 8'd0;
			hatPattern <= 8'd0;
			recPos <= 3'd0;
		end
		else if (recordMode) begin
			if (kickKey)  begin
				kickPattern[recPos]  <= 1'b1; 
			end
			
			if (snareKey) begin
				snarePattern[recPos] <= 1'b1;   
			end
			
			if (hatKey) begin 
				hatPattern[recPos] <= 1'b1;
			end
			
			if (nextKey) begin
				recPos <= recPos + 3'd1;
			end
		end
	end
	
	//tempo logic
	logic [13:0] stepTicks; 
	
	always_comb begin
		case (SW[8:7])
			2'b00: stepTicks = 14'd15000; //slowest
			2'b01: stepTicks = 14'd12000;
			2'b10: stepTicks = 14'd9000;
			2'b11: stepTicks = 14'd7000; //fastest
		endcase
	end
	
	
	//sequencer logic
	logic kickTrig, snareTrig, hatTrig;
	
	sequencer s (.CLOCK_50, .reset, .advance, .STEP_TICKS(stepTicks), 
		.kickPattern, .hatPattern, .snarePattern, .hatTrig, .kickTrig, .snareTrig);

	//triggers
	logic kickFire, snareFire, hatFire;
	assign kickFire  = recordMode ? kickKey : kickTrig; //if recordmode is true fire = key (record), otherwise trig (loop)
	assign snareFire = recordMode ? snareKey : snareTrig;
	assign hatFire = recordMode ? hatKey : hatTrig;
	
	reg k_lat, s_lat, h_lat;
	always @(posedge CLOCK_50) begin
	    if (kickFire) k_lat <= 1'b1; //remember the press
	    else if (advance) k_lat <= 1'b0; //consume it on the next sample tick
	end
	always @(posedge CLOCK_50) begin
	    if (snareFire) s_lat <= 1'b1;   
	    else if (advance) s_lat <= 1'b0;   
	end
	always @(posedge CLOCK_50) begin
	    if (hatFire) h_lat <= 1'b1;   
	    else if (advance) h_lat <= 1'b0;   
	end
	

	//sounds
	sounds kick (.CLOCK_50, .advance, .trigger (k_lat), .soundType (2'd0), .sound (kickSound));
	sounds snare (.CLOCK_50, .advance, .trigger (s_lat), .soundType (2'd1), .sound (snareSound));
	sounds hat (.CLOCK_50, .advance, .trigger (h_lat), .soundType (2'd2), .sound (hatSound));

	//mixer
	mixer mix (.kickSound, .snareSound, .hatSound, .mixed_out(mixed));

	//audio driver
	audio_driver u_audio (.CLOCK_50, .reset, .dac_left (mixed), .dac_right (mixed),
	    .adc_left, .adc_right, .advance, .FPGA_I2C_SCLK, .FPGA_I2C_SDAT, .AUD_XCK,
	    .AUD_DACLRCK, .AUD_ADCLRCK, .AUD_BCLK, .AUD_ADCDAT, .AUD_DACDAT);
	
	//VU meter
	logic LEDenable;
	assign LEDenable = 1'b1;
	logic [15:0][15:0] RedPixels;
	logic [15:0][15:0] GrnPixels;
	
	vu_meter vu (.CLOCK_50, .advance, .reset, .mixed, .RedPixels, .GrnPixels);
	
	LEDDriver #(.FREQDIV(15)) leds (.GPIO_1, .RedPixels, .GrnPixels, 
		.EnableCount(LEDenable), .CLK(CLOCK_50), .RST(reset));
		

	//display
	logic [6:0] h0_segs;
	seg7 h0 (.bcd({1'b0, recPos}), .leds(h0_segs));
	
	always_comb begin
		if (recordMode) begin
			HEX0 = ~h0_segs;
			HEX5 = 7'b0101111;
			HEX4 = 7'b0000110;
			HEX3 = 7'b1000110;
			HEX1 = 7'h7F; 
			HEX2 = 7'h7F;
		end
		
		else begin
			HEX5 = 7'b1000111; 
			HEX4 = 7'b1000000;
			HEX3 = 7'b1000000;
			HEX2 = 7'b0001100;
			HEX1 = 7'h7F;
			HEX0 = 7'h7F;
		end
	end

	assign LEDR[9] = recordMode;
endmodule	


module DE1_SoC_testbench();
	logic CLOCK_50;
	logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	logic [9:0] LEDR;
	logic [3:0] KEY;
	logic [9:0] SW;
	logic FPGA_I2C_SCLK, AUD_XCK, AUD_DACDAT;
	wire FPGA_I2C_SDAT;
	logic AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT;
	logic [35:0] GPIO_1;

	DE1_SoC dut (.CLOCK_50, .HEX0, .HEX1, .HEX2, .HEX3, .HEX4, .HEX5,
	    .KEY, .LEDR, .SW, .FPGA_I2C_SCLK, .FPGA_I2C_SDAT, .AUD_XCK, .AUD_DACLRCK,
	    .AUD_ADCLRCK, .AUD_BCLK, .AUD_ADCDAT, .AUD_DACDAT, .GPIO_1);

	parameter CLOCK_PERIOD = 20;
	initial begin
		CLOCK_50 <= 0;
		forever #(CLOCK_PERIOD/2) CLOCK_50 <= ~CLOCK_50;
	end

	//force a fast advance so the sequencer ticks in sim
	initial begin
		force dut.advance = 1'b0;
		forever begin
			@(posedge CLOCK_50);
			force dut.advance = 1'b1;
			@(posedge CLOCK_50);
			force dut.advance = 1'b0;
		end
	end

	//press a key for a few cycles, then release
	task press(input int k);
		begin
			KEY[k] <= 1'b0;
			repeat (4) @(posedge CLOCK_50);
			KEY[k] <= 1'b1;
			repeat (4) @(posedge CLOCK_50);
		end
	endtask

	initial begin
		//initialize
		KEY <= 4'b1111;
		SW  <= 10'd0;
		@(posedge CLOCK_50);

		//reset (recPos, kickPattern, snarePattern, hatPattern should go to x)
		SW[9] <= 1'b1;
		repeat (4) @(posedge CLOCK_50);
		SW[9] <= 1'b0;
		repeat (2) @(posedge CLOCK_50);

		//turn on record mode
		SW[0] <= 1'b1;
		@(posedge CLOCK_50);

		press(3); //step 0: KICK
		press(0); //change to step 1
		press(1); //step 1: HAT
		press(0); //change to step 2
		press(0); //step 2: empty, change to step 3
		press(2); //step 3: SNARE
		press(0); //change to step 4
		press(3); //step 4: KICK
		press(1); //step 4: HAT
		press(0); //change to step 5
		//check: recPos=5, kickPattern=00010001, snarePattern=00001000, hatPattern=00010010

		//play mode
		SW[0] <= 1'b0; //LEDR[9] should go to 0
		SW[8:7] <= 2'b11; // fastest tempo
		repeat (250000) @(posedge CLOCK_50); //watch kickTrig/snareTrig/hatTrig fire, change like 10 to show rec phase

		//tempo change
		SW[8:7] <= 2'b00;
		repeat (40) @(posedge CLOCK_50);

		//reset again (patterns clear again)
		SW[9] <= 1'b1;
		repeat (4) @(posedge CLOCK_50);
		SW[9] <= 1'b0;
		repeat (2) @(posedge CLOCK_50);

		$stop;
	end
endmodule 