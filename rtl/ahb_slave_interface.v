`timescale 1ns / 1ps

module ahb_slave_interface(
	input  wire        HCLK,
	input  wire        HRESETn,
	input  wire [1:0]  HTRANS,
	input  wire        HREADYIN,
	input  wire        HWRITE,
	input  wire [31:0] HADDR,
	input  wire [31:0] HWDATA,
	
	output reg         valid,
	output reg  [2:0]  tempselx,
	output reg         hwrite_reg,
	output reg  [31:0] haddr_q,
	output reg  [31:0] haddr_q2,
	output reg  [31:0] hwdata_q,
	output reg  [2:0]  selx_q,
	output reg  [2:0]  selx_q2
	);

	always @(*) begin
		valid = 1'b0;
		if(HRESETn && HREADYIN && (HADDR >= 32'h0000_0000 && HADDR < 32'h8C00_0000) && HTRANS[1])
			valid = 1'b1;
	end
	
	always @(*) begin
		tempselx = 3'b000;
		if(HADDR >= 32'h8000_0000 && HADDR < 32'h8400_0000) begin
			tempselx = 3'b001;
		end
		else if(HADDR >= 32'h8400_0000 && HADDR < 32'h8800_0000) begin
			tempselx = 3'b010;
		end
		else if(HADDR >= 32'h8800_0000 && HADDR < 32'h8C00_0000) begin
			tempselx = 3'b100;
		end
	end
	
	always @(posedge HCLK or negedge HRESETn) begin
		if(!HRESETn) begin
			hwrite_reg <= 0;
			haddr_q    <= 0;
			haddr_q2   <= 0;
			hwdata_q   <= 0;
			selx_q     <= 0;
			selx_q2    <= 0;
		end
		else begin
		  // Setup phase -- address and other are latched(except data)
			if(valid) begin
				hwrite_reg <= HWRITE;
				haddr_q    <= HADDR;
				haddr_q2   <= haddr_q;
				selx_q     <= tempselx;
				selx_q2    <= selx_q;
			end
			// Data phase so data is latched
			if(HREADYIN)
				hwdata_q   <= HWDATA;
		end
	end
endmodule
