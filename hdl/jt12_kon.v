`timescale 1ns / 1ps


/* This file is part of JT12.


	JT12 program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	JT12 program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with JT12.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Version: 1.0
	Date: 27-1-2017

*/

module jt12_kon(
	input 			rst,
	input 			clk,
	input			clk_en,
	input	[3:0]	keyon_op,
	input	[2:0]	keyon_ch,
	input	[1:0]	cur_op,
	input	[2:0]	cur_ch,
	input			up_keyon,
	input			csm,
	// input			flag_A,
	input			overflow_A,

	output	reg		keyon_I
);

//reg csm_copy;

reg din, drop_24;
wire drop_23;

reg [3:0] cur_op_hot;

always @(posedge clk) if( clk_en ) begin
	keyon_I <= (csm&&cur_ch==3'd2&&overflow_A) || drop_23;
	drop_24 <= drop_23;
end

always @(*) begin
	case( cur_op )
		2'd0: cur_op_hot = 4'b0001; // S1
		2'd1: cur_op_hot = 4'b0100; // S3
		2'd2: cur_op_hot = 4'b0010; // S2
		2'd3: cur_op_hot = 4'b1000; // S4
	endcase
	din = keyon_ch==cur_ch && up_keyon ? |(keyon_op&cur_op_hot) : drop_24;
end

jt12_sh_rst #(.width(1),.stages(23),.rstval(1'b0)) u_konch(
	.clk	( clk		),
	.clk_en	( clk_en	),
	.rst	( rst		),
	.din	( din		),
	.drop	( drop_23	)
);

endmodule
