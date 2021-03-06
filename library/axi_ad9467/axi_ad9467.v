// ***************************************************************************
// ***************************************************************************
// Copyright 2013(c) Analog Devices, Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//     - Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     - Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in
//       the documentation and/or other materials provided with the
//       distribution.
//     - Neither the name of Analog Devices, Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//     - The use of this software may or may not infringe the patent rights
//       of one or more patent holders.  This license does not release you
//       from the requirement that you obtain separate licenses from these
//       patent holders to use this software.
//     - Use of the software either in source or binary form, must be run
//       on or directly connected to an Analog Devices Inc. component.
//
// THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED.
//
// IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, INTELLECTUAL PROPERTY
// RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/1ns

module axi_ad9467(

    // physical interface

    adc_clk_in_p,
    adc_clk_in_n,
    adc_data_in_p,
    adc_data_in_n,
    adc_data_or_p,
    adc_data_or_n,

    // delay_clock

    delay_clk,

    // dma interface

    adc_clk,
    adc_dwr,
    adc_ddata,
    adc_doverflow,

    // axi interface

    s_axi_aclk,
    s_axi_aresetn,
    s_axi_awvalid,
    s_axi_awaddr,
    s_axi_awready,
    s_axi_wvalid,
    s_axi_wdata,
    s_axi_wstrb,
    s_axi_wready,
    s_axi_bvalid,
    s_axi_bresp,
    s_axi_bready,
    s_axi_arvalid,
    s_axi_araddr,
    s_axi_arready,
    s_axi_rvalid,
    s_axi_rresp,
    s_axi_rdata,
    s_axi_rready
);

    // parameters

    parameter PCORE_ID = 0;
    parameter PCORE_BUFTYPE = 0;
    parameter PCORE_IODELAY_GROUP = "dev_if_delay_group";
    parameter C_S_AXI_MIN_SIZE = 32'hffff;
    parameter C_BASEADDR = 32'hffffffff;
    parameter C_HIGHADDR = 32'h00000000;

    // physical interface

    input           adc_clk_in_p;
    input           adc_clk_in_n;
    input   [ 7:0]  adc_data_in_p;
    input   [ 7:0]  adc_data_in_n;
    input           adc_data_or_p;
    input           adc_data_or_n;

    // delay clk

    input           delay_clk;

    // dma interface

    output          adc_clk;
    output          adc_dwr;
    output  [15:0]  adc_ddata;
    input           adc_doverflow;

    // axi interface

    input           s_axi_aclk;
    input           s_axi_aresetn;
    input           s_axi_awvalid;
    input   [31:0]  s_axi_awaddr;
    output          s_axi_awready;
    input           s_axi_wvalid;
    input   [31:0]  s_axi_wdata;
    input   [ 3:0]  s_axi_wstrb;
    output          s_axi_wready;
    output          s_axi_bvalid;
    output  [ 1:0]  s_axi_bresp;
    input           s_axi_bready;
    input           s_axi_arvalid;
    input   [31:0]  s_axi_araddr;
    output          s_axi_arready;
    output          s_axi_rvalid;
    output  [ 1:0]  s_axi_rresp;
    output  [31:0]  s_axi_rdata;
    input           s_axi_rready;

    // internal registers
    reg [31:0]      up_rdata        = 32'b0;
    reg             up_ack          =  1'b0;

    // internal clock and resets
    wire            up_clk;
    wire            up_rstn;
    wire            adc_rst;
    wire            adc_clk;

    // internal signals
    wire            up_sel_s;
    wire            up_wr_s;
    wire [13:0]     up_addr_s;
    wire [31:0]     up_wdata_s;
    wire [15:0]     adc_data_if_s;
    wire            adc_or_s;
    wire            up_adc_or_s;
    wire            adc_ddr_edgesel_s;
    wire            delay_sel_s;
    wire            delay_rwn_s;
    wire [ 7:0]     delay_addr_s;
    wire [ 4:0]     delay_wdata_s;
    wire            delay_rst;
    wire            delay_ack_s;
    wire [ 4:0]     delay_rdata_s;
    wire            delay_locked_s;
    wire            adc_pn_oos_s;
    wire            adc_pn_err_s;
    wire [31:0]     up_rdata_common;
    wire [31:0]     up_rdata_channel;
    wire            up_ack_common;
    wire            up_ack_channel;
    wire            adc_pn_type_s;
    wire [15:0]     adc_channel_data_s;
    wire            adc_enable_s;

    assign up_clk         = s_axi_aclk;
    assign up_rstn        = s_axi_aresetn;
    assign adc_dwr        = 1'b1;
    assign adc_ddata      = adc_data_if_s;

    // processor read interface
    always @(negedge up_rstn or posedge up_clk) begin
        if (up_rstn == 0) begin
            up_rdata  <= 32'd0;
            up_ack    <= 1'd0;
        end else begin
            up_rdata  <= up_rdata_channel | up_rdata_common;
            up_ack    <= up_ack_channel | up_ack_common;
        end
    end

    // ADC data interface
    axi_ad9467_if #(
        .PCORE_BUFTYPE (PCORE_BUFTYPE),
        .PCORE_IODELAY_GROUP (PCORE_IODELAY_GROUP))
    i_if (
        .adc_clk_in_p (adc_clk_in_p),
        .adc_clk_in_n (adc_clk_in_n),
        .adc_data_in_p (adc_data_in_p),
        .adc_data_in_n (adc_data_in_n),
        .adc_data_or_p (adc_data_or_p),
        .adc_data_or_n (adc_data_or_n),
        .adc_clk (adc_clk),
        .adc_data (adc_data_if_s),
        .adc_or (adc_or_s),
        .adc_ddr_edgesel (adc_ddr_edgesel_s),
        .delay_sel (delay_sel_s),
        .delay_rwn (delay_rwn_s),
        .delay_addr (delay_addr_s),
        .delay_wdata (delay_wdata_s),
        .delay_clk (delay_clk),
        .delay_ack (delay_ack_s),
        .delay_rst (delay_rst),
        .delay_rdata (delay_rdata_s),
        .delay_locked (delay_locked_s));

    // channel
    axi_ad9467_channel #(.CHID(0)) i_channel (
        .adc_clk(adc_clk),
        .adc_rst(adc_rst),
        .adc_data(adc_data_if_s),
        .adc_or(adc_or_s),
        .adc_dfmt_data(adc_channel_data_s),
        .adc_enable(adc_enable_s),
        .up_adc_pn_err(adc_pn_err_s),
        .up_adc_pn_oos(adc_pn_oos_s),
        .up_adc_or(up_adc_or_s),
        .up_rstn(up_rstn),
        .up_clk(up_clk),
        .up_sel(up_sel_s),
        .up_wr(up_wr_s),
        .up_addr(up_addr_s),
        .up_wdata(up_wdata_s),
        .up_rdata(up_rdata_channel),
        .up_ack(up_ack_channel));

    // common processor control
    up_adc_common #(.PCORE_ID(PCORE_ID))
    i_up_adc_common(
        .mmcm_rst(),
        .delay_clk(delay_clk),
        .delay_ack_t(delay_ack_s),
        .delay_locked(delay_locked_s),
        .delay_rst(delay_rst),
        .delay_sel(delay_sel_s),
        .delay_rwn(delay_rwn_s),
        .delay_addr(delay_addr_s),
        .delay_wdata(delay_wdata_s),
        .delay_rdata(delay_rdata_s),
        .adc_clk(adc_clk),
        .adc_rst(adc_rst),
        .adc_r1_mode(),
        .adc_ddr_edgesel(adc_ddr_edgesel_s),
        .adc_pin_mode(),
        .adc_status(1'b1),
        .adc_status_pn_err(adc_pn_err_s),
        .adc_status_pn_oos(adc_pn_oos_s),
        .adc_status_or(up_adc_or_s),
        .adc_clk_ratio(32'b1),
        .adc_status_ovf(adc_doverflow),
        .adc_status_unf(1'b0),
        .drp_clk(1'b0),
        .drp_rdata(16'b0),
        .drp_rst(),
        .drp_sel(),
        .drp_wr(),
        .drp_addr(),
        .drp_wdata(),
        .drp_ready(1'b0),
        .drp_locked(1'b1),
        .up_rstn(up_rstn),
        .up_clk(up_clk),
        .up_sel(up_sel_s),
        .up_wr(up_wr_s),
        .up_addr(up_addr_s),
        .up_wdata(up_wdata_s),
        .up_rdata(up_rdata_common),
        .up_ack(up_ack_common),
        .up_usr_chanmax(),
        .adc_usr_chanmax(8'b0));

    // axi interface
    up_axi #(
        .PCORE_BASEADDR (C_BASEADDR),
        .PCORE_HIGHADDR (C_HIGHADDR))
    i_up_axi (
        .up_rstn (up_rstn),
        .up_clk (up_clk),
        .up_axi_awvalid (s_axi_awvalid),
        .up_axi_awaddr (s_axi_awaddr),
        .up_axi_awready (s_axi_awready),
        .up_axi_wvalid (s_axi_wvalid),
        .up_axi_wdata (s_axi_wdata),
        .up_axi_wstrb (s_axi_wstrb),
        .up_axi_wready (s_axi_wready),
        .up_axi_bvalid (s_axi_bvalid),
        .up_axi_bresp (s_axi_bresp),
        .up_axi_bready (s_axi_bready),
        .up_axi_arvalid (s_axi_arvalid),
        .up_axi_araddr (s_axi_araddr),
        .up_axi_arready (s_axi_arready),
        .up_axi_rvalid (s_axi_rvalid),
        .up_axi_rresp (s_axi_rresp),
        .up_axi_rdata (s_axi_rdata),
        .up_axi_rready (s_axi_rready),
        .up_sel (up_sel_s),
        .up_wr (up_wr_s),
        .up_addr (up_addr_s),
        .up_wdata (up_wdata_s),
        .up_rdata (up_rdata),
        .up_ack (up_ack));

endmodule
