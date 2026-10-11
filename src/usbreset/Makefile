CFLAGS ?= -O2 -Wall -Wextra

.PHONY: all clean

all: usbreset

usbreset: usbreset.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

clean:
	rm -f usbreset
