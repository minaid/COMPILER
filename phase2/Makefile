default: all

all: scanner.l parser.y
	bison --yacc --defines --output=parser.c parser.y
	flex --outfile=scanner.c scanner.l
	gcc -o calc scanner.c parser.c symbol_table.c

clean:
	rm -f calc scanner.c parser.c parser.h
