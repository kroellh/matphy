/* Interface between OsmocomBB layer23 and MatPHY L1 */

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

#define MMFILE_LENGTH 220
#define MMFILE_NAME "/tmp/mmfile.dat"
#define SOCK_PATH "/tmp/osmocom_l2" 

/* L1CTL lengths in bytes */
#define L1CTL_HDR_LENGTH 4
#define L1CTL_RESET_LENGTH 4
#define L1CTL_INFO_DL_LENGTH 12
#define L1CTL_FBSB_CONF_LENGTH 4
#define L1CTL_PM_CONF_LENGTH 4
#define L1CTL_DATA_IND_LENGTH 23
#define L1CTL_CCCH_MODE_CONF_LENGTH 4

/* memory mapped file indices and lengths */
#define PCT_RDY_IDX 0 /* phyconnect ready */
#define PHY_RDY_IDX 1 /* phydev ready */
#define MSG_PCT_IDX 2 /* message for phyconnect is ready (set by phydev) */
#define MSG_PHY_IDX 3 /* message for phydev is ready (set by phyconnect) */
#define MSG_FLAG_IDX 16 /* flag of the message towards phyconnect */
#define TYP_PCT_IDX 18 /* L1CTL message type towards phyconnect */
#define TYP_PHY_IDX 19 /* L1CTL message type towards phydev */
#define PCT_START_IDX 20 /* start of message for phyconnect */
#define PHY_START_IDX 120 /* start of message for phydev */  
#define PHY_STA_IDX 4 /* PHY state */
#define ARFCN_CUR_IDX 9 /* ARFCN of the currently synched cell */
#define BSIC_CUR_IDX 10 /* BSIC of the currently synched cell */
#define INFO_DL_ENTRIES 8
