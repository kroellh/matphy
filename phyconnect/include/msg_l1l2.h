/* Switch messages from L1 towards L2 */

/* Copyright (C) 2013 Integrated System Laboratory ETHZ (SharperEDGE Team)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <l1ctl_proto.h>

/* switch messages */
void l1l2_switch(int s, uint32_t *mmfile);

/* send RESET_IND from phydev to socket */
void l1l2_reset_ind(int s, uint32_t *mmfile);

/* send RESET_CONF from phydev to socket */
void l1l2_reset_conf(int s, uint32_t *mmfile);

/* send PM_CONF from phydev to socket */
void l1l2_pm_conf(int s, uint32_t *mmfile);

/* send DATA_IND from phydev to socket */
void l1l2_data_ind(int s, uint32_t *mmfile);

/* send FBSB_CONF from phydev to socket */
void l1l2_fbsb_conf(int s, uint32_t *mmfile);

/* send CCCH_MODE_CONF from phydev to socket */
void l1l2_ccch_mode_conf(int s, uint32_t *mmfile);

/* send message to socket */
void l1l2_send(int s, uint8_t *msg,int msg_len, int data_len);

/* initialize message for socket */
uint8_t *l1l2_create_msg(int msg_len, int data_len);

/* fill l1ctl_hdr */
void l1l2_create_hdr(uint32_t *mmfile, struct l1ctl_hdr *hdr);

/* fill l1ctl_info_dl */
void l1l2_create_info_dl(uint32_t *mmfile, struct l1ctl_info_dl *info_dl);
