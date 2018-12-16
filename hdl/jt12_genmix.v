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
    Date: 11-12-2018
    
    Each channel can use the full range of the DAC as they do not
    get summed in the real chip.

    Operator data is summed up without adding extra bits. This is
    the case of real YM3438, which was used on Megadrive 2 models.

*/

/* Mixer for Megadrive/Genesis
   cen_fm  must be 1 over  7  of clk
   psg_cen_240 must be 1 over 15  of clk
   PSG and FM signals are interpolated up to clk sample rate.
*/

module jt12_genmix(
    input               rst,
    input               clk,
    input signed [15:0] fm_snd,
    input signed [10:0] psg_snd,
    output reg signed [15:0] snd      // Mixed sound at clk sample rate
);

/////////////////////////////////////////////////
// PSG
// x5 -> div 3 -> div 7
// 54MHz count up to:
// orig -> 16*15 = 240
// x5 -> 16*15/5 = 48
// div 3 -> 48*3 = 144
// div 7 -> 144*7 = 1008 <=> fm_sample
// 48 x 5 = 240, 
reg [5:0] psgcnt48;
reg [2:0] psgcnt240, psgcnt1008;
reg [1:0] psgcnt144;

always @(posedge clk)
    if( rst ) begin
        psgcnt48  <= 5'd0;
        psgcnt240 <= 3'd0;
        psgcnt144 <= 8'd0;
        psgcnt1008<= 3'd0;
    end else begin
        psgcnt48  <= psgcnt48 ==6'd47  ? 6'd0 : psgcnt48 +6'd1;
        if( psgcnt48 == 6'd47 ) begin
            psgcnt240 <= psgcnt240==3'd4 ? 3'd0 : psgcnt240+3'd1;
            psgcnt144  <= psgcnt144 ==3'd2 ? 3'd0 : psgcnt144+3'd1;
            if( psgcnt144==3'd0 )
                psgcnt1008 <= psgcnt1008==3'd6 ? 3'd0 : psgcnt1008+3'd1;
        end
    end

reg psg_cen_1008, psg_cen_240, psg_cen_48, psg_cen_144;
always @(negedge clk) begin
    psg_cen_240 <= psgcnt48 ==6'd47 && psgcnt240 == 3'd0;
    psg_cen_48  <= psgcnt48 ==6'd47;
    psg_cen_144 <= psgcnt48 ==6'd47 && psgcnt144==3'd0;
    psg_cen_1008<= psgcnt48 ==6'd47 && psgcnt144==3'd0 && psgcnt1008==3'd0;
end

wire signed [10:0] psg1, psg2, psg3; // MSB will always be zero, but needed for
    // intermmediate calculations

// 48
jt12_interpol #(.calcw(14),.inw(11),.cntw(3),.rate(5)) 
u_psg1(
    .clk    ( clk      ),
    .rst    ( rst      ),        
    .cen_in ( psg_cen_240  ),
    .cen_out( psg_cen_48   ),
    .snd_in ( psg_snd  ),
    .snd_out( psg1     )
);

// 144
jt12_decim #(.calcw(18),.inw(11) ) 
u_psg2(
    .clk    ( clk         ),
    .rst    ( rst         ),        
    .cen_in ( psg_cen_48  ),
    .cen_out( psg_cen_144 ),
    .snd_in ( psg1        ),
    .snd_out( psg2        )
);

// 1008
jt12_decim #(.calcw(18),.inw(11) ) 
u_psg3(
    .clk    ( clk         ),
    .rst    ( rst         ),        
    .cen_in ( psg_cen_144 ),
    .cen_out( psg_cen_1008),
    .snd_in ( psg2        ),
    .snd_out( psg3        )
);

/////////////////////////////////////////////////
// FM
// x4 -> x4 -> x7 -> x9
// 54MHz count up to:
// 252 -> 63 -> 9 -> 1
reg [1:0] clkcnt252, clkcnt1008;
reg [3:0] clkcnt63;
reg [3:0] clkcnt9;
always @(posedge clk)
    if( rst ) begin
        clkcnt1008<= 2'd0;
        clkcnt252 <= 2'd0;
        clkcnt63  <= 4'd0;
        clkcnt9   <= 4'd0;
    end else begin
        clkcnt9   <= clkcnt9  ==4'd8   ? 4'd0 : clkcnt9  +4'd1;
        if( clkcnt9== 4'd8 ) begin
            clkcnt63  <= clkcnt63 ==3'd6  ? 3'd0 : clkcnt63 +6'd1;
            if( clkcnt63==3'd6 ) begin
                clkcnt252 <= clkcnt252+2'd1;
                if(clkcnt252==3'd3) clkcnt1008<=clkcnt1008+2'd1;
            end
        end
    end 
// evenly spaced clock enable signals
reg cen_1008, cen_252, cen_63, cen_9;
always @(negedge clk) begin
    cen_9    <= clkcnt9  ==4'd8;
    cen_63   <= clkcnt9  ==4'd8 && clkcnt63  ==3'd0;
    cen_252  <= clkcnt9  ==4'd8 && clkcnt63  ==3'd0 && clkcnt252 ==2'd0;
    cen_1008 <= clkcnt9  ==4'd8 && clkcnt63  ==3'd0 && clkcnt252 ==2'd0 && clkcnt1008==2'd0;
end

wire signed [15:0] fm2,fm3,fm4,fm5;

reg [15:0] mixed;
always @(posedge clk)
    mixed <= fm_snd + psg3;

// 1008 --> 252 x4
localparam wx4=18;
jt12_interpol #(.calcw(wx4),.inw(16),.cntw(2),.rate(4)) 
u_fm2(
    .clk    ( clk      ),
    .rst    ( rst      ),
    .cen_in ( cen_1008 ),
    .cen_out( cen_252  ),
    .snd_in ( mixed    ),
    .snd_out( fm2      )
);

// 252 --> 63 x4
jt12_interpol #(.calcw(wx4),.inw(16),.cntw(2),.rate(4)) 
u_fm3(
    .clk    ( clk      ),
    .rst    ( rst      ),    
    .cen_in ( cen_252  ),
    .cen_out( cen_63   ),
    .snd_in ( fm2      ),
    .snd_out( fm3      )
);

// 63 --> 9 x7
jt12_interpol #(.calcw(19),.inw(16),.cntw(4),.rate(7)) 
u_fm4(
    .clk    ( clk      ),
    .rst    ( rst      ),        
    .cen_in ( cen_63   ),
    .cen_out( cen_9    ),
    .snd_in ( fm3      ),
    .snd_out( fm4      )
);

// 9 --> 1 x9
jt12_interpol #(.calcw(19),.inw(16),.cntw(4),.rate(9)) 
u_fm5(
    .clk    ( clk      ),
    .rst    ( rst      ),        
    .cen_in ( cen_9    ),
    .cen_out( 1'b1     ),
    .snd_in ( fm4      ),
    .snd_out( fm5      )
);

wire signed [15:0] psg_snd16 = 16'd0;

always @(posedge clk)
    snd <= psg_snd16 + fm5;

endmodule // jt12_genmix