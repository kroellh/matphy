CC 	= gcc
MFLAGS  = -Iinclude
CFLAGS  = $(MFLAGS) -Wall -c
LDFLAGS = -o

OBJ = phyconnect.o msg_l2l1.o msg_l1l2.o utils.o

.PHONY: all clean

all: phyconnect

phyconnect: $(OBJ)
	$(CC) $(OBJ) $(LDFLAGS) $@

%.o: %.c include/*.h
	$(CC) $(CFLAGS) $<

clean:
	rm -f *.o
	rm -f phyconnect
