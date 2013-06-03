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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>

#include <phyconnect.h>
#include <msg_l2l1.h>
#include <msg_l1l2.h>

int done = 0;

/* prepare socket */
void prep_sock(int *s)
{
  int len;
  int t;
  struct sockaddr_un local, remote;

  /* create socket */
  if ((s[0] = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
    perror("Error creating socket");
    exit(1);
  }

  /* bind socket */
  local.sun_family = AF_UNIX;
  strcpy(local.sun_path, SOCK_PATH);
  unlink(local.sun_path);
  len = strlen(local.sun_path) + sizeof(local.sun_family);
  if (bind(s[0], (struct sockaddr *)&local, len) == -1) {
    perror("Error binding socket");
    exit(1);
  }

  /* listen on socket */
  if (listen(s[0], 1) == -1) {
    perror("Error listening on socket");
    exit(1);
  }    

  /* wait for connection on socket */
  printf("Waiting for a connection on socket ...\n");
  t = sizeof(remote);
  if ((s[1] = accept(s[0], (struct sockaddr *)&remote, &t)) == -1) {
    perror("Error accepting connection on socket");
    exit(1);
  }

  printf("Socket connected.\n\n");
}


/* map file into memory and return its pointer */
uint32_t *map_file(void)
{
  void *start;
  int fd;
  int length;
  uint32_t *data[MMFILE_LENGTH] = {0};
     
  length = 4*MMFILE_LENGTH;

  printf("Mapping file into memory\n");

  fd = open(MMFILE_NAME,O_RDWR|O_CREAT|O_TRUNC,S_IRUSR|S_IWUSR);

  if ( write(fd,data,length) == -1 ) {
    perror("Error writing to file");
    exit(1);
  }

  start = mmap(start, length, PROT_WRITE, MAP_SHARED, fd, 0);

  if ( close(fd) == -1 ) {
    perror("Error closing file after mmap");
    exit(1);
  }

  return (uint32_t *)start;
}

void signalHandler(int sig)
{
  done = 1;
}

int main(void)
{
  int s[2];
  uint32_t *mmfile;

  signal(SIGINT,signalHandler);  

  mmfile = map_file();

  prep_sock(s);  
  
  printf("Telling phydev that phyconnect is ready\n");
  mmfile[PCT_RDY_IDX] = (uint32_t) 1;
  printf("Waiting for phydev to be ready...\n");
  while (!done) {          
      if ( mmfile[PHY_RDY_IDX] == 1 ){
          printf("phydev is ready\n\n");
          break;
      }
  }
        
  /* wait for messages on socket and forward them to phydev
     and wait for messages from phydev and forward them to socket */
  while(!done) {
    l2l1_switch(s[1], mmfile);
    l1l2_switch(s[1], mmfile);
  }

  /* close socket */
  close(s[1]);
  close(s[0]);
  
  /* zero mmfile  and unmap it*/
  memset(mmfile,0,MMFILE_LENGTH*4);
  munmap(mmfile,MMFILE_LENGTH);

  return 0;
}
