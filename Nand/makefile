CC = gcc
CFLAGS = -g -Wall -Wextra -Wno-implicit-fallthrough -std=gnu17 -fPIC -O2
LDFLAGS = -shared -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=realloc -Wl,--wrap=reallocarray -Wl,--wrap=free -Wl,--wrap=strdup -Wl,--wrap=strndup

# Pseudocel .PHONY
.PHONY: all clean
	
# Opisuje zależność między bibliotekami
memory_test.o: memory_test.h
nand.o: nand.h vector.h
nand_test.o: nand.h memory_tests.h
vector.o: vector.h

# Kompiluje libnand.so i testy
all: libnand.so test

# Kompilowanie biblioteki 
libnand.so: nand.o memory_tests.o vector.o
	$(CC) $(LDFLAGS) -o $@ $^

# Kompilowanie testów
test: nand_test.o libnand.so
	$(CC) -o $@ $^ -L. -lnand

# Kompilowanie .o z .c
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Usuwa pliki .o oraz libnand.so i testy
clean:
	rm -f *.o libnand.so test

