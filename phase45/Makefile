default: all

all: scanner.l parser.y
	bison --yacc --defines --output=parser.c parser.y
	flex --outfile=scanner.c scanner.l
	gcc -o calc scanner.c parser.c symbol_table.c icode.c fcode.c
	gcc -o avm avm.c

clean:
	rm -f calc avm test.bin scanner.c parser.c parser.h
