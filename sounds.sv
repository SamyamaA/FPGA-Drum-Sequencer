module sounds (CLOCK_50, advance, trigger, soundType, sound);
	input logic CLOCK_50, advance, trigger;
	input logic [1:0] soundType;
	output logic signed [23:0] sound;

	localparam int halfPeriod = 400; //clock frequency/(beat frequency * 2)

	reg [8:0] phase; //counter for ticks (need it to be 240+ but add one bit for safety, TRY CHANGING LATER)
	reg square; //1 = + square wave, 0 = - square wave

	//create a basic square wave
	always_ff @(posedge CLOCK_50) begin
		if (advance) begin //when enable is true
			if (trigger) begin //if a key is pressed        
				phase <= 0; 
				square <= 1'b1; //reset counter and start square wave on high for sound
			end 
			
			else if (phase == halfPeriod-1) begin //when half way through period (when square wave switches)
				phase <= 0; 
				square <= ~square; //reset counter and flip square wave
			end 
			
			else begin
				phase <= phase + 1'b1; //add to counter one at a time if nothing special is happening
			end
		end
	end 
	
	
	reg [15:0] lfsr;
	
	//create LFSR for snare
	always_ff @(posedge CLOCK_50) begin
		if (advance) begin
			if (trigger) begin
				lfsr <= 16'd0; //dont let it start at all 1s
			end 
			
			else begin
				//16 dff connections xDDDDD
				lfsr <= {lfsr[14:0], ~(lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3])};
			end
		end
	end	
	
	logic snare0;
	assign snare0 = lfsr[0];

	logic [23:0] maxVol; 
	logic [23:0] decayStep; //the steps by which each decay cycle should happen
	reg [23:0] envelope; //hold the envelope value
	
	always_comb begin
		case(soundType)
			2'd0: begin
				decayStep = 24'd291; 
				maxVol = 24'h200000; //kick, maxVol/(.150 * 48000), 1/8th of max allowed volume 
			end
			2'd1: begin
				decayStep = 24'd291; 
				maxVol = 24'h200000; //snare
			end
			2'd2: begin
				decayStep = 24'd1100; 
				maxVol = 24'h180000; //hi-hat
			end
			default: begin
				decayStep = 24'd291;
				maxVol = 24'h200000;
			end
		endcase
	end

	//create an envelope to make effects on tone
	always_ff @(posedge CLOCK_50) begin
		if (advance) begin
			if (trigger) begin
				envelope <= maxVol; //at start should be at maximum volume
			end 
			
			else if (envelope > decayStep) begin
				envelope <= envelope - decayStep; //decrement volume
			end
			
			else begin
				envelope <= 24'd0; //make volume 0 after 150 ms
			end
		end
	end
	
													 
	logic osc;
	always_comb begin
		case (soundType)
			2'd0: osc = square;
			2'd1: osc = snare0;
			2'd2: osc = snare0;
			default: osc = square;
		endcase
	end
	
	always_ff @(posedge CLOCK_50) begin
		if (advance) begin
			sound <= osc ? $signed(envelope) : -$signed(envelope); //if osc is 1, output +env, if 0 output -env
		end
	end
endmodule


module sounds_testbench();
	logic CLOCK_50, advance, trigger;
	logic [1:0] soundType;
	logic signed [23:0] sound;

	sounds dut (.CLOCK_50, .advance, .trigger, .soundType, .sound);

	parameter CLOCK_PERIOD = 20;
	initial begin
		CLOCK_50 <= 0;
		forever #(CLOCK_PERIOD/2) CLOCK_50 <= ~CLOCK_50;
	end

	initial begin
		advance <= 0;
		forever begin
			@(posedge CLOCK_50);
			@(posedge CLOCK_50);
			@(posedge CLOCK_50);
			advance <= 1'b1;
			@(posedge CLOCK_50);
			advance <= 1'b0;
		end
	end

	//fire a trigger :pp
	task hit();
		begin
			@(posedge CLOCK_50); trigger <= 1'b1;
			@(posedge advance);              
			@(posedge CLOCK_50); trigger <= 1'b0;
		end
	endtask

	initial begin
		trigger  <= 1'b0;
		soundType <= 2'd0;

		//kick test
		soundType <= 2'd0;
		hit();
		repeat (40) @(posedge advance); 
		//expect the envelope to jump to 0x200000, a square wave that flips, slow decay

		//snare test
		soundType <= 2'd1;
		hit();
		repeat (40) @(posedge advance);
		//expect same envelope, but osc follows LFSR noise (sound jitters)

		//hi-hat test
		soundType <= 2'd2;
		hit();
		repeat (40) @(posedge advance);
		//expect a lower maxVol 0x180000, much faster decay compared to snare

		$stop;
	end
endmodule




