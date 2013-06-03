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

#include <stdio.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <string.h>

#include <phyconnect.h>
#include <l1ctl_proto.h>
#include <msg_l2l1.h>
#include <msg_l1l2.h>
#include <utils.h>

/* switch messages */
void l1l2_switch(int s, uint32_t *mmfile)
{
  if ( mmfile[MSG_PCT_IDX] ==  1 ) {

    printf("receiving message from phydev\n");
    printf("msg type: ");

    switch ( (uint8_t) mmfile[TYP_PCT_IDX] ) {
    case L1CTL_DATA_IND:
      printf("L1CTL_DATA_IND\n");
      l1l2_data_ind(s, mmfile);
      break;
    case L1CTL_RESET_IND:
      printf("L1CTL_RESET_IND\n");
      l1l2_reset_ind(s, mmfile);
      break;
    case L1CTL_RESET_CONF:
      printf("L1CTL_RESET_CONF\n");
      l1l2_reset_conf(s, mmfile);
      break;
    case L1CTL_PM_CONF:
      printf("L1CTL_PM_CONF\n");
      l1l2_pm_conf(s, mmfile);
      break;
    case L1CTL_FBSB_CONF:
      printf("L1CTL_FBSB_CONF\n");
      l1l2_fbsb_conf(s, mmfile);
      break;
    case L1CTL_CCCH_MODE_CONF:
      printf("L1CTL_CCCH_MODE_CONF\n");
      l1l2_ccch_mode_conf(s, mmfile);
      break;
    default:
      printf("Unhandled message type number %u\n",mmfile[TYP_PCT_IDX]);
      break;
    }

    /* reset data flag */
    mmfile[MSG_PCT_IDX] = 0;
    printf("\n");
  }
}

/* send RESET_IND from phydev to socket */
void l1l2_reset_ind(int s, uint32_t *mmfile)
{
  int data_len, msg_len;
  uint8_t *msg;
  struct l1ctl_hdr hdr;
  struct l1ctl_reset reset;

  data_len = L1CTL_HDR_LENGTH + L1CTL_RESET_LENGTH;
  msg_len = data_len + 2;

  /* fill structs */
  l1l2_create_hdr(mmfile,&hdr);
  reset.type = (uint8_t) mmfile[PCT_START_IDX];
  reset.pad[0] = 0;
  reset.pad[1] = 0;
  reset.pad[2] = 0;

  /* produce msg */
  msg = l1l2_create_msg(msg_len,data_len);
  memcpy(&msg[2],&hdr,L1CTL_HDR_LENGTH);
  memcpy(&msg[2+L1CTL_HDR_LENGTH],&reset,L1CTL_RESET_LENGTH);

  /* send msg */
  l1l2_send(s,msg,msg_len,data_len);
}

/* send RESET_CONF from phydev to socket */
void l1l2_reset_conf(int s, uint32_t *mmfile)
{
  /* processing of RESET_IND and RESET_CONF are identical */
  l1l2_reset_ind(s, mmfile);
}

/* send PM_CONF from phydev to socket */
void l1l2_pm_conf(int s, uint32_t *mmfile)
{
  int data_len, msg_len;
  uint8_t *msg;
  struct l1ctl_hdr hdr;
  struct l1ctl_pm_conf pm_conf;

  data_len = L1CTL_HDR_LENGTH + L1CTL_PM_CONF_LENGTH;
  msg_len = data_len + 2;

  /* fill structs */
  l1l2_create_hdr(mmfile,&hdr);
  pm_conf.band_arfcn = htons((uint16_t) mmfile[PCT_START_IDX]);
  pm_conf.pm[0] = (uint8_t) mmfile[PCT_START_IDX+1];
  pm_conf.pm[1] = 0;

  /* produce msg */
  msg = l1l2_create_msg(msg_len,data_len);
  memcpy(&msg[2],&hdr,L1CTL_HDR_LENGTH);
  memcpy(&msg[2+L1CTL_HDR_LENGTH],&pm_conf,L1CTL_PM_CONF_LENGTH);

  /* send msg */
  l1l2_send(s,msg,msg_len,data_len);
}

/* send DATA_IND from phydev to socket */
void l1l2_data_ind(int s, uint32_t *mmfile)
{
  int data_len, msg_len, i;
  uint8_t *msg;
  struct l1ctl_hdr hdr;
  struct l1ctl_info_dl info_dl;
  struct l1ctl_data_ind data_ind;
     
  data_len = L1CTL_HDR_LENGTH + L1CTL_INFO_DL_LENGTH + L1CTL_DATA_IND_LENGTH;
  msg_len = data_len + 2;

  /* fill structs */
  l1l2_create_hdr(mmfile,&hdr);
  l1l2_create_info_dl(mmfile,&info_dl);
  for (i=0;i<L1CTL_DATA_IND_LENGTH;i++){
    data_ind.data[i] = (uint8_t) mmfile[PCT_START_IDX+INFO_DL_ENTRIES+i];
  }
          
  /* produce msg */
  msg = l1l2_create_msg(msg_len,data_len);
  memcpy(&msg[2],&hdr,L1CTL_HDR_LENGTH);
  memcpy(&msg[2+L1CTL_HDR_LENGTH],&info_dl,L1CTL_INFO_DL_LENGTH);
  memcpy(&msg[2+L1CTL_HDR_LENGTH+L1CTL_INFO_DL_LENGTH],&data_ind,L1CTL_DATA_IND_LENGTH);
     
  /* send msg */     
  l1l2_send(s,msg,msg_len,data_len);
}

/* send FBSB_CONF from phydev to socket */
void l1l2_fbsb_conf(int s, uint32_t *mmfile)
{
  int data_len, msg_len;
  uint8_t *msg;
  struct l1ctl_hdr hdr;
  struct l1ctl_info_dl info_dl;
  struct l1ctl_fbsb_conf fbsb_conf;
     
  data_len = L1CTL_HDR_LENGTH + L1CTL_INFO_DL_LENGTH + L1CTL_FBSB_CONF_LENGTH;
  msg_len = data_len + 2;

  /* fill structs */
  l1l2_create_hdr(mmfile,&hdr);
  l1l2_create_info_dl(mmfile,&info_dl);
  fbsb_conf.initial_freq_err = ntohs((uint16_t) mmfile[PCT_START_IDX+INFO_DL_ENTRIES]);
  fbsb_conf.result = (uint8_t) mmfile[PCT_START_IDX+INFO_DL_ENTRIES+1];
  fbsb_conf.bsic = (uint8_t) mmfile[PCT_START_IDX+INFO_DL_ENTRIES+2];
     
  /* produce msg */
  msg = l1l2_create_msg(msg_len,data_len);
  memcpy(&msg[2],&hdr,L1CTL_HDR_LENGTH);
  memcpy(&msg[2+L1CTL_HDR_LENGTH],&info_dl,L1CTL_INFO_DL_LENGTH);
  memcpy(&msg[2+L1CTL_HDR_LENGTH+L1CTL_INFO_DL_LENGTH],&fbsb_conf,L1CTL_FBSB_CONF_LENGTH);
     
  /* send msg */     
  l1l2_send(s,msg,msg_len,data_len);
}

/* send CCCH_MODE_CONF from phydev to socket */
void l1l2_ccch_mode_conf(int s, uint32_t *mmfile)
{
  int data_len, msg_len;
  uint8_t *msg;
  struct l1ctl_hdr hdr;
  struct l1ctl_ccch_mode_conf ccch_mode_conf;

  data_len = L1CTL_HDR_LENGTH + L1CTL_CCCH_MODE_CONF_LENGTH;
  msg_len = data_len + 2;

  /* fill structs */
  l1l2_create_hdr(mmfile,&hdr);
  ccch_mode_conf.ccch_mode = (uint8_t) mmfile[PCT_START_IDX];
  ccch_mode_conf.padding[0] = 0;
  ccch_mode_conf.padding[1] = 0;
  ccch_mode_conf.padding[2] = 0;

  /* produce msg */
  msg = l1l2_create_msg(msg_len,data_len);
  memcpy(&msg[2],&hdr,L1CTL_HDR_LENGTH);
  memcpy(&msg[2+L1CTL_HDR_LENGTH],&ccch_mode_conf,L1CTL_CCCH_MODE_CONF_LENGTH);

  /* send msg */
  l1l2_send(s,msg,msg_len,data_len);
}

/* send message to socket */
void l1l2_send(int s,uint8_t *msg,int msg_len, int data_len)
{
  hexdump(&msg[2],data_len);
  printf("sending message to socket...");
  send(s,msg,msg_len,0);
  printf("done\n");
  free(msg);
}

/* initialize message for socket */
uint8_t *l1l2_create_msg(int msg_len, int data_len)
{
  uint8_t *msg;
  msg = malloc(sizeof(uint8_t)*msg_len);
     
  msg[0] = (uint8_t) (data_len >> 8);
  msg[1] = (uint8_t) data_len;
     
  return msg;
}

/* fill l1ctl_hdr */
void l1l2_create_hdr(uint32_t *mmfile, struct l1ctl_hdr *hdr)
{
  hdr->msg_type = (uint8_t) mmfile[TYP_PCT_IDX];
  hdr->flags = (uint8_t) mmfile[MSG_FLAG_IDX];
  hdr->padding[0] = 0;
  hdr->padding[1] = 0;
}

/* fill l1ctl_info_dl */
void l1l2_create_info_dl(uint32_t *mmfile, struct l1ctl_info_dl *info_dl)
{
  info_dl->chan_nr = (uint8_t) mmfile[PCT_START_IDX];
  info_dl->link_id = (uint8_t) mmfile[PCT_START_IDX+1];
  info_dl->band_arfcn = ntohs((uint16_t) mmfile[PCT_START_IDX+2]);
  info_dl->frame_nr = ntohl((uint32_t) mmfile[PCT_START_IDX+3]);
  info_dl->rx_level = (uint8_t) mmfile[PCT_START_IDX+4];
  info_dl->snr = (uint8_t) mmfile[PCT_START_IDX+5];
  info_dl->num_biterr = (uint8_t) mmfile[PCT_START_IDX+6];
  info_dl->fire_crc = (uint8_t) mmfile[PCT_START_IDX+7];
}
