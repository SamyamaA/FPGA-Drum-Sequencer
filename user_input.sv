module user_input (key, user_out, clk, reset);
	input logic key, clk, reset;
	output logic user_out;
	
	enum {unpressed, pressed} ps, ns;
	logic intermediate, cleanKey;
	
	always_comb begin	
		case(ps)
			unpressed: begin
				if(~cleanKey) begin
					ns = unpressed;
					user_out = 0;
				end
				
				else begin
					ns = pressed;
					user_out = 1;
				end
			end
			
			pressed: begin
				if(~cleanKey) begin
					ns = unpressed;
					user_out = 0;
				end
				
				else begin 
					ns = pressed;
					user_out = 0;
				end
			end 
			
			default: begin 
				ns = unpressed;
				user_out = 0;
			end
		endcase
	end
	
	always_ff @(posedge clk) begin

		if (reset) begin
			intermediate <= 0;
			cleanKey <= 0;
		end 
		
		else begin
			intermediate <= key;	
			cleanKey <= intermediate;	
		end
		
		if (reset) begin
            ps <= unpressed;
      end
      
		else begin
            ps <= ns;
      end
	end	
endmodule

module user_input_testbench();
	logic clk, reset, key;
	logic user_out;
	
	user_input dut (.clk, .reset, .key, .user_out);
	
	parameter CLOCK_PERIOD=100;
	initial begin
		clk <= 0;
		forever #(CLOCK_PERIOD/2) clk <= ~clk;
	end
	
	initial begin
	reset <= 1; key <= 0; user_out <= 0; @(posedge clk);
	reset <= 0; 	 		  					 @(posedge clk);
	
	key <= 1;
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
	
	key <= 0;
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		
	key <= 0; @(posedge clk);
	key <= 1; @(posedge clk);
				 @(posedge clk);
				 @(posedge clk);
	key <= 0; @(posedge clk);
	key <= 1; @(posedge clk);

	$stop;
	end
endmodule
		


