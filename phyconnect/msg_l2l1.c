/* Switch messages from L2 towards L1 */

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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <poll.h>

#include <l1ctl_proto.h>
#include <phyconnect.h>
#include <utils.h>
#include <msg_l2l1.h>

/* switch messages */
void l2l1_switch(int s, uint32_t *mmfile)
{
  unsigned int tout = 100;
  int pl;
  int len;
  uint8_t *msg;
  uint16_t msg_len;
  struct l1ctl_hdr *hdr;
  struct pollfd fds;

  fds.fd = s;
  fds.events = POLLIN;

  if ((pl = poll(&fds, 1, tout)) > 0) {
    /* only read socket if phydev is ready (avoids deadlocks) */
    if (mmfile[MSG_PHY_IDX] == 0) { 
      if ((len=recv(fds.fd, &msg_len, sizeof(msg_len), 0)) > 0) {
	printf("receiving message from socket\n");
      } else {
	if (len < 0) perror("Error receiving header on socket");
	else printf("Closed connection to socket\n");
      }
               
      msg = malloc(sizeof(uint8_t)*msg_len);
    
      if ((len=recv(fds.fd, msg, htons(msg_len), 0)) > 0) {
	hexdump(msg, len);
	hdr = (struct l1ctl_hdr *) msg;
	printf("receiving message from L2/L3\n");
	printf("msg type: ");
	switch ( hdr->msg_type ) {
	case L1CTL_FBSB_REQ:
	  printf("L1CTL_FBSB_REQ\n");
	  l2l1_fbsb_req(mmfile, (struct l1ctl_fbsb_req *)hdr->data);
	  break;
	case L1CTL_PM_REQ:
	  printf("L1CTL_PM_REQ\n");
	  l2l1_pm_req(mmfile, (struct l1ctl_pm_req *)hdr->data);           
	  break;
	case L1CTL_RESET_REQ:
	  printf("L1CTL_RESET_REQ\n");
	  l2l1_reset_req(mmfile, (struct l1ctl_reset *)hdr->data);
	  break;
	case L1CTL_CCCH_MODE_REQ:
	  printf("CCCH_MODE_REQ\n");
	  l2l1_ccch_mode_req(mmfile, (struct l1ctl_ccch_mode_req *)hdr->data);
	  break;
	default:
	  printf("Unhandled message type number %u\n",hdr->msg_type);
	  break;
	}
     
	printf("\n");
      } else {
	if (len < 0) perror("Error receiving message on socket");
	else printf("Closed connection to socket\n");
      }               
      free(msg);
    }
  } else if (pl < 0) {
    perror("Error pollings socket");
    exit(1);
  }
}
	
/* send RESET_REQ from socket to phydev */
void l2l1_reset_req(uint32_t *mmfile, struct l1ctl_reset *msg)
{
  printf("Forwarding reset request to phydev...");
  while (1) {
    if (mmfile[MSG_PHY_IDX] == 0 )
      break;
  }
  mmfile[TYP_PHY_IDX] = (uint32_t) L1CTL_RESET_REQ;
  mmfile[PHY_START_IDX] = (uint32_t) msg->type;
  mmfile[MSG_PHY_IDX]  = (uint32_t) 1;
  printf("done\n");
}

/* send PM_REQ from socket to phydev */
void l2l1_pm_req(uint32_t *mmfile, struct l1ctl_pm_req *msg)
{
  uint16_t arfcn_from;
  uint16_t arfcn_to;
  uint8_t byte_1;
  uint8_t byte_2;

  printf("Forwarding PM request to phydev...");
  while (1) {
    if (mmfile[MSG_PHY_IDX] == 0 )
      break;
  }
  mmfile[TYP_PHY_IDX] = (uint32_t) L1CTL_PM_REQ;
  mmfile[PHY_START_IDX] = (uint32_t) msg->type;
  byte_1 = msg->padding[3];
  byte_2 = msg->padding[4];
  arfcn_from = ((uint16_t) byte_1<<8) | (uint16_t) byte_2;
  byte_1 = msg->padding[5];
  byte_2 = msg->padding[6];
  arfcn_to = ((uint16_t) byte_1<<8) | (uint16_t) byte_2;
  mmfile[PHY_START_IDX+1] = (uint32_t) arfcn_from;
  mmfile[PHY_START_IDX+2] = (uint32_t) arfcn_to;
  mmfile[MSG_PHY_IDX]  = (uint32_t) 1;
  printf("done\n");
}

/* send FBSB_REQ from socket to phydev */
void l2l1_fbsb_req(uint32_t *mmfile, struct l1ctl_fbsb_req *msg)
{
  printf("Forwarding FBSB request to phydev...");
  while (1) {
    if (mmfile[MSG_PHY_IDX] == 0 )
      break;
  }
  mmfile[TYP_PHY_IDX] = (uint32_t) L1CTL_FBSB_REQ;
  mmfile[PHY_START_IDX] = (uint32_t) htons(msg->band_arfcn);
  mmfile[PHY_START_IDX+1] = (uint32_t) htons(msg->timeout);
  mmfile[PHY_START_IDX+2] = (uint32_t) htons(msg->freq_err_thresh1);
  mmfile[PHY_START_IDX+3] = (uint32_t) htons(msg->freq_err_thresh2);
  mmfile[PHY_START_IDX+4] = (uint32_t) msg->num_freqerr_avg;
  mmfile[PHY_START_IDX+5] = (uint32_t) msg->flags;
  mmfile[PHY_START_IDX+6] = (uint32_t) msg->sync_info_idx;
  mmfile[PHY_START_IDX+7] = (uint32_t) msg->ccch_mode;
  mmfile[PHY_START_IDX+8] = (uint32_t) msg->rxlev_exp;
  mmfile[MSG_PHY_IDX]  = (uint32_t) 1;
  printf("done\n");
}

/* send CCCH_MODE_REQ from socket to phydev */
void l2l1_ccch_mode_req(uint32_t *mmfile, struct l1ctl_ccch_mode_req *msg)
{
  printf("Forwarding CCCH_MODE_REQ to phydev...");
  while (1) {
    if (mmfile[MSG_PHY_IDX] == 0 )
      break;
  }
  mmfile[TYP_PHY_IDX] = (uint32_t) L1CTL_CCCH_MODE_REQ;
  mmfile[PHY_START_IDX] = (uint32_t) msg->ccch_mode;
  mmfile[MSG_PHY_IDX]  = (uint32_t) 1;
  printf("done\n");
}
