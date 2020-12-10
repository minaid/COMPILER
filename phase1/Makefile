default: all

all: scanner.l
	flex --outfile=scanner.c scanner.l
	gcc -o al scanner.c

clean:
	rm -f al scanner.c
