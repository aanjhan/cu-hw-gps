# This file is part of the Cornell University Hardware GPS Receiver Project.
# Copyright (C) 2009 - Adam Shapiro (ams348@cornell.edu)
#                      Tom Chatt (tjc42@cornell.edu)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

include ../components/common_header.mk

SOURCES+=$(COMPONENTS_DIR)/ca_upsampler.csv \
	$(COMPONENTS_DIR)/subchannel.csv \
	$(COMPONENTS_DIR)/cos.csv \
	$(COMPONENTS_DIR)/sin.csv \
	$(COMPONENTS_DIR)/channel__subchannel.csv \
	$(COMPONENTS_DIR)/channel__ca_upsampler.csv \
	$(COMPONENTS_DIR)/channel.csv \
	$(COMPONENTS_DIR)/acquisition.csv \
	$(COMPONENTS_DIR)/acquisition_controller.csv \
	$(COMPONENTS_DIR)/channel__acquisition_controller.csv \
	$(COMPONENTS_DIR)/tracking_loops.csv \
	$(COMPONENTS_DIR)/sqrt_fixed.csv \
	$(COMPONENTS_DIR)/fll.csv \
	$(COMPONENTS_DIR)/dll.csv \
	$(COMPONENTS_DIR)/channel__dll.csv \
	$(COMPONENTS_DIR)/channel__tracking_loops.csv \
	$(COMPONENTS_DIR)/mem_bank.csv \
	$(COMPONENTS_DIR)/dm9000a_controller.csv \
	$(COMPONENTS_DIR)/rtdf_packet_processor.csv \
#	top__channel.csv

VERILOG_SOURCES+=$(COMPONENTS_DIR)/priority_select.s

include ../components/common.mk