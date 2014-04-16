`timescale 1ns / 1ps
// Quad GLITCBUS master. This module also handles the programming interface as well.
// There's a separate module (in the TISC address space) which handle the programming
// state of each FPGA. Each FPGA can be programmed/reprogrammed individually.
//
// That module does:
// Assert PROGRAM_B: set "gready_i[N]" to 0. (N=0 to 3)
// Assert INIT_B
// Deassert PROGRAM_B
// Deassert INIT_B
// 
// It then watches for DONE being asserted, and sets gready_i[N] to 1.
//
//
module glitcbus_master(
		input [3:0] gready_i,
		output [3:0] GSEL_B,
		inout [7:0] GAD,
		output GRDWR_B,
		output GCLK,

		input clk_i,
		input cyc_i,
		input stb_i,
		input we_i,
		input [17:0] adr_i,
		input [31:0] dat_i,
		output [31:0] dat_o,
		output ack_o
    );

	// Bits [16:15] select which GLITC we're talking to.
	// If "gready_i" for that GLITC is 0, then we treat it as a configuration
	// load. Otherwise we treat it as a GLITCBUS transaction.
	
	localparam FSM_BITS = 4;
	//% Waiting...
	localparam [FSM_BITS-1:0] IDLE = 0;
	//% Config write. Assert RDWR_B first.
	localparam [FSM_BITS-1:0] CONFIG_RDWR_B = 1;
	//% Then assert CSI_B (GSEL_B) along with the data. Note that we just write 1 byte at a time
	//% right now. We might do something smarter with a separate programming module, and a PCI DMA
	//% transaction or something intelligent later. For that we'll have to handle bursts, which
	//% also shouldn't be too hard.
	localparam [FSM_BITS-1:0] CONFIG_WRITE_BYTE = 2;
	//% Finish.
	localparam [FSM_BITS-1:0] CONFIG_WRITE_BYTE_DONE = 3;
	//% GLITCBUS transaction. Select phase.
	localparam [FSM_BITS-1:0] GB_SEL = 4;
	//% GLITCBUS transaction. Address high phase.
	localparam [FSM_BITS-1:0] GB_ADDRESS = 5;
	//% GLITCBUS transaction. Address low phase.
	localparam [FSM_BITS-1:0] GB_ADDRESS2 = 6;
	//% GLITCBUS transaction. Wait 1 phase.
	localparam [FSM_BITS-1:0] GB_WAIT = 7;
	//% GLITCBUS transaction. Read wait phase.
	localparam [FSM_BITS-1:0] GB_READ_WAIT = 8;
	//% GLITCBUS transaction. Second read wait phase.
	localparam [FSM_BITS-1:0] GB_READ_WAIT_2 = 9;
	//% GLITCBUS transaction. BYTE3 phase.
	localparam [FSM_BITS-1:0] GB_BYTE3 = 10;
	//% GLITCBUS transaction. BYTE2 phase.
	localparam [FSM_BITS-1:0] GB_BYTE2 = 11;
	//% GLITCBUS transaction. BYTE1 phase.
	localparam [FSM_BITS-1:0] GB_BYTE1 = 12;
	//% GLITCBUS transaction. BYTE0 phase.
	localparam [FSM_BITS-1:0] GB_BYTE0 = 13;
	//% GLITCBUS transaction. Completion phase.
	localparam [FSM_BITS-1:0] GB_DONE = 14;
	//% State variable.
	reg [FSM_BITS-1:0] state = IDLE;
	
	always @(posedge clk_i) begin
		case (state)
			IDLE: if (cyc_i && stb_i) begin
				if (!gready_i[adr_i[17:16]]) begin
					if (!we_i) state <= CONFIG_WRITE_BYTE_DONE;
					else state <= CONFIG_RDWR_B;
				end else
					state <= GB_SEL;
			end
			CONFIG_RDWR_B: state <= CONFIG_WRITE_BYTE;
			CONFIG_WRITE_BYTE: state <= CONFIG_WRITE_BYTE_DONE;
			CONFIG_WRITE_BYTE_DONE: state <= IDLE;
			GB_SEL: state <= GB_ADDRESS;					// select phase
			GB_ADDRESS: state <= GB_ADDRESS2;			// address high phase
			GB_ADDRESS2: state <= GB_WAIT;				// address low phase
			GB_WAIT: if (we_i) state <= GB_BYTE3;		// wait1 phase
							else 	 state <= GB_READ_WAIT;
			GB_READ_WAIT: state <= GB_READ_WAIT_2;		// wait2 phase for read
			GB_READ_WAIT_2: state <= GB_BYTE3;			// byte3 phase for read
			GB_BYTE3: state <= GB_BYTE2;					// wait2 phase for write, byte2 phase for read
			GB_BYTE2: state <= GB_BYTE1;					// byte3 phase for write, byte1 phase for read
			GB_BYTE1: state <= GB_BYTE0;					// byte2 phase for write, byte0 phase for read
			GB_BYTE0: state <= GB_DONE;					// byte1 phase for write, completion for read
			GB_DONE: state <= IDLE;
		endcase
	end
	
	reg [7:0] gad_q = {8{1'b0}};
	(* IOB = "TRUE" *)
	reg [7:0] gad_out = {8{1'b0}};
	(* IOB = "TRUE" *)
	reg [3:0] gsel_out = {4{1'b1}};
	(* IOB = "TRUE" *)
	reg [7:0] gad_oe_b = {8{1'b1}};
	(* IOB = "TRUE" *)
	reg grdwr_b_out = 1;
	reg [15:0] address_out = {16{1'b0}};
	reg [31:0] data_out = {32{1'b0}};
	reg ack = 0;
	
	always @(posedge clk_i) begin
		gad_q <= GAD;
	end
	always @(posedge clk_i) begin
		if (state == GB_ADDRESS) gad_out <= adr_i[15:8];
		else if (state == GB_ADDRESS2) gad_out <= adr_i[7:0];
		else if (state == CONFIG_WRITE_BYTE) gad_out <= dat_i[7:0];
		else if (state == GB_BYTE3) gad_out <= dat_i[31:24];
		else if (state == GB_BYTE2) gad_out <= dat_i[23:16];
		else if (state == GB_BYTE1) gad_out <= dat_i[15:8];
		else if (state == GB_BYTE0) gad_out <= dat_i[7:0];
	end
	always @(posedge clk_i) begin
		if ((state == GB_WAIT && !we_i) 
		 || (state == CONFIG_WRITE_BYTE) 
		 || (state == GB_DONE) 
		 || (state == IDLE)) gad_oe_b <= {8{1'b0}};
		else if (state == GB_ADDRESS || state == CONFIG_RDWR_B) gad_oe_b <= {8{1'b1}};
	end
	always @(posedge clk_i) begin
		if (state == GB_SEL || state == CONFIG_WRITE_BYTE) gsel_out[adr_i[17:16]] <= 0;
		else if ((state == GB_DONE && we_i)
				|| (!we_i && state == GB_BYTE1)
				|| state == CONFIG_WRITE_BYTE_DONE || state == IDLE) gsel_out <= 4'hF;
	end
	always @(posedge clk_i) begin
		if (state == CONFIG_RDWR_B || (state == GB_ADDRESS && we_i) ||
			 state == GB_BYTE3)
			grdwr_b_out <= 0;
		else if (state == GB_DONE || state == IDLE)
			grdwr_b_out <= 1;
	end
	always @(posedge clk_i) begin
		if (!we_i) begin
			if (state == GB_BYTE3) data_out[31:24] <= gad_q;
			if (state == GB_BYTE2) data_out[23:16] <= gad_q;
			if (state == GB_BYTE1) data_out[15:8] <= gad_q;
			if (state == GB_BYTE0) data_out[7:0] <= gad_q;
		end
	end
	always @(posedge clk_i) begin
		ack <= (state == CONFIG_WRITE_BYTE_DONE) || (state == GB_BYTE0 && !we_i) || (state == GB_BYTE1 && we_i) ;
	end

	generate
		genvar i;
		for (i=0;i<8;i=i+1) begin : LOOP
			assign GAD[i] = (gad_oe_b[i]) ? 1'bZ : gad_out[i];
		end
	endgenerate
	assign GSEL_B = gsel_out;
	assign GRDWR_B = grdwr_b_out;
	// forward clk_i
	ODDR2 #(.INIT(0)) u_clk_forward(.D0(1'b1),.D1(1'b0),.C0(clk_i),.C1(~clk_i),.CE(1'b1),.R(1'b0),.S(1'b0),.Q(GCLK));
	assign ack_o = ack;
	assign dat_o = data_out;
endmodule
