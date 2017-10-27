# mkproject_v2017_2_hwacc_only.tcl
# Create a complete Vivado project which integrates a core from HLS
#
# Change log:
# Oct 27, 2017  Taesu Kim
#               - Created to support v2017.2

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2017.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_msg_id "BD_TCL-109" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# e.g. mkproject my_proj my_work /nobackup/jingpu/Halide-HLS/apps/hls_examples/demosaic_harris_hls/hls_prj/solution1/impl/ip
proc mkproject { projectName projectPath ip_path} {

    set hls_repo [file normalize $ip_path]

    puts "Creating project $projectName in $projectPath"

    # Create the empty project
    create_project $projectName $projectPath -part xc7z020clg484-1
    set_property BOARD_PART xilinx.com:zc706:part0:1.4 [current_project]

    # Set IP repo paths
    set_property ip_repo_paths "$hls_repo" [current_project]
    update_ip_catalog

    # Create an empty block design
    set design_name design_1
    set bd_name [create_bd_design $design_name]
    set bd_path "${projectPath}/${projectName}.srcs/sources_1/bd/${bd_name}"

    # Populate the block design
    create_root_design ""

    # create the hdl wrapper for the design
    make_wrapper -files [get_files "${bd_path}/${design_name}.bd"] -top

    # add newly created hdl wrapper as a source
    add_files -norecurse "${bd_path}/hdl/${bd_name}_wrapper.v"
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    puts "***** Building Binary..."

    launch_runs synth_1 -jobs 4
    wait_on_run synth_1

    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
}

# procedure to create entire design; provide argument to make
# procedure reusable. if parentcell is "", will use root.
proc create_root_design { parentcell } {

  variable script_folder

  if { $parentcell eq "" } {
     set parentcell [get_bd_cells /]
  }

  # get object for parentcell
  set parentobj [get_bd_cells $parentcell]
  if { $parentobj == "" } {
     catch {common::send_msg_id "bd_tcl-100" "error" "unable to find parent cell <$parentcell>!"}
     return
  }

  # make sure parentobj is hier blk
  set parenttype [get_property type $parentobj]
  if { $parenttype ne "hier" } {
     catch {common::send_msg_id "bd_tcl-101" "error" "parent <$parentobj> has type = <$parenttype>. expected to be <hier>."}
     return
  }

  # save current instance; restore later
  set oldcurinst [current_bd_instance .]

  # set parent object as current
  current_bd_instance $parentobj


  # create interface ports
  set ddr [ create_bd_intf_port -mode master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr ]
  set fixed_io [ create_bd_intf_port -mode master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 fixed_io ]

  # create ports

  # create instance: axi_dma_0, and set properties
  set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
  set_property -dict [ list \
config.c_enable_multi_channel {1} \
config.c_sg_include_stscntrl_strm {0} \
 ] $axi_dma_0

  # create instance: axi_smc, and set properties
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc ]
  set_property -dict [ list \
config.num_si {3} \
 ] $axi_smc

  # create instance: axis_dwidth_converter_0, and set properties
  set axis_dwidth_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_0 ]
  set_property -dict [ list \
config.m_tdata_num_bytes {4} \
 ] $axis_dwidth_converter_0

  # create instance: ipu_top_0, and set properties
  set ipu_top_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:ipu_top:1.0 ipu_top_0 ]

  # create instance: processing_system7_0, and set properties
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
  set_property -dict [ list \
config.pcw_irq_f2p_intr {1} \
config.pcw_use_fabric_interrupt {1} \
config.pcw_use_s_axi_acp {1} \
config.preset {zc706} \
 ] $processing_system7_0

  # create instance: ps7_0_axi_periph, and set properties
  set ps7_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps7_0_axi_periph ]
  set_property -dict [ list \
config.num_mi {2} \
 ] $ps7_0_axi_periph

  # create instance: rst_ps7_0_50m, and set properties
  set rst_ps7_0_50m [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_50m ]

  # create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]

  # create interface connections
  connect_bd_intf_net -intf_net axi_dma_0_m_axis_mm2s [get_bd_intf_pins axi_dma_0/m_axis_mm2s] [get_bd_intf_pins ipu_top_0/arg_0]
  connect_bd_intf_net -intf_net axi_dma_0_m_axi_mm2s [get_bd_intf_pins axi_dma_0/m_axi_mm2s] [get_bd_intf_pins axi_smc/s01_axi]
  connect_bd_intf_net -intf_net axi_dma_0_m_axi_s2mm [get_bd_intf_pins axi_dma_0/m_axi_s2mm] [get_bd_intf_pins axi_smc/s02_axi]
  connect_bd_intf_net -intf_net axi_dma_0_m_axi_sg [get_bd_intf_pins axi_dma_0/m_axi_sg] [get_bd_intf_pins axi_smc/s00_axi]
  connect_bd_intf_net -intf_net axi_smc_m00_axi [get_bd_intf_pins axi_smc/m00_axi] [get_bd_intf_pins processing_system7_0/s_axi_acp]
  connect_bd_intf_net -intf_net axis_dwidth_converter_0_m_axis [get_bd_intf_pins axi_dma_0/s_axis_s2mm] [get_bd_intf_pins axis_dwidth_converter_0/m_axis]
  connect_bd_intf_net -intf_net ipu_top_0_arg_2 [get_bd_intf_pins axis_dwidth_converter_0/s_axis] [get_bd_intf_pins ipu_top_0/arg_2]
  connect_bd_intf_net -intf_net processing_system7_0_ddr [get_bd_intf_ports ddr] [get_bd_intf_pins processing_system7_0/ddr]
  connect_bd_intf_net -intf_net processing_system7_0_fixed_io [get_bd_intf_ports fixed_io] [get_bd_intf_pins processing_system7_0/fixed_io]
  connect_bd_intf_net -intf_net processing_system7_0_m_axi_gp0 [get_bd_intf_pins processing_system7_0/m_axi_gp0] [get_bd_intf_pins ps7_0_axi_periph/s00_axi]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_m00_axi [get_bd_intf_pins axi_dma_0/s_axi_lite] [get_bd_intf_pins ps7_0_axi_periph/m00_axi]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_m01_axi [get_bd_intf_pins ipu_top_0/s_axi_config] [get_bd_intf_pins ps7_0_axi_periph/m01_axi]

  # create port connections
  connect_bd_net -net axi_dma_0_mm2s_introut [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/in0]
  connect_bd_net -net axi_dma_0_s2mm_introut [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/in1]
  connect_bd_net -net processing_system7_0_fclk_clk0 [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/m_axi_sg_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_dwidth_converter_0/aclk] [get_bd_pins ipu_top_0/ap_clk] [get_bd_pins processing_system7_0/fclk_clk0] [get_bd_pins processing_system7_0/m_axi_gp0_aclk] [get_bd_pins processing_system7_0/s_axi_acp_aclk] [get_bd_pins ps7_0_axi_periph/aclk] [get_bd_pins ps7_0_axi_periph/m00_aclk] [get_bd_pins ps7_0_axi_periph/m01_aclk] [get_bd_pins ps7_0_axi_periph/s00_aclk] [get_bd_pins rst_ps7_0_50m/slowest_sync_clk]
  connect_bd_net -net processing_system7_0_fclk_reset0_n [get_bd_pins processing_system7_0/fclk_reset0_n] [get_bd_pins rst_ps7_0_50m/ext_reset_in]
  connect_bd_net -net rst_ps7_0_50m_interconnect_aresetn [get_bd_pins axis_dwidth_converter_0/aresetn] [get_bd_pins ps7_0_axi_periph/aresetn] [get_bd_pins rst_ps7_0_50m/interconnect_aresetn]
  connect_bd_net -net rst_ps7_0_50m_peripheral_aresetn [get_bd_pins axi_dma_0/axi_resetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins ipu_top_0/ap_rst_n] [get_bd_pins ps7_0_axi_periph/m00_aresetn] [get_bd_pins ps7_0_axi_periph/m01_aresetn] [get_bd_pins ps7_0_axi_periph/s00_aresetn] [get_bd_pins rst_ps7_0_50m/peripheral_aresetn]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins processing_system7_0/irq_f2p] [get_bd_pins xlconcat_0/dout]

  # create address segments
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_0/data_sg] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_ddr_lowocm] seg_processing_system7_0_acp_ddr_lowocm
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_0/data_mm2s] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_ddr_lowocm] seg_processing_system7_0_acp_ddr_lowocm
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_0/data_s2mm] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_ddr_lowocm] seg_processing_system7_0_acp_ddr_lowocm
  create_bd_addr_seg -range 0x00400000 -offset 0xe0000000 [get_bd_addr_spaces axi_dma_0/data_sg] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_iop] seg_processing_system7_0_acp_iop
  create_bd_addr_seg -range 0x40000000 -offset 0x40000000 [get_bd_addr_spaces axi_dma_0/data_sg] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_m_axi_gp0] seg_processing_system7_0_acp_m_axi_gp0
  create_bd_addr_seg -range 0x02000000 -offset 0xfc000000 [get_bd_addr_spaces axi_dma_0/data_sg] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_qspi_linear] seg_processing_system7_0_acp_qspi_linear
  create_bd_addr_seg -range 0x02000000 -offset 0xfc000000 [get_bd_addr_spaces axi_dma_0/data_mm2s] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_qspi_linear] seg_processing_system7_0_acp_qspi_linear
  create_bd_addr_seg -range 0x02000000 -offset 0xfc000000 [get_bd_addr_spaces axi_dma_0/data_s2mm] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_qspi_linear] seg_processing_system7_0_acp_qspi_linear
  create_bd_addr_seg -range 0x00010000 -offset 0x40400000 [get_bd_addr_spaces processing_system7_0/data] [get_bd_addr_segs axi_dma_0/s_axi_lite/reg] seg_axi_dma_0_reg
  create_bd_addr_seg -range 0x00080000 -offset 0x43c00000 [get_bd_addr_spaces processing_system7_0/data] [get_bd_addr_segs ipu_top_0/s_axi_config/reg] seg_ipu_top_0_reg

  # exclude address segments
  create_bd_addr_seg -range 0x00400000 -offset 0xe0000000 [get_bd_addr_spaces axi_dma_0/data_mm2s] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_iop] seg_processing_system7_0_acp_iop
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_0/data_mm2s/seg_processing_system7_0_acp_iop]

  create_bd_addr_seg -range 0x40000000 -offset 0x40000000 [get_bd_addr_spaces axi_dma_0/data_mm2s] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_m_axi_gp0] seg_processing_system7_0_acp_m_axi_gp0
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_0/data_mm2s/seg_processing_system7_0_acp_m_axi_gp0]

  create_bd_addr_seg -range 0x00400000 -offset 0xe0000000 [get_bd_addr_spaces axi_dma_0/data_s2mm] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_iop] seg_processing_system7_0_acp_iop
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_0/data_s2mm/seg_processing_system7_0_acp_iop]

  create_bd_addr_seg -range 0x40000000 -offset 0x40000000 [get_bd_addr_spaces axi_dma_0/data_s2mm] [get_bd_addr_segs processing_system7_0/s_axi_acp/acp_m_axi_gp0] seg_processing_system7_0_acp_m_axi_gp0
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_0/data_s2mm/seg_processing_system7_0_acp_m_axi_gp0]



  # restore current instance
  current_bd_instance $oldcurinst

  save_bd_design
}
# End of create_root_design()

puts "Script loaded.  Create a design using"
puts "  mkproject PROJECT_NAME PROJECT_PATH IP_PATH"
puts "e.g. mkproject my_proj my_work /nobackup/jingpu/Halide-HLS/apps/hls_examples/demosaic_harris_hls/hls_prj/solution1/impl/ip"
